# Phase 2 verification / 第2段階の検証

## English

### Implemented scope

The existing configurable shortcut captures selected text before showing the popup. Accessibility is preferred; a guarded Copy is used when selected-text access is unavailable. Explicitly empty selections and secure fields do not trigger Copy. Copied text requires confirmation. Permission guidance and manual entry/paste work in the same popup. Source app and optional selection bounds are retained in memory. Near-selection placement falls back to the pointer, and the previous-position default is unchanged. No translation, persistence of source text, or network requests are implemented.

### Automated evidence (2026-10-30)

- `swift test`: 68 tests pass, covering direct capture, empty/secure selections, permission denial, source changes, manual input, copy confirmation, cancelled/stale requests, and popup reuse/close/focus-mode changes.
- Five language tests cover system defaults and invalid values, saved preferences, supported-language matching and English fallback, immediate resource lookup, and native-menu change notifications. They failed before implementation and pass afterward.
- Clipboard tests use isolated, real named NSPasteboards. They cover stale content, non-text responses, restoring multiple items and formats, timeout, held modifiers, input/app changes, cancellation, and preserving a newer clipboard generation. They do not alter the system's general clipboard.
- Geometry tests cover Quartz-to-AppKit conversion, negative display coordinates, placement beside a selection, right-edge placement, and pointer fallback.
- Native popup tests preserve Phase 1 focus/Escape/lifetime behavior and confirm that closing during capture cannot reopen the popup.
- Debug and universal Release (arm64/x86_64) builds passed; both local signatures passed verification. A separate whole-branch review found two important issues: skipped clipboard generations and AX timeouts incorrectly enabling Copy. Regression tests failed before the fixes and pass afterward; timeouts/permission/invalid-element errors now stop capture, and multiple generation changes are left untouched. No deferred review findings remain.

### Live application checks

Synthetic local HTML and a one-page PDF were opened in the installed Chrome and macOS Preview. A separate probe compiled the production capture adapters and ran with the development tool's Accessibility permission. No private document or text was used, and no pointer-warping calls were made.

| App / input | Direct selected text | Copy fallback | Clipboard restored | Selection bounds |
| --- | --- | --- | --- | --- |
| Chrome, HTML textarea, English/Japanese | Confirmed, 75 characters | Confirmed | All saved representations matched | Not provided |
| Chrome, ordinary webpage selection | Confirmed, 75 characters | Not separately exercised on this fixture | Not applicable | Not provided |
| Preview, text PDF | Confirmed, 61 characters | Confirmed | All saved representations matched | Not provided |

The actual app also dispatched its registered shortcut, preserved Chrome focus, displayed the permission-denied fallback, and accepted synthetic manual English/Japanese input through the editor and confirmation button. The rendered native popup was inspected. These results validate the production adapters on these fixtures. After the user re-added the capture build, before the settings updates below, in Privacy & Security → Device Control and Data Access, the actual app captured the Chrome and Preview fixtures through the registered shortcut, displayed the correct source app/text, and preserved source focus. Chrome empty-selection and synthetic password-field tests displayed the expected explanations without changing the clipboard. One Preview copy attempt was interrupted by the input guard; a subsequent stable attempt succeeded and restored the saved representations. Scanned/image-only PDFs require manual input; OCR is outside Phase 2.

### Settings and language checks

Settings now uses General, Popup, and Text capture tabs in a 600 × 520-point content area. All three tabs were inspected in English and Japanese: no scroll areas were exposed, and the controls fit without clipping. Check again shows a persistent result with the check time and enabled/disabled status. Repeating it updated the timestamp even while access remained disabled. Both English and Japanese result text were verified. Permission help names Device Control and Data Access on macOS 27 or later and Accessibility on earlier versions.

The live app switched from Follow system to Japanese, English, and back to Follow system without restarting. The existing settings window title, labels, app menus, and sample popup changed language; the popup retained its content, position, and size. The language choice persists, and Follow system is the default. System dialogs and some native controls, including KeyboardShortcuts' own recorder messages, follow macOS rather than the in-app choice. The running app was returned to Follow system after verification.

The selected-text checks above used the earlier permitted build. Rebuilding for these settings changes invalidated its local permission; the updated app correctly reports that access is not enabled. Selected-text capture in this new binary needs the user to re-add it in the system permission pane. No permission was changed automatically.

### Clipboard limits

The app does not clear the clipboard before sending Copy. It snapshots all readable representations (up to 8 MB), waits for shortcut modifier release, requires exactly one new generation, and waits briefly for it to settle. Multiple generation changes before the first observation are rejected without restoration, even if an app intentionally writes in multiple stages. It restores only if that generation is still current and no other input or focus change was observed. If ownership is uncertain, the latest clipboard content is left in place, so a cancelled/failed capture can leave the copied selection on the clipboard.

