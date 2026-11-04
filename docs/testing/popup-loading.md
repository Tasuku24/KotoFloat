# Popup loading and hover help

## English

The user selected the toolbar indicator between the target-language picker and Stop on 2026-11-03. A fixed 16-point slot keeps the picker and actions stationary when the indicator disappears. Normal translation activity no longer inserts a banner above the result. Configuration, failure, changed-input, and glossary notices remain available. The Translator retains its footer activity text.

Both surfaces use native delayed hover help (`.help` for SwiftUI controls and `toolTip` for native language pickers). Copy, Stop, Open Translator, More, source visibility, result details, Undo, and Redo have descriptions. Stop explicitly describes stopping translation. Native window controls retain system-provided help. No custom hover timer or overlay is needed.

Run the non-visible layout regression separately from routine background tests:

```sh
nice -n 10 swift test --jobs 2 --filter PopupControllerTests/popupLoadingCompletionKeepsBodyAndLanguageControlInPlace
```

It checks the scroll viewport and target-language control before and after streaming completion at 360- and 480-point widths. It does not move the pointer or verify the actual delayed tooltip appearance; that remains a live check in both windows.

## 日本語

2026-11-03に、翻訳先の言語選択と停止ボタンの間にローディングを置く案を利用者が選択した。幅16ポイントの専用スペースを常に確保し、表示が消えても言語選択や操作ボタンを動かさない。通常の翻訳中表示は本文上の通知行を追加しない。設定不足、失敗、入力変更、用語集の通知は引き続き表示する。Translatorは下部の翻訳中表示を維持する。

両画面のホバー説明はmacOS標準の遅延表示を使う（SwiftUIは`.help`、ネイティブ言語選択は`toolTip`）。コピー、停止、Translatorを開く、その他、原文表示、結果の詳細、取り消し、やり直しに説明を付ける。停止の説明は翻訳を停止することを明示する。標準ウィンドウボタンの説明はシステムに任せる。独自の待機タイマーや表示レイヤーは追加しない。

上記の非表示レイアウト回帰テストは通常のバックグラウンドテストとは別に実行する。幅360・480ポイントで、翻訳中と完了後のスクロール領域および言語選択の位置が変わらないことを確認する。ポインター操作と、両画面で実際にホバー説明が遅れて出ることの確認は、実アプリで別途行う。
