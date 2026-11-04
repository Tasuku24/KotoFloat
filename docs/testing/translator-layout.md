# Translator layout

## English

The user selected the third generated concept (side-by-side comparison) on 2026-11-02. This change applies only to the Translator editor. The popup retains its current layout, hidden-source default, adaptive height, and focus behavior. Liquid Glass is excluded.

The Translator opens with the source on the left and a wider translation on the right. Its native split view starts at 36% source width; AppKit owns subsequent divider dragging and window resizing. The source can be collapsed and restored without replacing the document. Both text areas scroll independently. The initial editor size is 1040 × 620 points and the minimum is 840 × 400; existing saved window frames remain in use.

Reuse the popup's compact toolbar and existing button-clearance measurement. The editor hides its separate native window title and draws an opaque toolbar beneath the native controls. Source visibility and the more menu occupy this row. Source and target language pickers sit in aligned headers above their respective text, with favorites available in the target picker. A labeled Copy button sits beside the translation.

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

### Leading margin refinement (2026-11-03)

The user supplied ChatGPT's titlebar as a spacing reference. Increase the leading edge of the native button group from approximately 9 to 16 points by translating the group together. Preserve button size, native spacing, the toolbar's existing vertical center, and title clearance. The same placement runs after AppKit updates in the Translator and both popup modes. The native regression checks the 16-point margin, original button sizes and offsets, alignment, and hit testing before and after replaying native horizontal/vertical resets.

### Translator usability refinement (2026-11-03)

An inspection of the live empty editor identified no in-field entry guidance and a target-language/copy group separated from the result. Apply Product Design's audit and ui-ux-pro-max's empty-state and SwiftUI accessibility guidance: put language selection beside each pane's label, keep Copy beside the result, and keep a source-visibility button available in the toolbar. Add source-entry guidance and a result placeholder that displays the existing model's notice while waiting, stopped, or unable to translate. Completed translations remain editable even when emptied; placeholder overlays never intercept input.

Use native semantic colors and controls, 28-point hit areas for footer icon actions, and a regular-sized Translate/Stop button. Source guidance is also exposed as the text editor's accessibility help. No dependencies, blur, animation, polling, new translation triggers, or changes to the popup layout are introduced.

The native layout regression additionally checks that language pickers align and remain within the host bounds. Optional `KOTOFLOAT_EDITOR_PREVIEW_DIR` captures render hosted content without showing or focusing a window, including empty, long-text/minimum-size, and dark appearances. These captures do not establish native titlebar appearance, VoiceOver, or physical pointer acceptance.

Verification passed: 140 background tests, the focused native layout regression, a clean Debug build, embedded English/Japanese strings, strict signature verification, and whitespace checks. The updated app was gracefully restarted; live source collapse and restoration succeeded, and the editor was left in its side-by-side layout. No live text was changed or sent. VoiceOver and IME acceptance remain unverified. Live screenshots include macOS's window-sharing indicator over the native controls.

### Larger reading and control scale (2026-11-03)

The user requested DeepL-like readability, explicitly excluding imitation of its colors or styling. Increase source text from 16 to 20 points and translation text from 17 to 22 points. Use 14-point pane labels and status, 16-point language selection, 15-point Copy, and 16-point primary actions. Expand pane headers to 72 points and secondary action targets to 36 points; increase text insets and line/paragraph spacing together. Keep the existing colors, initial/saved window sizes, split behavior, and popup layout.

The existing native layout check also inspects a narrow result pane at the minimum window size. Enlarging text reduces the number of visible lines, so independent native scrolling remains essential. Hosted light/dark captures and the focused native check passed; these do not establish VoiceOver or IME acceptance.

## 日本語

利用者は2026年11月2日に、生成した3案目の左右比較レイアウトを選択した。変更対象はTranslatorの編集ウィンドウのみとする。ポップアップの現在のレイアウト、原文の初期非表示、本文に応じた高さ、フォーカス動作は維持する。Liquid Glassは使用しない。

Translatorは左に原文、右に幅の広い訳文を表示する。標準の分割ビューを初期状態で原文36%とし、その後の境界線のドラッグとウィンドウのリサイズはAppKitに任せる。文書を置き換えずに原文を折りたたみ・再表示できる。両方の本文は独立してスクロールする。初期サイズは1040 × 620ポイント、最小サイズは840 × 400ポイントとし、既存の保存済みウィンドウ枠は引き続き使用する。

