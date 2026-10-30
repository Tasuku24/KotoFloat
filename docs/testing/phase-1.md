# Phase 1 verification / 第1段階の検証

## English

### Implemented scope

Menu bar, settings, configurable shortcut, fixed English/Japanese sample, drag/resize/scroll, independent topmost toggle, previous-position and near-pointer placement, frame persistence and display recovery. No text capture or LLM calls.

### Automated evidence (2026-10-30)

- Swift 6.4 / Xcode 27.1 on the development Mac; deployment target macOS 15.
- `swift test`: 25 tests pass, covering geometry, corrupt preferences, persistence, native focus and Escape handling, close/reopen, topmost changes, offscreen recovery, long-text scrolling without resizing, controller/panel lifetime, focus-mode persistence, and switching modes without losing text or geometry.
- Geometry and persistence tests failed before their behavior was implemented. Native panel tests initially failed on focus, dismissal, topmost, persistence, and display recovery; the implemented behavior passes.
- `xcodebuild -project KotoFloat.xcodeproj -scheme KotoFloat -configuration Debug -derivedDataPath .build/xcode build`: passes. App resources include both localizations and the shortcut recorder's resources. `LSUIElement` is true and the deployment target is 15.0.
- The built app launches as a menu bar process. The local ad-hoc signature passes `codesign --verify --deep --strict`.
- Rendered native content previews were inspected for the sample popup and settings. These previews are not evidence of physical mouse or AutoRaise behavior.

### AutoRaise regression and compatibility mode