A single unrelated writer before the requested Copy becomes observable cannot be reliably attributed. macOS does not expose an atomic compare-and-swap or a reliable writer identity for NSPasteboard. The final generation check greatly narrows, but cannot mathematically eliminate, a simultaneous cross-process update during restoration. Clipboard managers and delayed Copy implementations may behave differently. Copy results always require confirmation because some apps copy an entire line or object without selected text. A later translation request must only consume confirmed capture state.

### Manual acceptance

- [x] Enable the earlier capture build in Device Control and Data Access, then use ⌃⌥⌘T on a Chrome selection and a Preview PDF selection.
- [x] Confirm source text and source app, absence of a fake translation, and that source focus is preserved when the popup appears.
- [x] Confirm no-selection, protected-field, and permission-denial explanations, plus manual text entry/confirmation.
- [x] Verify non-scrolling settings and permission-check feedback in English and Japanese; change app language without restarting.
- [ ] Re-add the updated settings build in Device Control and Data Access to resume selected-text capture.
- [ ] Verify physical ⌘V paste and actual user copy interruptions with the user's resident utilities.
- [ ] Choose AutoRaise compatibility, move focus between source and popup, and verify focused Escape.
- [ ] Copy different text during capture and confirm that the newer copy remains available. Try the user's clipboard manager, if any.
- [ ] Confirm near-selection/pointer fallback on the user's physical displays.

### Distribution status

This is a locally ad-hoc-signed development build, not a notarized release. Rebuilding may require re-adding KotoFloat in the system permission pane. Permissions must be granted by the user. This Mac labels the pane Device Control and Data Access; earlier macOS versions use Accessibility. The app's help uses the corresponding name, and the settings-opening button routes to the correct pane. The settings update was rebuilt after the earlier successful permission grant, so that grant does not validate the current binary. No settings for AutoRaise or other resident utilities were changed.

## 日本語

### 実装範囲

既存の変更可能なショートカットで、ポップアップ表示前に選択文章を取得します。Accessibilityを優先し、選択文章を直接取得できない場合は保護付きコピー操作を使います。空選択と保護された入力欄ではコピーしません。コピー経由の文章は利用者の確認後に採用します。同じポップアップで権限案内、手入力・貼り付けを利用できます。取得元アプリと取得できた選択位置はメモリ内に保持します。選択付近への配置は位置不明時にカーソルへ切り替わり、既定の前回位置は維持します。翻訳、原文の永続保存、通信は実装していません。

### 自動検証（2026-10-30）

- `swift test`：68テスト成功。直接取得、空選択・保護欄、権限不足、取得元変更、手入力、コピー確認、キャンセル・古い要求、ポップアップ再利用・終了・フォーカス方式変更を確認。
- 言語設定の5テストで、システム準拠の初期値・不正値、保存、対応言語の選択と英語への代替、即時の翻訳リソース参照、標準メニューへの変更通知を確認。実装前に失敗、実装後に成功しました。
- クリップボードのテストは実際の独立した名前付きNSPasteboardを使用。古い内容、非テキスト、複数項目・形式の復元、タイムアウト、修飾キー、入力・取得元変更、キャンセル、新しい世代の保持を確認。システムの共通クリップボードは変更しません。
- 配置テストでQuartz→AppKit座標変換、負の画面座標、選択箇所の横・画面右端での配置、カーソルへの代替を確認。
- ネイティブ画面テストで第1段階のフォーカス・Esc・解放を維持し、取得中に閉じても再表示されないことを確認。
- DebugとユニバーサルRelease（arm64/x86_64）のビルド、両方のローカル署名検証が成功。独立した全体レビューで、最初の観測前に複数回コピーされた場合と、AXタイムアウトから誤ってコピーへ進む場合の2点を指摘されました。修正前に回帰テストの失敗、修正後に成功を確認。タイムアウト・権限・無効な要素のエラーでは取得を停止し、複数世代の変更はそのまま保持します。保留したレビュー指摘はありません。

### 実アプリでの確認

テスト用のローカルHTMLと1ページのPDFを、インストール済みChromeとmacOSのプレビューで開きました。本体の取得処理を組み込んだ別の検証プログラムを、開発ツールのアクセシビリティ権限で実行しています。個人の文章・資料は使わず、ポインターを移動する処理も使用していません。

| アプリ・入力 | 選択文章の直接取得 | コピー経由 | クリップボード復元 | 選択位置 |
| --- | --- | --- | --- | --- |
| Chrome、HTML入力欄、英日文章 | 75文字で確認 | 確認済み | 保存した全形式が一致 | 取得できず |
| Chrome、通常のWebページの選択 | 75文字で確認 | この資料では別途確認せず | 対象外 | 取得できず |
| プレビュー、文字を含むPDF | 61文字で確認 | 確認済み | 保存した全形式が一致 | 取得できず |

