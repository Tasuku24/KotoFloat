# Phase 1 verification / 第1段階の検証

## English

### Implemented scope

Menu bar, settings, configurable shortcut, fixed English/Japanese sample, drag/resize/scroll, independent topmost toggle, previous-position and near-pointer placement, frame persistence and display recovery. No text capture or LLM calls.

### Automated evidence (2026-10-30)

- Swift 6.4 / Xcode 27.1 on the development Mac; deployment target macOS 15.
- `swift test`: 21 tests pass, covering geometry, corrupt preferences, persistence, native focus and Escape handling, close/reopen, topmost changes, offscreen recovery, long-text scrolling without resizing, and controller/panel lifetime.
- Geometry and persistence tests failed before their behavior was implemented. Native panel tests initially failed on focus, dismissal, topmost, persistence, and display recovery; the implemented behavior passes.
- `xcodebuild -project KotoFloat.xcodeproj -scheme KotoFloat -configuration Debug -derivedDataPath .build/xcode build`: passes. App resources include both localizations and the shortcut recorder's resources. `LSUIElement` is true and the deployment target is 15.0.
- The built app launches as a menu bar process. The local ad-hoc signature passes `codesign --verify --deep --strict`.
- Rendered native content previews were inspected for the sample popup and settings. These previews are not evidence of physical mouse or AutoRaise behavior.

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

Physical AutoRaise, shortcut recording/global dispatch, keyboard routing in other apps, monitor disconnect/reconnect, Spaces/fullscreen apps, and VS Code F5 debugger launch are not yet independently verified. Native tests simulate window focus and dispatch a local Escape event; they do not reproduce the complete user's workflow. This preview is locally signed, not Developer ID signed or notarized. An unrelated installed iOS simulator-service version warning appears in Xcode logs; the macOS app build succeeds.

## 日本語

### 実装範囲

メニューバー、設定、変更可能なショートカット、固定の英日サンプル、移動・サイズ変更・スクロール、独立した最前面固定、前回位置・カーソル付近の配置、位置保存、画面外からの復旧。文章取得やLLM通信は含みません。

### 自動検証の記録（2026-10-30）

- 開発MacのSwift 6.4 / Xcode 27.1で検証。対象OSの下限はmacOS 15。
- `swift test`：21テスト成功。配置、不正な設定データ、保存、実ウィンドウのフォーカスとEsc、閉じる・再表示、最前面切り替え、画面外からの復旧、長文のスクロールとサイズ維持、制御処理・パネルの解放を確認。
- 配置と保存は実装前のテスト失敗を確認しました。パネルも最初はフォーカス・終了条件・最前面・位置保存・画面復旧で失敗し、実装後に成功しています。
- `xcodebuild -project KotoFloat.xcodeproj -scheme KotoFloat -configuration Debug -derivedDataPath .build/xcode build`：成功。アプリに英日両言語とショートカット入力部のリソースを含み、`LSUIElement` はtrue、対応OS下限は15.0です。
- ビルドしたアプリがメニューバー用プロセスとして起動。ローカルのアドホック署名は `codesign --verify --deep --strict` に成功。
- 実際のネイティブビューから生成したサンプルと設定画面の画像を確認しました。画像は物理的なマウス操作やAutoRaise動作の証拠にはしません。

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

実際のAutoRaise操作、ショートカットの記録・グローバル呼び出し、別アプリへのキー入力、実モニターの着脱、Spaces・全画面アプリ、VS CodeのF5デバッグ起動はまだ独立した検証が済んでいません。ネイティブテストはフォーカス操作とパネル内のEscイベントを再現しますが、利用者の操作全体を再現するものではありません。ローカル署名のプレビューであり、Developer ID署名・公証は未実施です。Xcodeログにはインストール済みiOSシミュレーターサービスのバージョン警告が出ますが、macOSアプリのビルドは成功しています。
