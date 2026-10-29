# KotoFloat

[English](#english) | [日本語](#日本語)

## English

Translate selected text without leaving your current task. KotoFloat is a macOS translation app project built around glossaries and local LLMs.

### Development status

Phases 1 and 2 are implemented: a menu bar app with a movable, resizable popup, selected-text capture, and settings. The popup preserves source-app focus when shown, stays open across focus changes, and closes with Escape only while it has keyboard focus. It remembers position and size, offers near-pointer placement, and lets you toggle always-on-top independently. The shortcut defaults to **Control–Option–Command–T** and can be changed or cleared in Settings.

**Standard** focus behavior is the default for people who do not use AutoRaise. If hovering stops moving focus after using the popup, select **Settings → Popup → Focus → Window behavior → AutoRaise compatibility**. The setting is saved and takes effect immediately without losing the popup size, position, or text. Compatibility depends on AutoRaise settings; it is not a promise for every window manager. KotoFloat never moves the mouse pointer.

Settings uses three tabs—**General**, **Popup**, and **Text capture**—without scrolling. Under **General → App language**, choose **Follow system** (the default), **English**, or **日本語**. The choice is saved and updates KotoFloat's screens and menus immediately; unsupported system languages fall back to English. System dialogs and some native controls still follow macOS. Under **Text capture**, **Check again** displays the check time and whether permission is enabled, even when the status has not changed.

This is a **local development preview that captures text**. LLM translation, glossaries, and the translation editor are planned in later phases. There is no notarized downloadable release yet. See [Phase 1 verification](docs/testing/phase-1.md) and [Phase 2 verification](docs/testing/phase-2.md) for actual checks and limitations.

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

The app appears in the menu bar rather than the Dock. Settings opens on first launch. Enable KotoFloat in **System Settings → Privacy & Security → Device Control and Data Access** (called **Accessibility** on earlier macOS versions), select text in another app, and press **⌃⌥⌘T**. The original text and source app appear; translation is not connected yet. If direct access is unavailable, the app tries Copy and asks you to confirm the resulting text. **Enter or paste text…** works without Accessibility permission. **Show sample popup** remains available for layout testing. Drag the title bar to move it and its edges to resize it. **Try long text** demonstrates scrolling without automatic window resizing. Close the popup with its close button or focus it and press Escape; quit the app from the menu bar.

Native window tests require a logged-in graphical macOS session and briefly show test windows. They use separate settings domains. Pure geometry and persistence tests can also run separately with `swift test --filter 'PopupGeometryTests|PopupPreferencesTests'`. In Xcode, open `Package.swift` to run the package's tests; the app scheme is for building and running the app.

### Project structure

- `App/`: the macOS application entry point.
- `Sources/KotoFloatKit/`: AppKit popup management, selected-text capture, clipboard transactions, SwiftUI views, preferences, and localized resources.
- `Tests/KotoFloatKitTests/`: capture lifecycle, clipboard safety, placement, persistence, and native window behavior tests.
- `KotoFloat.xcodeproj/`: the app wrapper linking the local Swift package.
- `docs/superpowers/plans/`: the [six-phase roadmap](docs/superpowers/plans/2026-10-29-initial-release-phases.md) and detailed phase plans.

### Goals for the first version

- Translate text selected in another app with a keyboard shortcut and display the result in a floating popup.
- Include glossaries from the first version, using preferred translations and contextual notes to guide translation.
- Connect to a self-hosted local LLM server without tying the app to a specific model. LM Studio's OpenAI-compatible API is the first integration target.
- Let users copy translations and edit them in a shared main window.

The first release includes all six phases. Final model selection and click-based alternative translations come afterward. Translation and glossary logic will remain separate from the UI so that the popup and main window can share it.

### Data handling principles

- Phase 2 keeps captured text in memory on this Mac and makes no translation requests. It does not log or save source text.
- Copy fallback restores readable clipboard formats only if its observed generation is unchanged; newer updates, app switches, and input interrupt capture. See the verification record for the limits of cross-process clipboard restoration.
- Known empty selections and protected password fields are not copied. Copied text must be confirmed before later translation features can use it.
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

第1・第2段階を実装しました。移動・サイズ変更できるポップアップ、選択文章の取得、設定画面、メニューバー常駐に対応しています。ポップアップは表示時に元アプリのフォーカスを奪わず、フォーカスが移っても表示を維持し、キーボードフォーカスがあるときだけEscで閉じます。位置・サイズの保存、カーソル付近への配置、独立した最前面固定の切り替えに対応しています。ショートカットの初期設定は **Control–Option–Command–T** で、設定から変更・解除できます。

AutoRaiseを使わない方を想定した **標準** の動作が初期設定です。ポップアップを操作した後にホバーでフォーカスが移らなくなる場合は、**設定 → ポップアップ → フォーカス → ウィンドウの動作 → AutoRaise互換** を選んでください。設定は保存され、位置・サイズ・文章を維持したまま即座に切り替わります。AutoRaiseの設定によって動作が異なるため、すべてのウィンドウ管理アプリへの対応を保証するものではありません。KotoFloatはマウスポインターを移動しません。

設定画面は **一般・ポップアップ・文章取得** の3つのタブに分かれ、スクロールせず操作できます。**一般 → アプリの言語** から **システムに従う**（初期設定）、**English**、**日本語** を選べます。選択は保存され、KotoFloatの画面とメニューにすぐ反映されます。システムの優先言語に対応言語がない場合は英語になります。システムのダイアログと一部の標準部品はmacOSの言語に従います。**文章取得** の **再確認** を押すと、状態が変わらない場合も、確認時刻と権限の有効・無効を表示します。

現在は **文章を取得するローカル開発用プレビュー** です。LLM翻訳、用語集、翻訳エディタは後続の段階で実装します。公証済みの配布版はまだありません。実際の確認結果と制限は、[第1段階の検証記録](docs/testing/phase-1.md)と[第2段階の検証記録](docs/testing/phase-2.md)を参照してください。

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

Dockではなくメニューバーに表示されます。初回は設定画面が開きます。**システム設定 → Privacy & Security → Device Control and Data Access**（以前のmacOSでは **アクセシビリティ**）でKotoFloatを有効にし、別アプリで文章を選択して **⌃⌥⌘T** を押してください。原文と取得元アプリが表示されます。翻訳にはまだ接続していません。直接取得できない場合はコピーを試し、結果の確認を求めます。**文章を入力・貼り付け…** は権限なしでも使えます。画面確認用の **サンプルを表示** も残しています。タイトルバーで移動し、端のドラッグでサイズを変更できます。**長文を試す** では自動リサイズせずスクロールする動作を確認できます。閉じるボタン、またはポップアップにフォーカスした状態のEscで閉じます。アプリの終了はメニューバーから行います。

ネイティブウィンドウのテストにはログイン済みのmacOS画面が必要で、テスト中は一時的にウィンドウが表示されます。設定保存先はテスト専用です。配置計算と保存のテストだけなら `swift test --filter 'PopupGeometryTests|PopupPreferencesTests'` でも実行できます。Xcodeでパッケージのテストを実行するときは `Package.swift` を開いてください。アプリのスキームはビルド・起動用です。

### フォルダ構成

- `App/`：macOSアプリの起動処理。
- `Sources/KotoFloatKit/`：AppKitのポップアップ制御、選択文章取得、クリップボード処理、SwiftUI画面、設定、言語リソース。
- `Tests/KotoFloatKitTests/`：取得要求の管理、クリップボード保護、配置、保存、実際のウィンドウ動作のテスト。
- `KotoFloat.xcodeproj/`：ローカルのSwiftパッケージを利用するアプリ。
- `docs/superpowers/plans/`：[6段階の開発計画](docs/superpowers/plans/2026-10-29-initial-release-phases.md)と各段階の詳細計画。

### 初期版で目指すこと

- 他のアプリで選択した文章を、ショートカットで翻訳してポップアップ表示する。
- 用語集を初期版から搭載し、指定した訳語や文脈を翻訳に反映する。
- 自分で運用するローカルLLMサーバーへ接続し、モデルを固定しない。最初の接続対象はLM StudioのOpenAI互換API。
- 翻訳結果をコピーし、共通のメイン画面で編集できるようにする。

初期版には6段階すべてを含めます。最終的なモデル選定とクリックによる別訳候補の選択はその後です。翻訳・用語集の処理を画面から分離し、ポップアップとメイン画面で共有します。

### データの取り扱い方針

- 第2段階は取得文をこのMacのメモリ内に保持し、翻訳リクエストを行いません。原文をログやファイルへ保存しません。
- コピー経由の取得では、観測した世代が変わらない場合だけ読み取れた形式を復元します。新しい更新・アプリ切り替え・入力で処理を中断します。プロセス間の復元の制限は検証記録を参照してください。
- 空選択と保護されたパスワード欄はコピーしません。コピー結果は利用者が確認してから後続の翻訳機能へ渡します。
- 将来の翻訳対象は、利用者が指定した接続先だけへ送信します。
- 接続資格情報、個人の用語集、翻訳履歴、モデルファイルをGitへ登録しません。
- 将来の資格情報はmacOSキーチェーンへ保存します。
- 実装済み・計画中・未検証を明確に区別します。

### ライセンス

未選定です。現時点ではオープンソースライセンスを付与していません。依存ライブラリのKeyboardShortcutsは独立したMITライセンスで配布されています。
