# Phase 2 verification / 第2段階の検証

## English

### Implemented scope

The existing configurable shortcut captures selected text before showing the popup. Accessibility is preferred; a guarded Copy is used when selected-text access is unavailable. Explicitly empty selections and secure fields do not trigger Copy. Copied text requires confirmation. Permission guidance and manual entry/paste work in the same popup. Source app and optional selection bounds are retained in memory. Near-selection placement falls back to the pointer, and the previous-position default is unchanged. No translation, persistence of source text, or network requests are implemented.

### Automated evidence (2026-10-30)

- Swift tests cover direct capture, empty/secure selections, permission denial, source changes, manual input, copy confirmation, cancelled/stale requests, and popup reuse/close/focus-mode changes.
- Clipboard tests use isolated, real named NSPasteboards. They cover stale content, non-text responses, restoring multiple items and formats, timeout, held modifiers, input/app changes, cancellation, and preserving a newer clipboard generation. They do not alter the system's general clipboard.
- Geometry tests cover Quartz-to-AppKit conversion, negative display coordinates, placement beside a selection, right-edge placement, and pointer fallback.
- Native popup tests preserve Phase 1 focus/Escape/lifetime behavior and confirm that closing during capture cannot reopen the popup.
- Debug and universal Release builds passed. Final counts and review outcomes are recorded below after final verification.

### Live application checks

Synthetic local HTML and a one-page PDF were opened in the installed Chrome and macOS Preview. A separate probe compiled the production capture adapters and ran with the development tool's Accessibility permission. No private document or text was used, and no pointer-warping calls were made.

| App / input | Direct selected text | Copy fallback | Clipboard restored | Selection bounds |
| --- | --- | --- | --- | --- |
| Chrome, HTML textarea, English/Japanese | Confirmed, 75 characters | Confirmed | All saved representations matched | Not provided |
| Chrome, ordinary webpage selection | Confirmed, 75 characters | Not separately exercised on this fixture | Not applicable | Not provided |
| Preview, text PDF | Confirmed, 61 characters | Confirmed | All saved representations matched | Not provided |

These results validate the production adapters on these fixtures. The separately signed KotoFloat app has its own permission; permission approval and end-to-end shortcut acceptance are tracked separately below. Scanned/image-only PDFs require manual input; OCR is outside Phase 2.

### Clipboard limits

The app does not clear the clipboard before sending Copy. It snapshots all readable representations (up to 8 MB), waits for shortcut modifier release, observes a new generation, and waits briefly for it to settle. It restores only if that generation is still current and no other input or focus change was observed. If ownership is uncertain, the latest clipboard content is left in place, so a cancelled/failed capture can leave the copied selection on the clipboard.

macOS does not expose an atomic compare-and-swap or a reliable writer identity for NSPasteboard. The final generation check greatly narrows, but cannot mathematically eliminate, a simultaneous cross-process update during restoration. Clipboard managers and delayed Copy implementations may behave differently. Copy results always require confirmation because some apps copy an entire line or object without selected text. A later translation request must only consume confirmed capture state.

### Manual acceptance

- [ ] Enable Accessibility for the built KotoFloat app, then use ⌃⌥⌘T on a Chrome selection and a Preview PDF selection.
- [ ] Confirm source text and source app, absence of a fake translation, and that source focus is preserved when the popup appears.
- [ ] Try no selection and permission denial; check the explanation and manual entry/paste path.
- [ ] Choose AutoRaise compatibility, move focus between source and popup, and verify focused Escape.
- [ ] Copy different text during capture and confirm that the newer copy remains available. Try the user's clipboard manager, if any.
- [ ] Confirm near-selection/pointer fallback on the user's physical displays.

### Distribution status

This is a locally ad-hoc-signed development build, not a notarized release. Rebuilding may require re-adding KotoFloat in Accessibility settings. Permissions must be granted by the user. No settings for AutoRaise or other resident utilities were changed.

## 日本語

### 実装範囲

既存の変更可能なショートカットで、ポップアップ表示前に選択文章を取得します。Accessibilityを優先し、選択文章を直接取得できない場合は保護付きコピー操作を使います。空選択と保護された入力欄ではコピーしません。コピー経由の文章は利用者の確認後に採用します。同じポップアップで権限案内、手入力・貼り付けを利用できます。取得元アプリと取得できた選択位置はメモリ内に保持します。選択付近への配置は位置不明時にカーソルへ切り替わり、既定の前回位置は維持します。翻訳、原文の永続保存、通信は実装していません。

