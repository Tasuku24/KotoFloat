import Observation

@MainActor @Observable
final class SampleContent {
    var isLong = false

    var source: String {
        let paragraph = "Move this window beside the text you are reading. It stays open when you switch to another app, so you can compare both texts at your own pace."
        return isLong ? Array(repeating: paragraph, count: 8).joined(separator: "\n\n") : paragraph
    }

    var translation: String {
        let paragraph = "このウィンドウを、読んでいる文章の横へ移動してください。別のアプリに切り替えても表示が続くので、自分のペースで原文と訳文を見比べられます。"
        return isLong ? Array(repeating: paragraph, count: 8).joined(separator: "\n\n") : paragraph
    }
}
