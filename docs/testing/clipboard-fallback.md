# Clipboard fallback when no text is selected

## English

On 2026-11-03 the user explicitly chose automatic translation of clipboard text when invoking KotoFloat without a selection. This replaces the previous no-selection failure behavior and the earlier prohibition on using existing clipboard text in this case.

Selection capture still takes priority. An empty or whitespace-only selection reads the current clipboard's plain text once. When accessibility cannot expose the selection, the existing copy attempt remains first; if it times out without producing text, capture falls back to the clipboard. The clipboard is not monitored or overwritten by this fallback. A change-count check rejects text if the clipboard changes during the read. Clipboard captures have a distinct method and no attributed source app or selection bounds.

The existing capture-to-translation binding sends clipboard captures automatically, as requested. Copy-based selection captures retain their existing confirmation, and replacing an edited/unsent document retains draft protection. Empty/non-text clipboards show input guidance. Permission failures, protected fields, unknown source apps, interrupted copy operations, and source changes remain failures rather than fallback triggers. Existing translation size limits remain in force.

Background tests cover selection priority, automatic clipboard translation, empty/non-text input, copy timeout, protected/interrupted capture, source changes, and clipboard generation changes. Named test pasteboards and a fake translation service avoid reading the user's clipboard or contacting their configured server. These do not establish live cross-app capture or real-server translation quality.

## 日本語

2026年11月3日、利用者は文章を選択せずにKotoFloatを呼び出した場合、クリップボードの文章をそのまま自動翻訳する動作を明示的に選択した。これにより、従来の未選択エラーと、この場合に既存のクリップボードを使わない制約を変更する。

選択文字の取得を優先する。選択が空または空白のみの場合、現在のクリップボードのプレーンテキストを1回読む。アクセシビリティ経由で選択を取得できない場合は既存のコピー操作を先に試し、文章を取得できず時間切れになった場合にクリップボードを使う。この代替取得ではクリップボードの監視や書き換えは行わない。読み取り中に変更回数が変わった場合は文章を採用しない。クリップボード由来を専用の取得方式として区別し、取得元アプリや選択範囲は推測しない。

既存の取得・翻訳の連携により、クリップボードから取得した文章を指定どおり自動送信する。コピー操作による選択文字の取得には従来の確認を維持し、編集済み・未送信の文書を置き換える場合の下書き保護も維持する。空または文章を含まないクリップボードでは入力を案内する。権限不足、保護された入力欄、取得元アプリ不明、コピー操作の中断、取得元の切り替えは、代替取得を行わずエラーとする。翻訳の既存の文字量制限は維持する。

バックグラウンドテストで、選択文字の優先、自動翻訳、空・非テキスト入力、コピーの時間切れ、保護・中断、取得元切り替え、クリップボードの変更回数を確認する。専用のテスト用クリップボードと翻訳サービスを使い、利用者のクリップボードや設定済みサーバーにはアクセスしない。実アプリ間の取得操作や実サーバーの翻訳品質を確認したものではない。
