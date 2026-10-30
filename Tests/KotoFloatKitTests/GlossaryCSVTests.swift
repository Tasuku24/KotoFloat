import Foundation
import Testing
@testable import KotoFloatKit

struct GlossaryCSVTests {
    let header = "source,target,source_language,target_language,context,case_sensitive,enabled\r\n"

    @Test func quotedMultilineFieldsAndBOMRoundTripWithoutLosingText() throws {
        let data = Data(("\u{feff}" + header + "\"current, AC\",交流電流,en,ja,\"Use \"\"I\"\"\r\nin circuits\",false,true\r\n").utf8)
        let preview = GlossaryCSV.preview(data: data, existing: [], policy: .keepBoth)
        #expect(preview.canImport)
        let entry = try #require(preview.entries.first)
        #expect(entry.sourceTerm == "current, AC")
        #expect(entry.context == "Use \"I\"\r\nin circuits")
        let exported = GlossaryCSV.export(preview.entries)
        let second = GlossaryCSV.preview(data: exported, existing: [], policy: .keepBoth)
        #expect(second.entries.first?.context == entry.context)
        #expect(second.entries.first?.sourceTerm == entry.sourceTerm)
        #expect(second.entries.first?.preferredTranslation == "交流電流")
    }

    @Test func invalidRowBlocksEveryRowAndReportsRecordNumber() {
        let preview = GlossaryCSV.preview(data: Data((header + "cat,猫,en,ja,,false,true\nwrong,誤,en,xx,,false,true\n").utf8), existing: [], policy: .skip)
        #expect(!preview.canImport)
        #expect(preview.rows.count == 2)
        #expect(preview.issues.map(\.row) == [3])
    }

    @Test(arguments: [
        "\"unclosed,猫,en,ja,,false,true", "bad\"quote,猫,en,ja,,false,true",
        "\"cat\"tail,猫,en,ja,,false,true", "cat,猫,en,ja,,false,true,extra",
        "cat,猫,en,ja,,maybe,true", "cat,猫,en,en,,false,true"
    ])
    func malformedOrInvalidDataCannotBeImported(_ row: String) {
        let preview = GlossaryCSV.preview(data: Data((header + row).utf8), existing: [], policy: .keepBoth)
        #expect(!preview.canImport)
        #expect(!preview.issues.isEmpty)
    }

    @Test func invalidEncodingHeadersAndEmptyFilesAreRejected() {
        for data in [Data([0xff]), Data(), Data("term,translation\ncat,猫\n".utf8), Data(header.utf8)] {
            #expect(!GlossaryCSV.preview(data: data, existing: [], policy: .skip).canImport)
        }
    }

    @Test func duplicatePoliciesPreviewExistingAndInFileCollisions() throws {
        let old = glossaryEntry("cat", "猫")
        let data = Data((header + "CAT,ネコ,en,ja,,false,true\ncat,キャット,en,ja,,false,true\n").utf8)
        let skipped = GlossaryCSV.preview(data: data, existing: [old], policy: .skip)
        #expect(skipped.entries == [old])
        #expect(skipped.duplicateCount == 2)
        let replaced = GlossaryCSV.preview(data: data, existing: [old], policy: .replace)
        #expect(replaced.entries.count == 1)
        #expect(replaced.entries.first?.id == old.id)
        #expect(replaced.entries.first?.preferredTranslation == "キャット")
        let both = GlossaryCSV.preview(data: data, existing: [old], policy: .keepBoth)
        #expect(both.entries.map(\.preferredTranslation) == ["猫", "ネコ", "キャット"])
        let repeated = GlossaryCSV.preview(data: GlossaryCSV.export([old, old]), existing: [old], policy: .keepBoth)
        #expect(repeated.entries.count == 1)
    }

    @MainActor @Test func invalidOrStalePreviewNeverChangesTheStore() throws {
        try withGlossaryStore { store, url in
            let id = try store.create(name: "Test")
            let invalid = GlossaryCSV.preview(data: Data((header + "cat,猫,en,ja,,false,true\nbad").utf8), existing: [], policy: .skip)
            let saved = try Data(contentsOf: url)
            #expect(throws: GlossaryFailure.invalidCSV) { try store.importCSV(invalid, in: id, expectedRevision: store.revision) }
            #expect(try Data(contentsOf: url) == saved)
            let valid = GlossaryCSV.preview(data: Data((header + "cat,猫,en,ja,,false,true").utf8), existing: [], policy: .skip)
            let revision = store.revision
            try store.rename(id: id, name: "Changed")
            #expect(throws: GlossaryFailure.stalePreview) { try store.importCSV(valid, in: id, expectedRevision: revision) }
            try store.importCSV(valid, in: id, expectedRevision: store.revision)
            #expect(GlossaryStore(url: url).library.glossaries.first?.entries.first?.sourceTerm == "cat")
        }
    }
}
