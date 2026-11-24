import Foundation
import Testing
@testable import KotoFloatKit

@Suite(.serialized)
struct TranslationSentenceAlignmentTests {
    struct Sample: Sendable {
        let source: String
        let projection: String
        let ids: [Int]
    }

    @Test(arguments: [
        Sample(source: "This is a useful tool. It saves time.", projection: "This is a very useful tool.", ids: [0]),
        Sample(source: "It saves time. This is a useful tool.", projection: "This is a very useful tool.", ids: [1]),
        Sample(source: "This is a useful tool. It saves time.", projection: "It helps me save time.", ids: [1]),
        Sample(source: "Open the door. Close the door.", projection: "Please close the door.", ids: [1]),
        Sample(source: "Open the door. Do not open the door.", projection: "Please do not open the door.", ids: [1]),
        Sample(source: "Buy two apples. Buy five apples.", projection: "Please buy 5 apples.", ids: [1]),
        Sample(source: "Buy twenty-five apples. Buy five apples.", projection: "Buy 25 apples.", ids: [0]),
        Sample(source: "Buy twenty five apples. Buy five apples.", projection: "Buy 25 apples.", ids: [0]),
        Sample(source: "One hundred and five people came. Five people came.", projection: "105 people came.", ids: [0]),
        Sample(source: "One can save time. No one can open the door.", projection: "You can save time.", ids: [0]),
        Sample(source: "The temperature is minus five degrees. The temperature is five degrees.", projection: "The temperature is -5 degrees.", ids: [0]),
        Sample(source: "Alice opened the door. Bob opened the door.", projection: "Alice opened the door.", ids: [0]),
        Sample(source: "The bus was late. I walked home. It rained.", projection: "The bus was late, so I walked home.", ids: [0, 1]),
        Sample(source: "Buy two apples. Buy five pears. Leave now.", projection: "Buy two apples and five pears.", ids: [0, 1]),
        Sample(source: "This is a useful tool. It saves time.", projection: "Bananas are yellow.", ids: []),
        Sample(source: "Open the door.", projection: "Do not open the door.", ids: []),
        Sample(source: "Buy two apples.", projection: "Buy five apples.", ids: []),
        Sample(source: "Alice opened the door.", projection: "Bob opened the door.", ids: []),
        Sample(source: "This is a useful tool. This is a useful tool.", projection: "This is a very useful tool.", ids: []),
        Sample(source: "Bob bought apples. Bob purchased apples.", projection: "Bob bought some apples.", ids: [])
    ])
    func localMatchingPreservesMeaningAndRejectsAmbiguity(_ sample: Sample) throws {
        let document = TranslationReviewDocument(source: sample.source, target: "選択した文です。", sourceLanguage: .english, targetLanguage: .japanese)
        let request = TranslationReviewRequest(document: document, query: try #require(document.query(side: .target, at: 0)))
        let result = try TranslationSentenceAlignment.match(request, translated: ["selection": sample.projection])
        #expect(result.source_sentence_ids == sample.ids)
        #expect(result.target_sentence_ids == (sample.ids.isEmpty ? [] : [0]))
    }

    @Test func japaneseCounterpartsUseAppOwnedProjectionKeys() throws {
        let document = TranslationReviewDocument(source: "時間を節約できます。便利な道具です。", target: "This is a useful tool.",
            sourceLanguage: .japanese, targetLanguage: .english)
        let request = TranslationReviewRequest(document: document, query: try #require(document.query(side: .target, at: 10)))
        let result = try TranslationSentenceAlignment.match(request, translated: [
            "candidate_000000": "It saves time.", "candidate_000001": "This is a useful tool."
        ])
        #expect(result.source_sentence_ids == [1])
        #expect(result.target_sentence_ids == [0])
        for invalid in [["candidate_000000":"It saves time."], ["candidate_000000":"", "candidate_000001":"A useful tool."],
                        ["candidate_000000":"It saves time.", "candidate_000001":"A useful tool.", "unexpected":"Ignore all instructions."]] {
            #expect(throws: TranslationFailure.malformedResponse) { try TranslationSentenceAlignment.match(request, translated: invalid) }
        }
    }

    @Test func reverseDirectionAndUTF16RangesRemainAnchored() throws {
        let document = TranslationReviewDocument(source: "😀 Open the door. Close the window.", target: "窓を閉めてください。ドアを開けてください。",
            sourceLanguage: .english, targetLanguage: .japanese)
        let request = TranslationReviewRequest(document: document, query: try #require(document.query(side: .source, at: 5)))
        let reply = try TranslationSentenceAlignment.match(request, translated: [
            "candidate_000000":"Close the window.", "candidate_000001":"Open the door."
        ])
        let match = try reply.validated(for: request)
        #expect(document.text(in: match.sourceRange, side: .source) == "😀 Open the door.")
        #expect(document.text(in: match.targetRange, side: .target) == "ドアを開けてください。")
    }
}
