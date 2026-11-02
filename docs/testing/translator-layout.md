# Translator layout

## English

The user selected the third generated concept (side-by-side comparison) on 2026-11-02. This change applies only to the Translator editor. The popup retains its current layout, hidden-source default, adaptive height, and focus behavior. Liquid Glass is excluded.

The Translator opens with the source on the left and a wider translation on the right. Its native split view starts at 36% source width; AppKit owns subsequent divider dragging and window resizing. The source can be collapsed and restored without replacing the document. Both text areas scroll independently. The initial editor size is 1040 × 620 points and the minimum is 840 × 400; existing saved window frames remain in use.

Reuse the popup's compact toolbar and existing button-clearance measurement. The editor hides its separate native window title and draws an opaque toolbar beneath the native controls. Target language, favorites, copy, and the more menu occupy this single row. The source-language picker sits above the source text.

The footer keeps status, details, Undo/Redo, and Translate/Retranslate or Stop available. The more menu contains original visibility, result details, source language, swap, glossary selection/management, clear, and settings. Result details retain request direction, previous request source, glossary review, character counts, and the generated original of an edited translation. Destructive confirmation remains outside the scrolling text. Existing TranslationModel ownership, explicit translation, draft protection, incomplete-copy protection, request snapshots, and undo history are unchanged.

### Verification of the 2026-11-02 implementation

- Routine background suite: 140 tests in 22 suites passed.
- Debug application build passed with the repository's separate validation build path.
- An explicitly run, non-visible native-window test verifies the initial split, retention of a manually moved divider after model updates, independent long-text scrolling at 840 × 400, and no additional translation request from resizing. It lives in `PopupControllerTests`, which routine background checks exclude.
- Non-visible AppKit rendering at 1040 × 620 and 840 × 400 was inspected against the selected concept. This checks the hosted content; it does not show native window decorations or prove real desktop focus behavior.
- The running app was not restarted. Real pointer interactions, active native titlebar appearance, VoiceOver, and IME acceptance remain separate live checks. The existing broader native-window suite was not run.

### Native button alignment follow-up (2026-11-03)

The user reported that the native close/minimize/zoom buttons were above the title in both the Translator and popup. A non-visible native regression test reproduced an 8-point vertical difference from the toolbar's language control. The shared toolbar now moves the existing native buttons onto its measured center line, retaining their horizontal positions and native behavior. Updates run after layout and window resizing, and are coalesced on the main queue. Full-screen controls remain under macOS management.

The native test covers the Translator, standard popup panel, and AutoRaise-compatible popup window at two sizes. It checks alignment and native hit testing without showing or focusing a window. This does not establish full-screen, VoiceOver, or actual pointer-interaction acceptance.

The regression test failed before the fix and passed afterward for all three window variants. The 140-test background suite, Debug build, strict signature verification, and whitespace check passed. The real app was gracefully restarted. During the live capture, macOS displayed its screen-sharing indicator in the native-button area, so that capture does not provide an unobstructed visual comparison of the buttons.

### Post-display reflow correction (2026-11-03)

The user subsequently confirmed that the visible buttons were still too high. Runtime diagnostics reproduced AppKit restoring all three button centers to 16 points after the toolbar had aligned them at 24 points. The original test only checked content layout and resize, so it did not catch this later native-window update.

Observe the window's update and key-activation notifications as well as resizing. The existing coalesced main-queue adjustment then restores alignment after AppKit's titlebar reflow. No timers, polling, new input monitors, or replacement window controls are involved. Temporary coordinate logging was removed after checking the real app: the post-update centers returned to 24 points and remained there in subsequent updates.

The regression now covers hidden and ordered windows for all three variants at two sizes. It replays the measured native position reset, calls the real AppKit window update, and checks alignment plus hit testing for the native controls and language picker. Test windows are transparent, ignore mouse input, and do not become key; macOS may constrain an ordered window back onto a display despite an offscreen origin. Full-screen, VoiceOver, and physical pointer-action acceptance remain separate.

Final verification passed: all three native regression cases, 140 background tests in 22 suites, Debug build, strict signature verification, and whitespace checks. The final app, with temporary diagnostic logging removed, was restarted and the Translator displayed.

## 日本語

利用者は2026年11月2日に、生成した3案目の左右比較レイアウトを選択した。変更対象はTranslatorの編集ウィンドウのみとする。ポップアップの現在のレイアウト、原文の初期非表示、本文に応じた高さ、フォーカス動作は維持する。Liquid Glassは使用しない。

Translatorは左に原文、右に幅の広い訳文を表示する。標準の分割ビューを初期状態で原文36%とし、その後の境界線のドラッグとウィンドウのリサイズはAppKitに任せる。文書を置き換えずに原文を折りたたみ・再表示できる。両方の本文は独立してスクロールする。初期サイズは1040 × 620ポイント、最小サイズは840 × 400ポイントとし、既存の保存済みウィンドウ枠は引き続き使用する。

