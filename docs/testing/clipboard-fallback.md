# Clipboard fallback when no text is selected

## English

On 2026-11-08 the user refined the clipboard fallback: text copied within the last five minutes translates automatically, while older text requires confirmation. Exactly five minutes is included. An unknown copy time also requires confirmation.

Directly retrieved selections go straight to translation. If no selection is available, automatic clipboard access proceeds only when macOS allows the read without prompting. Otherwise, the popup offers manual paste. An empty or whitespace-only selection reads the current clipboard’s plain text once. If Accessibility cannot expose a selection, KotoFloat tries Copy first and reads the existing clipboard if Copy times out. A change-count check rejects text if the clipboard changes during the read. Clipboard captures have a distinct method and no attributed source app or selection bounds.

The system capture environment retains one clipboard instance from launch and checks only its [change count](https://developer.apple.com/documentation/appkit/nspasteboard/changecount) every 500 ms; it does not read or store clipboard contents in the background. Text already present at launch has an unknown age. Each change uses the preceding observation time as the earliest possible copy time, so observation delays or sleep cannot make old text appear new. This conservative estimate can require confirmation up to one polling interval early during normal operation. Moving the system clock backwards invalidates the recorded time. A new copy of identical text still resets the age. Restoring the clipboard after automatic selection copying preserves the original age, including unknown ages.

Old or unknown clipboard text is shown with a confirmation button; no translation request starts until it is accepted. Fresh selection copies still translate without extra confirmation. Empty/non-text clipboards show input guidance. Permission failures, protected fields, unknown source apps, interrupted copy operations, and source changes remain failures rather than fallback triggers. Existing translation size limits remain in force.

Background tests cover the inclusive five-minute boundary, old/unknown/invalid ages, confirmation before sending, copy timeout, expiry without reading, repeated identical copies, delayed observation, clock rollback, age preservation during clipboard restoration, preservation of the current document until clipboard text is accepted, and existing capture safety. Named test pasteboards, injected time, and a fake translation service avoid reading the user's clipboard, waiting five minutes, or contacting their configured server. These do not establish live cross-app capture, timer scheduling on a running desktop, visual behavior, or real-server translation quality.

## 日本語

2026年11月8日、利用者はクリップボードの代替取得を変更し、コピーから5分以内の文章は自動翻訳し、5分を超えた文章は確認することを指定した。ちょうど5分は自動翻訳に含む。コピー時刻が不明な場合も確認する。

直接取得した選択文はそのまま翻訳する。選択文を取得できない場合は、macOSが確認なしで読み取りを許可しているときだけクリップボードを自動で使う。許可の確認が必要な場合は、ポップアップで手動貼り付けを案内する。選択が空または空白のみの場合は、現在のクリップボードのプレーンテキストを1回読む。アクセシビリティ経由で選択を取得できない場合はコピー操作を先に試し、時間切れになった場合に既存のクリップボードを読む。読み取り中に変更回数が変わった場合は文章を採用しない。クリップボード由来を専用の取得方式として区別し、取得元アプリや選択範囲は推測しない。

取得環境は起動時から1つのクリップボードインスタンスを保持し、500ミリ秒ごとに[変更回数](https://developer.apple.com/documentation/appkit/nspasteboard/changecount)だけを確認する。バックグラウンドで本文を読み取ったり保存したりしない。起動前から入っていた文章は時刻不明とする。変更を見つけた場合は直前の監視時刻を、コピーされた可能性がある最も早い時刻として記録する。これにより監視の遅延やスリープで古い文章を新しいと扱わない。通常動作では、この保守的な推定により最大で監視間隔ぶん早く確認が出る場合がある。システム時計が巻き戻された場合は記録した時刻を無効にする。同じ文章を再コピーした場合も時刻を更新する。選択文字の自動コピー後に元のクリップボードへ戻す場合は、時刻不明も含め元のコピー時刻を維持する。

古い文章や時刻不明の文章は確認ボタンとともに表示し、了承されるまで翻訳リクエストを開始しない。選択文字を新しくコピーして取得できた場合は追加の確認なしで翻訳する。空または文章を含まないクリップボードでは入力を案内する。権限不足、保護された入力欄、取得元アプリ不明、コピー操作の中断、取得元の切り替えは、代替取得を行わずエラーとする。翻訳の既存の文字量制限は維持する。

バックグラウンドテストで、5分ちょうどの境界、古い・不明・不正な時刻、了承前の送信防止、コピーの時間切れ、本文を読まない間の期限切れ、同一文章の再コピー、監視の遅延、時計の巻き戻り、復元時の時刻維持、クリップボードの文章を採用するまで現在の文書を保持すること、既存の取得安全性を確認する。専用のテスト用クリップボード、注入した時刻、翻訳サービスを使い、利用者のクリップボードや設定済みサーバーにはアクセスせず、実際に5分待つ必要もない。実アプリ間の取得操作、実デスクトップ上のタイマー動作、見た目、実サーバーの翻訳品質を確認したものではない。