The user confirmed persistence and focused Escape, but reported that AutoRaise stopped moving focus away from the popup. The installed AutoRaise 5.7 focus-first configuration (`-delay 0 -focusDelay 1 -pollMillis 50`) was reproduced with an isolated source window and controlled pointer input. AutoRaise requires the currently focused window to be a main window and rejects dialog roles in this path; see [AutoRaise.mm](https://github.com/sbmpost/AutoRaise/blob/master/AutoRaise.mm).

Before the fix, the popup reported `AXMain = false` and `AXSystemDialog`; hovering the source did not return focus. A regular NSWindow reported `AXMain = true` and `AXStandardWindow`; the same live probe returned focus to the source, kept the popup visible, and confirmed showing the popup did not steal focus. The probe moved/restored the pointer; production KotoFloat does not move it. AutoRaise preferences were not modified.

At the user's request, this behavior is now opt-in: Standard remains the default; AutoRaise compatibility recreates the native window and preserves frame/content/visibility. Unit tests check the compatibility window's main-window capability and accessibility role. They cannot establish cross-process activation in an unhosted test runner; the live probe supplies that separate evidence. Final user confirmation through the new setting is pending. Other AutoRaise settings are not yet verified.

Both Debug and universal Release (arm64/x86_64) builds pass. The app now declares English and Japanese in `CFBundleLocalizations`. A runtime localization probe using the built app's Info.plist and resource bundles resolves `Sample` to `サンプル` and `AutoRaise compatibility` to `AutoRaise互換` with Japanese preferred. An independent review identified this packaging issue; it was fixed and verified. No other critical, important, or minor findings were reported in that review.

### Focused recheck (2026-10-31)

Rechecked the Phase 1 foundation against current revision `9863dce`, which includes the later translation and editor work. This does not replace the historical Phase 1 results above or establish full desktop acceptance.

- `nice -n 10 swift test --jobs 2 --filter 'PopupGeometryTests|PopupPreferencesTests|AppLocalizationTests'`: **21 tests passed**. This covers placement, offscreen recovery, invalid settings, persistence across preference instances, and actual English/Japanese resource lookup; some cases were added after Phase 1.
- `nice -n 10 swift test --jobs 2 --filter 'PopupControllerTests/(compatibilityMode|standardMode|switchingMode|closingAndReleasing|longText|escapeKeyEvent|showingPreserves|focusLoss|closeButton|changingTopmost|recoversOffscreen)'`: **12 native-window tests passed**. Test windows were briefly shown with isolated preferences. They verified focus retention, key-only Escape, close/reopen, topmost changes, mode switching, long-content scrollability/frame stability, offscreen recovery, and window lifetime. Later capture/editor tests were outside this focused run.
- The low-priority Debug build with two jobs succeeded in `.build/validation`, and `codesign --verify --deep --strict` passed. The built bundle has `LSUIElement = true`, macOS 15.0 as its minimum version, both declared localizations, the shortcut recorder resources, and **228 matching English/Japanese localization keys**.
- VS Code's task/launch files parse successfully, Swift extension **2.18.0** is installed, and Xcode's `lldb-dap` executable is available. These are prerequisite checks, not an actual F5 launch.
- Two displays were detected. No physical display disconnect/reconnect, Spaces/fullscreen transition, pointer-driven AutoRaise workflow, or shortcut-recorder interaction was performed. The test runner dispatched Escape directly to its own window; this does not prove keyboard routing in another application. Product code and user settings were not changed, and KotoFloat itself was not launched or restarted.

The focused run passed **33 tests in total**. Logs are in `.build/phase1-verification-20261031/` (ignored by Git). The manual items below remain open; the earlier general report of normal operation does not identify which individual acceptance cases were exercised.

### Manual acceptance checklist

Use the built app, with the normal AutoRaise configuration left enabled. Do not infer these outcomes from automated tests. In the current app, use **Show sample popup** for fixed-text layout checks; the global shortcut now captures selected text and can translate it using the saved connection.

- [ ] With text selected in another app, press ⌃⌥⌘T. The popup appears and typing still goes to the original app.
- [ ] Move the pointer to the original app and let AutoRaise change focus. The popup remains visible.
- [ ] Press Escape in the original app. Its normal Escape action works and the popup stays open.
- [ ] Focus the popup, then press Escape. Only the popup closes. Reopen with the shortcut.
- [ ] Drag the title bar away from the original text, resize it, close it, and reopen. Position and size are preserved, including after quitting/relaunching.
- [ ] Use long text. Scroll it and confirm the window remains at the same position and size.
- [ ] Change/clear the shortcut in Settings and verify the new binding. Disable topmost and confirm focus loss still does not close the popup.
- [ ] Use a second physical display, move the popup there, then disconnect it. Confirm the whole popup can be reached on the remaining display.

### Limits

Final user acceptance of the AutoRaise mode switch, shortcut recording/clearing (default global dispatch was exercised), keyboard routing in other apps, monitor disconnect/reconnect, Spaces/fullscreen apps, and VS Code F5 debugger launch are not yet independently verified. Native tests simulate window focus and dispatch a local Escape event; they do not reproduce the complete user's workflow. This preview is locally signed, not Developer ID signed or notarized. An unrelated installed iOS simulator-service version warning appears in Xcode logs; the macOS app build succeeds.

## 日本語

### 実装範囲

メニューバー、設定、変更可能なショートカット、固定の英日サンプル、移動・サイズ変更・スクロール、独立した最前面固定、前回位置・カーソル付近の配置、位置保存、画面外からの復旧。文章取得やLLM通信は含みません。

### 自動検証の記録（2026-10-30）

- 開発MacのSwift 6.4 / Xcode 27.1で検証。対象OSの下限はmacOS 15。
- `swift test`：25テスト成功。配置、不正な設定データ、保存、実ウィンドウのフォーカスとEsc、閉じる・再表示、最前面切り替え、画面外からの復旧、長文のスクロールとサイズ維持、制御処理・パネルの解放、フォーカス方式の保存、切り替え時の文章・位置保持を確認。
- 配置と保存は実装前のテスト失敗を確認しました。パネルも最初はフォーカス・終了条件・最前面・位置保存・画面復旧で失敗し、実装後に成功しています。
- `xcodebuild -project KotoFloat.xcodeproj -scheme KotoFloat -configuration Debug -derivedDataPath .build/xcode build`：成功。アプリに英日両言語とショートカット入力部のリソースを含み、`LSUIElement` はtrue、対応OS下限は15.0です。
- ビルドしたアプリがメニューバー用プロセスとして起動。ローカルのアドホック署名は `codesign --verify --deep --strict` に成功。
- 実際のネイティブビューから生成したサンプルと設定画面の画像を確認しました。画像は物理的なマウス操作やAutoRaise動作の証拠にはしません。

### AutoRaiseの不具合修正と互換モード

利用者は表示維持とフォーカス時のEscを確認しましたが、ポップアップから別アプリへAutoRaiseで戻れない問題を報告しました。インストール済みAutoRaise 5.7のフォーカス優先設定（`-delay 0 -focusDelay 1 -pollMillis 50`）で、専用の原文ウィンドウと制御したポインター操作を使って再現しました。この経路では現在の画面がメインウィンドウであることが求められ、ダイアログとして扱われる画面は除外されます。[AutoRaise.mm](https://github.com/sbmpost/AutoRaise/blob/master/AutoRaise.mm)を参照してください。

修正前は `AXMain = false`、`AXSystemDialog` で、原文へホバーしても戻れませんでした。通常のNSWindowでは `AXMain = true`、`AXStandardWindow` となり、同じ実機テストで原文へのフォーカス復帰、ポップアップの表示維持、表示時に元アプリのフォーカスを奪わないことを確認しました。テストではポインターを移動して復元しましたが、KotoFloat本体は移動しません。AutoRaiseの設定は変更していません。

利用者の要望でこの方式を選択制にしました。既定は標準モードで、AutoRaise互換モードは位置・文章・表示状態を保ってウィンドウを作り直します。単体テストでは互換ウィンドウがメインになれることとアクセシビリティの役割を確認します。アプリに組み込まれていないテスト実行環境では別プロセス間のアクティブ化を証明できないため、上記の実機テストを別の証拠として扱います。新しい設定からの最終的な利用者確認は保留です。AutoRaiseのほかの設定は未検証です。

DebugとユニバーサルRelease（arm64/x86_64）のビルドが成功しています。アプリの `CFBundleLocalizations` に英語・日本語を宣言しました。ビルド済みアプリのInfo.plistとリソースを使った実行時の言語確認で、日本語優先時に `Sample` が「サンプル」、`AutoRaise compatibility` が「AutoRaise互換」になることを確認しました。このパッケージ構成の問題は別のレビュアーが指摘し、修正・検証しています。そのレビューにはほかの重大・重要・軽微な指摘はありませんでした。

### 対象を絞った再検証（2026-10-31）

後続の翻訳・エディタ実装を含む現在の `9863dce` で、第1段階の基礎動作を再確認しました。上記の当時の結果を置き換えたり、実際のデスクトップ操作全体を確認済みにしたりするものではありません。

- `nice -n 10 swift test --jobs 2 --filter 'PopupGeometryTests|PopupPreferencesTests|AppLocalizationTests'`：**21件成功**。配置、画面外からの復旧、不正な設定、設定オブジェクト間の保存、実際の英日リソースの読み出しを確認しました。一部は第1段階以降に追加された項目です。
- `nice -n 10 swift test --jobs 2 --filter 'PopupControllerTests/(compatibilityMode|standardMode|switchingMode|closingAndReleasing|longText|escapeKeyEvent|showingPreserves|focusLoss|closeButton|changingTopmost|recoversOffscreen)'`：**実ウィンドウを使う12件が成功**。独立した設定を使うテスト用ウィンドウを一時的に表示し、フォーカス保持、フォーカス中だけのEsc、閉じる・再表示、最前面切り替え、モード切り替え、長文のスクロール領域と位置・サイズ維持、画面外からの復旧、ウィンドウ解放を確認しました。後続の文章取得・エディタのテストは今回の対象外です。
- 優先度を下げ、並列処理を2つに制限したDebugビルドが `.build/validation` で成功し、`codesign --verify --deep --strict` も成功しました。生成したアプリで `LSUIElement = true`、対応OS下限15.0、英日言語の宣言、ショートカット入力部のリソース、**英日228キーの一致**を確認しました。
- VS Codeのタスク・起動設定が正しいJSONであること、Swift拡張機能 **2.18.0** の導入、Xcodeの `lldb-dap` 実行ファイルの存在を確認しました。これは前提条件の確認であり、F5による実際の起動確認ではありません。
- 接続中の画面を2台認識しました。実モニターの着脱、Spaces・全画面への遷移、ポインター操作によるAutoRaiseの一連の動作、ショートカット入力部の操作は実施していません。Escはテスト用ウィンドウへ直接送っており、別アプリへのキー入力の証明にはなりません。製品コードと利用者の設定は変更せず、KotoFloat本体の起動・再起動も行っていません。

今回の対象は**合計33テストが成功**しました。ログは `.build/phase1-verification-20261031/`（Git対象外）に保存しています。下記の手動確認項目は未完了のままです。以前の正常動作の報告だけでは、個々の確認項目の実施範囲を特定していません。

### 手動確認チェックリスト

通常のAutoRaise設定を有効にしたまま、ビルドしたアプリで確認してください。自動テストから結果を推測しないでください。現在のアプリで固定文の配置を確認するときは **サンプルを表示** を使います。グローバルショートカットは現在、選択文を取得し、保存済みの接続設定で翻訳する動作になっています。

- [ ] 別アプリで文章を選択して⌃⌥⌘T。ポップアップが表示され、文字入力は元アプリへ届く。
- [ ] 原文側へポインターを移し、AutoRaiseでフォーカスを変更してもポップアップが残る。
- [ ] 元アプリでEsc。元アプリの通常動作が働き、ポップアップは残る。
- [ ] ポップアップにフォーカスしてEsc。ポップアップだけ閉じ、ショートカットで再表示できる。
- [ ] タイトルバーで原文から離し、サイズを変更して閉じ、再表示。終了・再起動も含めて位置とサイズが復元される。
- [ ] 長文を表示してスクロールしても、ウィンドウの位置・サイズが変わらない。
- [ ] 設定でショートカットを変更・解除して動作を確認。最前面固定を無効にしてもフォーカス喪失で閉じない。
- [ ] 実際の第2画面へ移動してから切断し、残った画面でポップアップ全体へアクセスできる。

### 未確認事項と制限

AutoRaiseモード切り替え後の最終的な利用者確認、ショートカットの記録・解除（初期設定の呼び出しは実施済み）、別アプリへのキー入力、実モニターの着脱、Spaces・全画面アプリ、VS CodeのF5デバッグ起動はまだ独立した検証が済んでいません。ネイティブテストはフォーカス操作とパネル内のEscイベントを再現しますが、利用者の操作全体を再現するものではありません。ローカル署名のプレビューであり、Developer ID署名・公証は未実施です。Xcodeログにはインストール済みiOSシミュレーターサービスのバージョン警告が出ますが、macOSアプリのビルドは成功しています。