### 自動検証（2026-10-30）

- Swiftテストで直接取得、空選択・保護欄、権限不足、取得元変更、手入力、コピー確認、キャンセル・古い要求、ポップアップ再利用・終了・フォーカス方式変更を確認。
- クリップボードのテストは実際の独立した名前付きNSPasteboardを使用。古い内容、非テキスト、複数項目・形式の復元、タイムアウト、修飾キー、入力・取得元変更、キャンセル、新しい世代の保持を確認。システムの共通クリップボードは変更しません。
- 配置テストでQuartz→AppKit座標変換、負の画面座標、選択箇所の横・画面右端での配置、カーソルへの代替を確認。
- ネイティブ画面テストで第1段階のフォーカス・Esc・解放を維持し、取得中に閉じても再表示されないことを確認。
- DebugとユニバーサルReleaseのビルドが成功。最終件数とレビュー結果は最終確認後に追記します。

### 実アプリでの確認

テスト用のローカルHTMLと1ページのPDFを、インストール済みChromeとmacOSのプレビューで開きました。本体の取得処理を組み込んだ別の検証プログラムを、開発ツールのアクセシビリティ権限で実行しています。個人の文章・資料は使わず、ポインターを移動する処理も使用していません。

| アプリ・入力 | 選択文章の直接取得 | コピー経由 | クリップボード復元 | 選択位置 |
| --- | --- | --- | --- | --- |
| Chrome、HTML入力欄、英日文章 | 75文字で確認 | 確認済み | 保存した全形式が一致 | 取得できず |
| Chrome、通常のWebページの選択 | 75文字で確認 | この資料では別途確認せず | 対象外 | 取得できず |
| プレビュー、文字を含むPDF | 61文字で確認 | 確認済み | 保存した全形式が一致 | 取得できず |

これは上記資料で本体の取得処理が動くことの検証です。別署名のKotoFloatアプリには独自の権限が必要なため、権限許可とショートカットからの通し確認は下記で別管理します。画像だけのスキャンPDFは手入力が必要です。OCRは第2段階の対象外です。

### クリップボードの制限

コピー前にクリップボードを消去しません。読み取れる全形式を8 MBまで保存し、ショートカットの修飾キーを離すのを待ち、新しい世代への変更と短い安定期間を確認します。同じ世代のままで別の入力・フォーカス変更もないときだけ復元します。更新元が不明確な場合は最新の内容を残すため、キャンセル・失敗後に選択文章がクリップボードへ残る場合があります。

macOSのNSPasteboardには原子的な比較・更新や確実な書き込み元の判定がありません。最後の世代確認で競合する時間を狭めますが、復元の瞬間に別プロセスが更新する条件まで数学的に排除することはできません。クリップボード管理アプリや遅いコピー実装では挙動が異なる場合があります。選択がなくても行・オブジェクト全体をコピーするアプリがあるため、コピー結果は必ず利用者が確認します。後続の翻訳処理は確定済みの取得状態だけを使用する必要があります。

### 利用者による確認

- [ ] ビルド済みKotoFloatのアクセシビリティを許可し、Chromeの選択文章とプレビューのPDFで⌃⌥⌘Tを使う。
- [ ] 原文・取得元が正しく、仮の翻訳を表示せず、表示時に元アプリのフォーカスが維持されることを確認。
- [ ] 空選択と権限不足の案内、手入力・貼り付けを確認。
- [ ] AutoRaise互換を選び、原文とポップアップ間のフォーカス移動と、フォーカス時のEscを確認。
- [ ] 取得中に別の文章をコピーし、新しい内容が残ることを確認。使用中ならクリップボード管理アプリとの併用も確認。
- [ ] 実際の画面構成で、選択付近・カーソルへの代替配置を確認。

### 配布状態

ローカルのアドホック署名による開発版で、公証済みの配布版ではありません。再ビルド後はアクセシビリティ設定への再登録が必要な場合があります。権限は利用者が許可します。AutoRaiseや他の常駐アプリの設定は変更していません。
