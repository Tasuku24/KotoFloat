# Translator layout

## English

The user selected the third generated concept (side-by-side comparison) on 2026-11-02. This change applies only to the Translator editor. The popup retains its current layout, hidden-source default, adaptive height, and focus behavior. Liquid Glass is excluded.

The Translator opens with the source on the left and a wider translation on the right. Its native split view starts at 36% source width; AppKit owns subsequent divider dragging and window resizing. The source can be collapsed and restored without replacing the document. Both text areas scroll independently. The initial editor size is 1040 × 620 points and the minimum is 840 × 400; existing saved window frames remain in use.

Reuse the popup's compact toolbar and existing button-clearance measurement without modifying either. The editor hides its separate native window title and draws an opaque toolbar beneath the native controls. Target language, favorites, copy, and the more menu occupy this single row. The source-language picker sits above the source text.

The footer keeps status, details, Undo/Redo, and Translate/Retranslate or Stop available. The more menu contains original visibility, result details, source language, swap, glossary selection/management, clear, and settings. Result details retain request direction, previous request source, glossary review, character counts, and the generated original of an edited translation. Destructive confirmation remains outside the scrolling text. Existing TranslationModel ownership, explicit translation, draft protection, incomplete-copy protection, request snapshots, and undo history are unchanged.

### Verification

- Routine background suite: 140 tests in 22 suites passed.
- Debug application build passed with the repository's separate validation build path.
- An explicitly run, non-visible native-window test verifies the initial split, retention of a manually moved divider after model updates, independent long-text scrolling at 840 × 400, and no additional translation request from resizing. It lives in `PopupControllerTests`, which routine background checks exclude.
- Non-visible AppKit rendering at 1040 × 620 and 840 × 400 was inspected against the selected concept. This checks the hosted content; it does not show native window decorations or prove real desktop focus behavior.
- The running app was not restarted. Real pointer interactions, active native titlebar appearance, VoiceOver, and IME acceptance remain separate live checks. The existing broader native-window suite was not run.

## 日本語

利用者は2026年11月2日に、生成した3案目の左右比較レイアウトを選択した。変更対象はTranslatorの編集ウィンドウのみとする。ポップアップの現在のレイアウト、原文の初期非表示、本文に応じた高さ、フォーカス動作は維持する。Liquid Glassは使用しない。

Translatorは左に原文、右に幅の広い訳文を表示する。標準の分割ビューを初期状態で原文36%とし、その後の境界線のドラッグとウィンドウのリサイズはAppKitに任せる。文書を置き換えずに原文を折りたたみ・再表示できる。両方の本文は独立してスクロールする。初期サイズは1040 × 620ポイント、最小サイズは840 × 400ポイントとし、既存の保存済みウィンドウ枠は引き続き使用する。

ポップアップのコンパクトな上部バーと、標準ウィンドウボタンとの余白を測る処理を、変更せず再利用する。エディタの独立した標準タイトル表示を隠し、標準ボタンの下に不透明な上部バーを配置する。翻訳先言語、お気に入り、コピー、その他メニューを1行にまとめる。翻訳元言語は原文の上で選択する。

下部には状態、詳細、Undo／Redo、翻訳／再翻訳または停止を置く。その他メニューに原文表示、結果の詳細、翻訳元言語、入れ替え、用語集の選択・管理、クリア、設定をまとめる。結果の詳細には、翻訳方向、前回送信した原文、用語集の確認、文字数、編集前の生成訳を残す。破棄確認はスクロールする本文の外に維持する。既存のTranslationModelによる状態管理、明示的な翻訳、下書き保護、未完了訳のコピー制限、送信時点の設定、Undo履歴は変更しない。

### 検証

- 通常のバックグラウンドテスト：22スイート・140件が成功した。
- リポジトリ指定の独立した検証先でDebugアプリのビルドが成功した。
- 明示的に実行する非表示のネイティブウィンドウテストで、初期分割比率、モデル更新後の手動分割位置の維持、840 × 400での左右独立した長文スクロール、リサイズによる追加送信がないことを確認する。通常の検証で除外される`PopupControllerTests`に配置する。
- 1040 × 620と840 × 400の非表示AppKit描画を選択画像と見比べた。これは内部の表示確認であり、標準ウィンドウ枠の表示や実デスクトップでのフォーカス動作の証明ではない。
- 実行中のアプリは再起動していない。実際のマウス操作、アクティブな標準タイトルバーの見た目、VoiceOver、IMEは独立した実画面確認として残る。既存のネイティブウィンドウテスト全体は実行していない。
