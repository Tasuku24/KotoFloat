# KotoFloat

[English](#english) | [日本語](#日本語)

## English

Translate selected text without leaving your current task. KotoFloat is a macOS translation app project built around glossaries and local LLMs.

### Development status

Phase 1 is implemented: a menu bar app with a movable, resizable sample popup and settings. The popup preserves source-app focus when shown, stays open across focus changes, and closes with Escape only while it has keyboard focus. It remembers position and size, offers near-pointer placement, and lets you toggle always-on-top independently. The shortcut defaults to **Control–Option–Command–T** and can be changed or cleared in Settings.

This is a **local development preview with fixed text**. Selected-text capture, LLM translation, glossaries, and the translation editor are planned in later phases. There is no notarized downloadable release yet. Real AutoRaise and physical multi-display acceptance are tracked separately in the [Phase 1 verification record](docs/testing/phase-1.md).

### Build and run

Requirements: macOS 15 or later, Xcode with the macOS SDK and a Swift 6 toolchain. Internet access is needed for the initial KeyboardShortcuts package download.

**Xcode:** open `KotoFloat.xcodeproj`, select the **KotoFloat** scheme and **My Mac**, then Run. No Apple developer account is needed for this locally signed preview.

**VS Code:** open the repository folder and install the recommended Swift extension. `Package.swift` enables code navigation, diagnostics, and Swift package tests. Run **Tasks: Run Task → Run macOS app / macOSアプリを起動**, or press F5 to use the included LLDB launch configuration. Xcode must still be installed. The native app and package share the same implementation.

From a terminal in the repository:

```sh
swift test
xcodebuild -project KotoFloat.xcodeproj -scheme KotoFloat -configuration Debug -derivedDataPath .build/xcode build
open .build/xcode/Build/Products/Debug/KotoFloat.app
```

The app appears in the menu bar rather than the Dock. Settings opens on first launch. Choose **Show sample popup** or press **⌃⌥⌘T**. Drag the title bar to move it and its edges to resize it. **Try long text** demonstrates scrolling without automatic window resizing. Close the popup with its close button or focus it and press Escape; quit the app from the menu bar.

Native window tests require a logged-in graphical macOS session and briefly show test windows. They use separate settings domains. Pure geometry and persistence tests can also run separately with `swift test --filter 'PopupGeometryTests|PopupPreferencesTests'`. In Xcode, open `Package.swift` to run the package's tests; the app scheme is for building and running the app.

### Project structure

- `App/`: the macOS application entry point.
- `Sources/KotoFloatKit/`: AppKit popup management, SwiftUI views, preferences, and localized resources.
- `Tests/KotoFloatKitTests/`: placement, persistence, and native window behavior tests.
- `KotoFloat.xcodeproj/`: the app wrapper linking the local Swift package.
- `docs/superpowers/plans/`: the [six-phase roadmap](docs/superpowers/plans/2026-10-29-initial-release-phases.md) and detailed phase plans.

### Goals for the first version

- Translate text selected in another app with a keyboard shortcut and display the result in a floating popup.
- Include glossaries from the first version, using preferred translations and contextual notes to guide translation.
- Connect to a self-hosted local LLM server without tying the app to a specific model. LM Studio's OpenAI-compatible API is the first integration target.
- Let users copy translations and edit them in a shared main window.

The first release includes all six phases. Final model selection and click-based alternative translations come afterward. Translation and glossary logic will remain separate from the UI so that the popup and main window can share it.

### Data handling principles

- Phase 1 does not capture selected text or make translation requests.
- Future translation input goes only to the endpoint configured by the user.
- Keep credentials, personal glossaries, translation history, and model files out of Git.
- Store future credentials in the macOS Keychain.
- Clearly distinguish implemented features from planned and unverified features.

### License

No license has been selected. This project does not currently grant an open-source license. KeyboardShortcuts is a separate dependency distributed under its own MIT license.

---

## 日本語

選択した文章を、その場で翻訳する。用語集とローカルLLMを活用するmacOS向け翻訳アプリの開発プロジェクトです。

### 開発状況

第1段階を実装しました。移動・サイズ変更できるサンプルのポップアップ、設定画面、メニューバー常駐に対応しています。ポップアップは表示時に元アプリのフォーカスを奪わず、フォーカスが移っても表示を維持し、キーボードフォーカスがあるときだけEscで閉じます。位置・サイズの保存、カーソル付近への配置、独立した最前面固定の切り替えに対応しています。ショートカットの初期設定は **Control–Option–Command–T** で、設定から変更・解除できます。

現在は **固定文章を表示するローカル開発用プレビュー** です。選択文章の取得、LLM翻訳、用語集、翻訳エディタは後続の段階で実装します。公証済みの配布版はまだありません。実際のAutoRaise操作と物理的な複数画面の確認は、[第1段階の検証記録](docs/testing/phase-1.md)で別途管理します。

### ビルドと起動

必要環境：macOS 15以降、macOS SDKとSwift 6のツールチェーンを含むXcode。初回はKeyboardShortcutsの取得にインターネット接続が必要です。

**Xcode：** `KotoFloat.xcodeproj` を開き、**KotoFloat** スキームと **My Mac** を選んで実行します。ローカル署名のプレビューにはApple開発者アカウントは不要です。

**VS Code：** リポジトリフォルダを開き、推奨されるSwift拡張機能をインストールしてください。`Package.swift` により定義への移動、エラー表示、Swiftパッケージのテストが利用できます。**Tasks: Run Task → Run macOS app / macOSアプリを起動** を実行するか、F5で付属のLLDB設定からデバッグできます。Xcodeのインストールも必要です。アプリとパッケージは同じ実装を共有します。

リポジトリ内のターミナルからは次の操作で確認できます。

```sh
swift test
xcodebuild -project KotoFloat.xcodeproj -scheme KotoFloat -configuration Debug -derivedDataPath .build/xcode build
open .build/xcode/Build/Products/Debug/KotoFloat.app
```

Dockではなくメニューバーに表示されます。初回は設定画面が開きます。**サンプルを表示** または **⌃⌥⌘T** でポップアップを開き、タイトルバーで移動、端のドラッグでサイズを変更してください。**長文を試す** では自動リサイズせずスクロールする動作を確認できます。閉じるボタン、またはポップアップにフォーカスした状態のEscで閉じます。アプリの終了はメニューバーから行います。

ネイティブウィンドウのテストにはログイン済みのmacOS画面が必要で、テスト中は一時的にウィンドウが表示されます。設定保存先はテスト専用です。配置計算と保存のテストだけなら `swift test --filter 'PopupGeometryTests|PopupPreferencesTests'` でも実行できます。Xcodeでパッケージのテストを実行するときは `Package.swift` を開いてください。アプリのスキームはビルド・起動用です。

### フォルダ構成

- `App/`：macOSアプリの起動処理。
- `Sources/KotoFloatKit/`：AppKitのポップアップ制御、SwiftUI画面、設定、言語リソース。
- `Tests/KotoFloatKitTests/`：配置、保存、実際のウィンドウ動作のテスト。
- `KotoFloat.xcodeproj/`：ローカルのSwiftパッケージを利用するアプリ。
- `docs/superpowers/plans/`：[6段階の開発計画](docs/superpowers/plans/2026-10-29-initial-release-phases.md)と各段階の詳細計画。

### 初期版で目指すこと

- 他のアプリで選択した文章を、ショートカットで翻訳してポップアップ表示する。
- 用語集を初期版から搭載し、指定した訳語や文脈を翻訳に反映する。
- 自分で運用するローカルLLMサーバーへ接続し、モデルを固定しない。最初の接続対象はLM StudioのOpenAI互換API。
- 翻訳結果をコピーし、共通のメイン画面で編集できるようにする。

初期版には6段階すべてを含めます。最終的なモデル選定とクリックによる別訳候補の選択はその後です。翻訳・用語集の処理を画面から分離し、ポップアップとメイン画面で共有します。

### データの取り扱い方針

- 第1段階は選択文章の取得や翻訳リクエストを行いません。
- 将来の翻訳対象は、利用者が指定した接続先だけへ送信します。
- 接続資格情報、個人の用語集、翻訳履歴、モデルファイルをGitへ登録しません。
- 将来の資格情報はmacOSキーチェーンへ保存します。
- 実装済み・計画中・未検証を明確に区別します。

### ライセンス

未選定です。現時点ではオープンソースライセンスを付与していません。依存ライブラリのKeyboardShortcutsは独立したMITライセンスで配布されています。
