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

### Manual acceptance checklist

Use the built app, with the normal AutoRaise configuration left enabled. Do not infer these outcomes from automated tests.

- [ ] With another app focused, press ⌃⌥⌘T. The sample appears and typing still goes to the original app.
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

### 手動確認チェックリスト

通常のAutoRaise設定を有効にしたまま、ビルドしたアプリで確認してください。自動テストから結果を推測しないでください。

- [ ] 別アプリにフォーカスして⌃⌥⌘T。サンプルが表示され、文字入力は元アプリへ届く。
- [ ] 原文側へポインターを移し、AutoRaiseでフォーカスを変更してもポップアップが残る。
- [ ] 元アプリでEsc。元アプリの通常動作が働き、ポップアップは残る。
- [ ] ポップアップにフォーカスしてEsc。ポップアップだけ閉じ、ショートカットで再表示できる。
- [ ] タイトルバーで原文から離し、サイズを変更して閉じ、再表示。終了・再起動も含めて位置とサイズが復元される。
- [ ] 長文を表示してスクロールしても、ウィンドウの位置・サイズが変わらない。
- [ ] 設定でショートカットを変更・解除して動作を確認。最前面固定を無効にしてもフォーカス喪失で閉じない。
- [ ] 実際の第2画面へ移動してから切断し、残った画面でポップアップ全体へアクセスできる。

### 未確認事項と制限

AutoRaiseモード切り替え後の最終的な利用者確認、ショートカットの記録・解除（初期設定の呼び出しは実施済み）、別アプリへのキー入力、実モニターの着脱、Spaces・全画面アプリ、VS CodeのF5デバッグ起動はまだ独立した検証が済んでいません。ネイティブテストはフォーカス操作とパネル内のEscイベントを再現しますが、利用者の操作全体を再現するものではありません。ローカル署名のプレビューであり、Developer ID署名・公証は未実施です。Xcodeログにはインストール済みiOSシミュレーターサービスのバージョン警告が出ますが、macOSアプリのビルドは成功しています。