アプリ本体でも登録済みショートカットの発火、Chromeのフォーカス維持、権限不足の案内、入力欄から英日テスト文章を入力して確定する操作を確認しました。実画面の表示も確認しています。上表は上記資料で本体の取得処理が動くことの検証です。利用者が下記の設定変更前の文章取得用ビルドをPrivacy & Security → Device Control and Data Accessへ再登録した後、アプリ本体でも登録済みショートカットからChrome・プレビューの文章を取得し、正しい原文・取得元の表示と元アプリのフォーカス維持を確認しました。Chromeの空選択・テスト用パスワード欄では、説明を表示しクリップボードを変更しないことも確認。プレビューのコピーは1回入力監視で中断し、その後の安定した試行では保存した形式の復元まで成功しました。画像だけのスキャンPDFは手入力が必要です。OCRは第2段階の対象外です。

### 設定画面と言語の確認

設定画面を一般・ポップアップ・文章取得の3タブに分け、内容領域を600 × 520ポイントにしました。全タブを英語・日本語で確認し、スクロール領域がなく、項目が欠けずに収まることを確認しました。再確認を押すと、確認時刻と権限の有効・無効を継続表示します。権限が無効のままでも、再度押すと時刻が更新されました。英日両方の結果表示を確認しています。権限案内はmacOS 27以降ではDevice Control and Data Access、それ以前ではAccessibility／アクセシビリティと表示します。

実アプリで、再起動せずにシステムに従う→日本語→英語→システムに従うと切り替えました。開いている設定画面のタイトル・項目・アプリメニュー・サンプルポップアップの表示言語が変わり、ポップアップの文章・位置・サイズは維持されました。選択は保存され、初期設定はシステムに従うです。システムのダイアログや、KeyboardShortcutsのショートカット記録メッセージを含む一部の標準部品は、アプリ内の選択ではなくmacOSの言語に従います。確認後は起動中のアプリをシステムに従うへ戻しました。

上記の選択文章取得は、以前の権限許可済みビルドで確認したものです。今回の設定変更による再ビルドでローカルの権限が無効になり、更新版でも権限が無効であることを正しく表示しています。このバイナリで選択文章を取得するには、利用者がシステムの権限画面へ再登録する必要があります。権限は自動で変更していません。

### クリップボードの制限

コピー前にクリップボードを消去しません。読み取れる全形式を8 MBまで保存し、ショートカットの修飾キーを離すのを待ち、ちょうど1世代の変更と短い安定期間を確認します。最初の観測前に複数世代変わった場合は、アプリが意図的に段階的な書き込みを行う場合も含め、復元せずに中断します。同じ世代のままで別の入力・フォーカス変更もないときだけ復元します。更新元が不明確な場合は最新の内容を残すため、キャンセル・失敗後に選択文章がクリップボードへ残る場合があります。

要求したコピーを観測する前に別の書き込みが1回だけ発生した場合、その更新元を確実に判別することはできません。macOSのNSPasteboardには原子的な比較・更新や確実な書き込み元の判定がありません。最後の世代確認で競合する時間を狭めますが、復元の瞬間に別プロセスが更新する条件まで数学的に排除することはできません。クリップボード管理アプリや遅いコピー実装では挙動が異なる場合があります。選択がなくても行・オブジェクト全体をコピーするアプリがあるため、コピー結果は必ず利用者が確認します。後続の翻訳処理は確定済みの取得状態だけを使用する必要があります。

### 利用者による確認

- [x] 以前の文章取得用ビルドをDevice Control and Data Accessで許可し、Chromeの選択文章とプレビューのPDFで⌃⌥⌘Tを使う。
- [x] 原文・取得元が正しく、仮の翻訳を表示せず、表示時に元アプリのフォーカスが維持されることを確認。
- [x] 空選択・保護欄・権限不足の案内、手入力・確定を確認。
- [x] 英語・日本語でスクロールなしの設定画面と権限の確認結果を確認し、再起動せず表示言語を変更する。
- [ ] 設定更新後のビルドをDevice Control and Data Accessへ再登録し、選択文章取得を再開する。
- [ ] 利用者の常駐アプリ環境で、実際の⌘V貼り付けと取得中の別のコピーを確認。
- [ ] AutoRaise互換を選び、原文とポップアップ間のフォーカス移動と、フォーカス時のEscを確認。
- [ ] 取得中に別の文章をコピーし、新しい内容が残ることを確認。使用中ならクリップボード管理アプリとの併用も確認。
- [ ] 実際の画面構成で、選択付近・カーソルへの代替配置を確認。

### 配布状態

ローカルのアドホック署名による開発版で、公証済みの配布版ではありません。再ビルド後はシステムの権限画面への再登録が必要な場合があります。権限は利用者が許可します。このMacでは設定画面の名称がDevice Control and Data Accessで、以前のmacOSはAccessibility／アクセシビリティを使用します。アプリ内案内も対応する名称を表示し、設定を開くボタンは正しい画面へ移動します。以前の権限許可後に設定変更のため再ビルドしているので、その許可は現在のバイナリの動作確認にはなりません。AutoRaiseや他の常駐アプリの設定は変更していません。