ポップアップのコンパクトな上部バーと、標準ウィンドウボタンとの余白を測る処理を再利用する。エディタの独立した標準タイトル表示を隠し、標準ボタンの下に不透明な上部バーを配置する。翻訳先言語、お気に入り、コピー、その他メニューを1行にまとめる。翻訳元言語は原文の上で選択する。

下部には状態、詳細、Undo／Redo、翻訳／再翻訳または停止を置く。その他メニューに原文表示、結果の詳細、翻訳元言語、入れ替え、用語集の選択・管理、クリア、設定をまとめる。結果の詳細には、翻訳方向、前回送信した原文、用語集の確認、文字数、編集前の生成訳を残す。破棄確認はスクロールする本文の外に維持する。既存のTranslationModelによる状態管理、明示的な翻訳、下書き保護、未完了訳のコピー制限、送信時点の設定、Undo履歴は変更しない。

### 2026年11月2日の実装に対する検証

- 通常のバックグラウンドテスト：22スイート・140件が成功した。
- リポジトリ指定の独立した検証先でDebugアプリのビルドが成功した。
- 明示的に実行する非表示のネイティブウィンドウテストで、初期分割比率、モデル更新後の手動分割位置の維持、840 × 400での左右独立した長文スクロール、リサイズによる追加送信がないことを確認する。通常の検証で除外される`PopupControllerTests`に配置する。
- 1040 × 620と840 × 400の非表示AppKit描画を選択画像と見比べた。これは内部の表示確認であり、標準ウィンドウ枠の表示や実デスクトップでのフォーカス動作の証明ではない。
- 実行中のアプリは再起動していない。実際のマウス操作、アクティブな標準タイトルバーの見た目、VoiceOver、IMEは独立した実画面確認として残る。既存のネイティブウィンドウテスト全体は実行していない。

### 標準ボタンの整列修正（2026年11月3日）

Translatorとポップアップの両方で、標準の閉じる・最小化・拡大ボタンがタイトルより上にあるとの報告を受けた。非表示のネイティブ回帰テストで、上部バーの言語選択と8ポイントの高さの差を再現した。共通の上部バーで実測した中心線に既存の標準ボタンを移動し、横位置と標準の動作を維持する。配置とウィンドウのリサイズ後に更新し、メインキューで処理をまとめる。フルスクリーンの標準ボタンはmacOSの管理に任せる。

ネイティブテストはTranslator、通常のポップアップパネル、AutoRaise互換のポップアップウィンドウを、それぞれ2種類のサイズで確認する。ウィンドウを表示・フォーカスせずに、整列と標準のクリック判定を確認する。フルスクリーン、VoiceOver、実際のマウス操作の動作確認を意味するものではない。

回帰テストは修正前に失敗し、修正後は3種類すべてで成功した。通常の140件のテスト、Debugビルド、厳密な署名確認、空白検査も成功した。実アプリは通常の終了操作を経て再起動した。実画面の取得中はmacOSの画面共有インジケータが標準ボタンの場所に表示されたため、その取得画像だけではボタンを遮らない見た目の比較はできていない。

### 表示後の再配置への対応（2026年11月3日）

その後、利用者から実画面のボタンがまだ上にあるとの報告を受けた。実アプリの座標記録により、上部バーで中心を24ポイントに揃えた後、AppKitが3つのボタンの中心を16ポイントに戻すことを再現した。元のテストは本文の配置とリサイズだけを確認しており、その後の標準ウィンドウの更新を捉えていなかった。

リサイズに加え、ウィンドウの描画更新とキー状態への切り替えの通知を監視する。既存のメインキューでまとめる調整処理により、AppKitのタイトルバー再配置後にも整列を回復させる。タイマー、ポーリング、新しい入力監視、独自ボタンへの置き換えは追加しない。実アプリで更新後に中心が24ポイントへ戻り、続く更新でも維持されることを確認した後、一時的な座標記録を削除した。

回帰テストは非表示と表示済みの両方について、3種類のウィンドウを2つのサイズで確認する。実測した標準ボタンの位置の巻き戻りを再現し、実際のAppKitのウィンドウ更新を呼び出してから、整列と標準ボタン・言語選択のクリック判定を確認する。検証ウィンドウは透明にし、マウス入力を受け取らず、キー状態にしない。画面外の座標を指定しても、macOSが表示時に画面内へ戻す場合があるためである。フルスクリーン、VoiceOver、実際のマウス操作の動作確認は独立した確認として残る。

最終確認では、3種類のネイティブ回帰テスト、22スイート・140件の通常テスト、Debugビルド、厳密な署名確認、空白検査が成功した。一時的な診断記録を外した最終版を再起動し、Translatorを表示した。
