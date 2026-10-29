# KotoFloat

[English](#english) | [日本語](#日本語)

## English

Translate selected text without leaving your current task. KotoFloat is a macOS translation app project built around glossaries and local LLMs.

### Development status

Phases 1–3 are implemented: a menu bar app with a movable, resizable popup, selected-text capture, and OpenAI-compatible streaming translation. The popup preserves source-app focus when shown, stays open across focus changes, and closes with Escape only while it has keyboard focus. It remembers position and size, offers near-pointer placement, and lets you toggle always-on-top independently. The shortcut defaults to **Control–Option–Command–T** and can be changed or cleared in Settings. Phase 3 has been checked against fixed API fixtures; a real LLM server is not yet verified.

**Standard** focus behavior is the default for people who do not use AutoRaise. If hovering stops moving focus after using the popup, select **Settings → Popup → Focus → Window behavior → AutoRaise compatibility**. The setting is saved and takes effect immediately without losing the popup size, position, or text. Compatibility depends on AutoRaise settings; it is not a promise for every window manager. KotoFloat never moves the mouse pointer.

Settings uses five tabs—**General**, **Popup**, **Text capture**, **Connection**, and **Translation**—without a scrolling container. Under **General → App language**, choose **Follow system** (the default), **English**, or **日本語**. The choice is saved and updates KotoFloat's screens and menus immediately; unsupported system languages fall back to English. System dialogs and some native controls still follow macOS. Under **Text capture**, **Check again** displays the check time and whether permission is enabled, even when the status has not changed.

This is a **local development preview**. Glossaries and the translation editor are planned in Phases 4 and 5. There is no notarized downloadable release yet. See [Phase 1 verification](docs/testing/phase-1.md), [Phase 2 verification](docs/testing/phase-2.md), and [Phase 3 verification](docs/testing/phase-3.md) for actual checks and limitations.

### Build and run

Requirements: macOS 15 or later, Xcode with the macOS SDK and a Swift 6 toolchain. Internet access is needed for the initial KeyboardShortcuts package download.

**Xcode:** open `KotoFloat.xcodeproj`, select the **KotoFloat** scheme and **My Mac**, then Run. No Apple developer account is needed for this locally signed preview.

**VS Code:** open the repository folder and install the recommended Swift extension. `Package.swift` enables code navigation, diagnostics, and Swift package tests. Run **Tasks: Run Task → Run macOS app / macOSアプリを起動**, or press F5 to use the included LLDB launch configuration. Xcode must still be installed. The native app and package share the same implementation.

For daily development, use **Test in background** or **Validate build in background** in VS Code's Tasks menu. These are the default test/build tasks. They run at lower process priority with two build jobs, do not launch the app, and do not focus the terminal. Build validation writes to `.build/validation`, leaving the app in `.build/xcode` untouched. Background tests exclude the native window suite and use isolated settings and clipboard storage. Choose **Test all (opens windows)** separately for desktop checks; full verification of focus and AutoRaise still needs a graphical session.

From a terminal in the repository:

```sh
nice -n 10 swift test --jobs 2 --skip PopupControllerTests
xcodebuild -project KotoFloat.xcodeproj -scheme KotoFloat -configuration Debug -derivedDataPath .build/xcode build
open .build/xcode/Build/Products/Debug/KotoFloat.app
```

The app appears in the menu bar rather than the Dock. Settings opens on first launch. Enable KotoFloat in **System Settings → Privacy & Security → Device Control and Data Access** (called **Accessibility** on earlier macOS versions), select text in another app, and press **⌃⌥⌘T**. The original text and source app appear. Configure and save a server in **Settings → Connection** to translate; otherwise the popup explains the missing setup. If direct access is unavailable, the app tries Copy and asks you to confirm the resulting text before sending it. **Enter or paste text…** works without Accessibility permission. **Show sample popup** remains available for layout testing and sends no requests. Drag the title bar to move it and its edges to resize it. Close the popup with its close button or focus it and press Escape; quit the app from the menu bar.

### Translation setup and offline development

In **Connection**, enter a base URL (for example, `http://127.0.0.1:1234/v1` for a server on this Mac), a model ID, and an optional API token. **Check connection** fetches the model list; it does not prove a model can generate. **Try translation** sends a disclosed fixed sentence using the current fields. **Save** applies the fields to selected-text translation and stores tokens in Keychain, scoped to that endpoint. Leaving the token blank preserves that endpoint's token; the remove option deletes it. A different endpoint does not inherit the old token.

Translation defaults to automatic source detection and Japanese output. Choose English/Japanese in **Translation** or the popup. Changes apply to the next request; use **Retranslate** for existing text. **Stop** or closing the popup cancels the current request. Interrupted results remain labeled incomplete; the copy button is enabled only for complete output. No automatic retry or cloud fallback occurs.

Without an LLM, run the background suite against a loopback-only fixed API server:

```sh
python3 scripts/test_with_mock_server.py
```

To use that fixture manually, run `python3 scripts/mock_llm_server.py`, set the base URL to `http://127.0.0.1:8765/v1`, and choose model `kotofloat-fixture`. It always returns text explicitly identified as a test response, never a real translation. The normal app has no automatic mock mode. Real model quality, remote HTTPS/VPN access, Keychain access in the signed app, and the new live UI still need acceptance checks.

The commands above intentionally build and launch the app. Native window tests require a logged-in graphical macOS session and briefly show test windows; run them explicitly with `swift test --jobs 2` when desktop interaction is convenient. They use separate settings domains. Pure geometry and persistence tests can also run separately with `swift test --filter 'PopupGeometryTests|PopupPreferencesTests'`. In Xcode, open `Package.swift` to run the package's tests; the app scheme is for building and running the app.

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

- Captured and translated text stays in memory; source text, output, and tokens are not logged or saved as history. Translation sends confirmed text only to the server configured by the user.
- Copy fallback restores readable clipboard formats only if its observed generation is unchanged; newer updates, app switches, and input interrupt capture. See the verification record for the limits of cross-process clipboard restoration.
- Known empty selections and protected password fields are not copied. Copied text must be confirmed before later translation features can use it.
- HTTPS certificates use system validation, and redirects are rejected. HTTP is allowed on loopback; other HTTP requires explicit opt-in. The app's transport setting permits custom HTTP endpoints, while application validation enforces this choice. Prefer HTTPS or a trusted VPN for remote access.
- Keep credentials, personal glossaries, translation history, and model files out of Git.
- Credentials are stored in the macOS Keychain; only non-secret connection settings and language choices go into preferences.
- Clearly distinguish implemented features from planned and unverified features.

### License

No license has been selected. This project does not currently grant an open-source license. KeyboardShortcuts is a separate dependency distributed under its own MIT license.

---

## 日本語

選択した文章を、その場で翻訳する。用語集とローカルLLMを活用するmacOS向け翻訳アプリの開発プロジェクトです。

### 開発状況

第1〜第3段階を実装しました。移動・サイズ変更できるポップアップ、選択文章の取得、OpenAI互換のストリーミング翻訳、メニューバー常駐に対応しています。ポップアップは表示時に元アプリのフォーカスを奪わず、フォーカスが移っても表示を維持し、キーボードフォーカスがあるときだけEscで閉じます。位置・サイズの保存、カーソル付近への配置、独立した最前面固定の切り替えに対応しています。ショートカットの初期設定は **Control–Option–Command–T** で、設定から変更・解除できます。第3段階は固定API応答で検証しており、実LLMサーバーは未確認です。

AutoRaiseを使わない方を想定した **標準** の動作が初期設定です。ポップアップを操作した後にホバーでフォーカスが移らなくなる場合は、**設定 → ポップアップ → フォーカス → ウィンドウの動作 → AutoRaise互換** を選んでください。設定は保存され、位置・サイズ・文章を維持したまま即座に切り替わります。AutoRaiseの設定によって動作が異なるため、すべてのウィンドウ管理アプリへの対応を保証するものではありません。KotoFloatはマウスポインターを移動しません。

設定画面は **一般・ポップアップ・文章取得・接続・翻訳** の5つのタブに分かれ、スクロールする領域を設けていません。**一般 → アプリの言語** から **システムに従う**（初期設定）、**English**、**日本語** を選べます。選択は保存され、KotoFloatの画面とメニューにすぐ反映されます。システムの優先言語に対応言語がない場合は英語になります。システムのダイアログと一部の標準部品はmacOSの言語に従います。**文章取得** の **再確認** を押すと、状態が変わらない場合も、確認時刻と権限の有効・無効を表示します。

現在は **ローカル開発用プレビュー** です。用語集と翻訳エディタは第4・第5段階で実装します。公証済みの配布版はまだありません。実際の確認結果と制限は、[第1段階](docs/testing/phase-1.md)・[第2段階](docs/testing/phase-2.md)・[第3段階の検証記録](docs/testing/phase-3.md)を参照してください。

### ビルドと起動

必要環境：macOS 15以降、macOS SDKとSwift 6のツールチェーンを含むXcode。初回はKeyboardShortcutsの取得にインターネット接続が必要です。

**Xcode：** `KotoFloat.xcodeproj` を開き、**KotoFloat** スキームと **My Mac** を選んで実行します。ローカル署名のプレビューにはApple開発者アカウントは不要です。

**VS Code：** リポジトリフォルダを開き、推奨されるSwift拡張機能をインストールしてください。`Package.swift` により定義への移動、エラー表示、Swiftパッケージのテストが利用できます。**Tasks: Run Task → Run macOS app / macOSアプリを起動** を実行するか、F5で付属のLLDB設定からデバッグできます。Xcodeのインストールも必要です。アプリとパッケージは同じ実装を共有します。

日常の開発では、VS CodeのTasksメニューにある **バックグラウンドでテスト** または **バックグラウンドでビルド確認** を使ってください。これらが既定のテスト・ビルドタスクです。処理の優先度を下げ、ビルドの並列処理を2つに制限し、アプリを起動せず、ターミナルへフォーカスを移しません。ビルド確認の保存先は `.build/validation` とし、`.build/xcode` のアプリは変更しません。バックグラウンドのテストはウィンドウを表示するテストを除外し、設定とクリップボードは独立した領域を使用します。画面の確認には別途 **全テスト（ウィンドウを表示）** を選んでください。フォーカスやAutoRaiseの完全な検証には実際の画面が必要です。

リポジトリ内のターミナルからは次の操作で確認できます。

```sh
nice -n 10 swift test --jobs 2 --skip PopupControllerTests
xcodebuild -project KotoFloat.xcodeproj -scheme KotoFloat -configuration Debug -derivedDataPath .build/xcode build
open .build/xcode/Build/Products/Debug/KotoFloat.app
```

Dockではなくメニューバーに表示されます。初回は設定画面が開きます。**システム設定 → Privacy & Security → Device Control and Data Access**（以前のmacOSでは **アクセシビリティ**）でKotoFloatを有効にし、別アプリで文章を選択して **⌃⌥⌘T** を押してください。原文と取得元アプリが表示されます。翻訳するには **設定 → 接続** でサーバーを設定・保存してください。未設定の場合はポップアップで案内します。直接取得できない場合はコピーを試し、利用者が結果を確認してから送信します。**文章を入力・貼り付け…** は権限なしでも使えます。画面確認用の **サンプルを表示** は通信しません。タイトルバーで移動し、端のドラッグでサイズを変更できます。閉じるボタン、またはポップアップにフォーカスした状態のEscで閉じます。アプリの終了はメニューバーから行います。

### 翻訳の設定とLLMなしでの開発

**接続** でベースURL（このMacで動かすサーバーなら例：`http://127.0.0.1:1234/v1`）、モデルID、任意のAPIトークンを入力します。**接続確認** はモデル一覧の取得までで、生成できることの確認ではありません。**試し翻訳** は入力中の値を使い、明示した固定文を送ります。**保存** で選択文章の翻訳に適用し、トークンは接続先ごとにキーチェーンへ保存します。トークンが空欄ならその接続先の保存済み値を維持し、削除の選択肢で消去できます。別の接続先へ以前のトークンを引き継ぎません。

翻訳元は自動判定、翻訳先は日本語が初期設定です。**翻訳** またはポップアップで英語・日本語を選べます。変更は次の要求から反映し、現在の文章には **再翻訳** を使います。**停止** またはポップアップを閉じると要求をキャンセルします。中断した文章は未完了と表示し、コピーボタンは完了した訳文だけに使用できます。自動再試行やクラウドへの代替接続はありません。

LLMがない場合は、ループバック専用の固定応答サーバーでバックグラウンド検証できます。

```sh
python3 scripts/test_with_mock_server.py
```

手動で試す場合は `python3 scripts/mock_llm_server.py` を起動し、ベースURLを `http://127.0.0.1:8765/v1`、モデルを `kotofloat-fixture` にします。常にテスト用と明示した固定文を返し、本物の翻訳は行いません。通常のアプリに、自動で固定応答へ切り替わる機能はありません。実モデルの品質、遠隔HTTPS／VPN接続、署名済みアプリからのキーチェーン利用、新しい実画面の確認は今後必要です。

上記のコマンドは、意図的にアプリをビルドして起動する手順です。ネイティブウィンドウのテストにはログイン済みのmacOS画面が必要で、テスト中は一時的にウィンドウが表示されます。画面を操作してよいタイミングで、明示的に `swift test --jobs 2` を実行してください。設定保存先はテスト専用です。配置計算と保存のテストだけなら `swift test --filter 'PopupGeometryTests|PopupPreferencesTests'` でも実行できます。Xcodeでパッケージのテストを実行するときは `Package.swift` を開いてください。アプリのスキームはビルド・起動用です。

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

- 取得文・訳文はメモリ内で保持し、原文・訳文・トークンをログや履歴へ保存しません。翻訳時は、確定した文章だけを利用者が設定したサーバーへ送信します。
- コピー経由の取得では、観測した世代が変わらない場合だけ読み取れた形式を復元します。新しい更新・アプリ切り替え・入力で処理を中断します。プロセス間の復元の制限は検証記録を参照してください。
- 空選択と保護されたパスワード欄はコピーしません。コピー結果は利用者が確認してから後続の翻訳機能へ渡します。
- HTTPS証明書はシステムで検証し、リダイレクトは拒否します。HTTPはループバックで許可し、それ以外では明示的な有効化が必要です。アプリの通信設定では任意のHTTP接続先を扱えるようにし、アプリ内の検証でこの選択を適用します。遠隔接続にはHTTPSまたは信頼するVPNを推奨します。
- 接続資格情報、個人の用語集、翻訳履歴、モデルファイルをGitへ登録しません。
- 認証情報はmacOSキーチェーンに保存します。通常の設定には認証情報を含まない接続設定と言語の選択だけを保存します。
- 実装済み・計画中・未検証を明確に区別します。

### ライセンス

未選定です。現時点ではオープンソースライセンスを付与していません。依存ライブラリのKeyboardShortcutsは独立したMITライセンスで配布されています。