ポップアップのコンパクトな上部バーと、標準ウィンドウボタンとの余白を測る処理を再利用する。エディタの独立した標準タイトル表示を隠し、標準ボタンの下に不透明な上部バーを配置する。この行には原文の表示切り替えとその他メニューを置く。翻訳元・翻訳先の言語選択は各本文の上に同じ高さで配置し、お気に入りは翻訳先の選択内で使えるようにする。文字付きのコピーボタンを訳文の隣に配置する。

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

### 左余白の調整（2026年11月3日）

利用者が余白の参考として添付したChatGPTのタイトルバーに合わせ、標準ボタン全体を同じ量だけ移動し、左端の余白を約9ポイントから16ポイントへ増やす。ボタンの大きさ、標準の間隔、上部バーの現在の縦の中心線、タイトルとの重なり防止は維持する。Translatorと2種類のポップアップで、AppKit更新後にも同じ配置を適用する。ネイティブ回帰テストで16ポイントの左余白、元のボタンの大きさと相対位置、縦の整列、クリック判定を、標準の横位置・縦位置への巻き戻りの前後で確認する。

### Translatorの使いやすさの改善（2026年11月3日）

実画面の空のエディタを確認し、入力欄内に案内がないことと、翻訳先言語・コピー操作が訳文から離れていることを確認した。Product Designの監査とui-ux-pro-maxの空表示・SwiftUIアクセシビリティの指針を適用し、言語選択を各領域の見出しの隣、コピーを訳文の隣に配置する。原文の表示切り替えは上部に常設する。原文の入力案内と訳文の空表示を追加し、待機・停止・翻訳できない状態では既存モデルの状態説明を表示する。完成訳を空に編集しても編集可能な状態を維持し、案内表示は入力を遮らない。

標準の意味付き色と操作部品を使い、下部のアイコン操作には28ポイントのクリック範囲を設け、翻訳・停止ボタンは標準サイズにする。原文の入力案内はテキストエディタのアクセシビリティ説明にも含める。依存関係、ぼかし、アニメーション、ポーリング、翻訳の自動送信契機は追加せず、ポップアップのレイアウトは変更しない。

ネイティブ配置の回帰テストに、左右の言語選択が揃い、本文領域の枠内に収まることの確認を追加する。任意の`KOTOFLOAT_EDITOR_PREVIEW_DIR`指定で、ウィンドウを表示・フォーカスせず、空表示・長文の最小サイズ・ダーク表示の本文を保存できる。この描画確認だけでは、標準タイトルバーの見た目、VoiceOver、実際のマウス操作の動作確認とはならない。

140件の通常テスト、対象のネイティブ配置テスト、クリーンなDebugビルド、アプリ内の英語・日本語文言、厳密な署名確認、空白検査が成功した。更新版を通常終了後に再起動し、実画面で原文の折りたたみと再表示が成功した。最後は左右分割に戻してある。実アプリの本文の変更・送信は行っていない。VoiceOverとIMEの動作確認は未実施。実画面の取得画像には、標準ボタン上にmacOSの画面共有インジケータが含まれる。

### 本文と操作部品の拡大（2026年11月3日）

利用者はDeepLのような読みやすさを求め、配色や意匠の模倣は明確に除外した。原文を16から20ポイント、訳文を17から22ポイントに拡大する。領域の見出しと状態表示は14ポイント、言語選択は16ポイント、コピーは15ポイント、主要操作は16ポイントとする。見出し行を72ポイント、副操作のクリック範囲を36ポイントに広げ、本文の内側余白と行間・段落間隔も合わせて拡大する。既存の配色、初期・保存済みウィンドウサイズ、分割動作、ポップアップの配置は維持する。

既存のネイティブ配置確認では、最小ウィンドウで訳文領域を狭くした状態も確認する。文字の拡大に伴って一度に表示できる行数は減るため、左右独立の標準スクロールを維持する。ライト・ダークの本文描画と対象のネイティブ検証が成功した。これらはVoiceOverやIMEの動作確認を意味しない。
