# KotoFloat

[English](#english) | [日本語](#日本語)

## English

Translate selected text without leaving your current task. KotoFloat is a macOS translation app project built around glossaries and local LLMs.

### Development status

Phase 6 adds **searchable language selection and favorites**. **Phase 7** covers end-to-end acceptance and distribution preparation; outstanding physical-user checks from earlier phases remain open. See the [revised roadmap](docs/superpowers/plans/2026-10-29-initial-release-phases.md).

Phases 1–6 are implemented: a menu bar app with a movable, resizable popup, selected-text capture, OpenAI-compatible streaming translation, local glossaries with CSV import/export, a shared translation editor, and searchable language selection with favorites. The popup preserves source-app focus when shown, stays open across focus changes, and closes with Escape only while it has keyboard focus. It remembers position and size, offers near-pointer placement, and lets you toggle always-on-top independently. The shortcut defaults to **Control–Option–Command–T** and can be changed or cleared in Settings. Fixed API fixtures and real local LM Studio English/Japanese smoke translations have been verified; remote HTTPS/VPN acceptance remains pending.

**Standard** focus behavior is the default for people who do not use AutoRaise. If hovering stops moving focus after using the popup, select **Settings → Popup → Focus → Window behavior → AutoRaise compatibility**. The setting is saved and takes effect immediately without losing the popup size, position, or text. Compatibility depends on AutoRaise settings; it is not a promise for every window manager. KotoFloat never moves the mouse pointer.

Settings uses five tabs—**General**, **Popup**, **Text capture**, **Connection**, and **Translation**—with scrolling in Translation settings for favorite-language management. Under **General → App language**, choose **Follow system** (the default), **English**, or **日本語**. The choice is saved and updates KotoFloat's screens and menus immediately; unsupported system languages fall back to English. System dialogs and some native controls still follow macOS. Under **Text capture**, **Check again** displays the check time and whether permission is enabled, even when the status has not changed.

This is a **local development preview**. Glossaries and the translation editor are implemented. Desktop editing, shared-window navigation, local-model translation, and Keychain persistence have been checked; actual IME/VoiceOver/AutoRaise and part of the visual acceptance matrix remain pending. There is no notarized downloadable release yet. See [Phase 1 verification](docs/testing/phase-1.md), [Phase 2 verification](docs/testing/phase-2.md), [Phase 3 verification](docs/testing/phase-3.md), [Phase 4 verification](docs/testing/phase-4.md), [Phase 5 verification](docs/testing/phase-5.md), and [Phase 6 verification](docs/testing/phase-6.md) for actual checks and limitations.

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

In **Connection**, enter a base URL (for example, `http://127.0.0.1:1234/v1` for a server on this Mac), a model ID, and an optional API token. **Check connection** fetches the model list; it does not prove a model can generate. **Try translation** sends a disclosed fixed sentence using the current fields. **Save** applies the fields to selected-text translation and stores tokens in Keychain, scoped to that endpoint. Leaving the token blank preserves that endpoint's token; the remove option deletes it. Changing to a different endpoint clears unsaved token edits, the removal option, and HTTP approval; the old saved token is not transferred.

Translation defaults to automatic source detection and Japanese output. Click a language name in the popup or editor to search the 26 selectable languages, including Simplified/Traditional Chinese and Brazilian/European Portuguese. Search accepts English, Japanese, native names, and language codes. Use arrows and Return to select; Escape dismisses the picker. **Settings → Translation** stores up to five favorite target languages in order; add, remove, and reorder them there. Use the favorite buttons or **Command-1–5** in the focused popup/editor to switch. These shortcuts do not operate in other apps, settings, or the picker. The list describes app choices, not verified quality for every language/model. Changes apply to the next request; use **Retranslate** for existing text. **Stop** cancels the current request. Closing the popup cancels it when the editor is not visible; closing the editor cancels it when the popup is not visible. Both retain the draft. Interrupted results remain labeled incomplete; the copy button is enabled only for nonempty, complete output (including manual edits). No automatic retry or cloud fallback occurs.

Without an LLM, run the background suite against a loopback-only fixed API server:

```sh
python3 scripts/test_with_mock_server.py
```

To use that fixture manually, run `python3 scripts/mock_llm_server.py`, set the base URL to `http://127.0.0.1:8765/v1`, and choose model `kotofloat-fixture`. It always returns text explicitly identified as a test response, never a real translation. The normal app has no automatic mock mode. Real model quality, remote HTTPS/VPN access, Keychain access in the signed app, and the new live UI still need acceptance checks.

The commands above intentionally build and launch the app. Native window tests require a logged-in graphical macOS session and briefly show test windows; run them explicitly with `swift test --jobs 2` when desktop interaction is convenient. They use separate settings domains. Pure geometry and persistence tests can also run separately with `swift test --filter 'PopupGeometryTests|PopupPreferencesTests'`. In Xcode, open `Package.swift` to run the package's tests; the app scheme is for building and running the app.

### Main translator and editing

Choose **Open translator…** in the menu bar or popup. The resizable window shares the current source, request, translation, and edits with the popup; opening it never translates again. Enter or paste text on the left, select source/target languages (or automatic source), and click **Translate**. Input, language, and glossary changes do not send requests automatically. Source input is limited to 128 KiB of UTF-8 per request; character counts are shown separately.

Edit completed output on the right. **Original generated translation** reveals the unchanged model output after edits, while **Copy translation** copies your current edited wording. **Undo/Redo** and Command–Z / Shift–Command–Z operate within the current document. A new translation or confirmed clear/swap resets undo so old text cannot reappear in a new document. Editing the source stops active generation; existing output remains labeled with its original source/direction. Incomplete output stays read-only.

Retranslating edited output, replacing an edited or untranslated draft with a new capture, **Clear**, and **Swap languages and text** show an in-app confirmation. **Keep editing** retains the current document. Further edits invalidate that confirmation. Swap requires an explicit source language and a completed result matching the current source/direction; it moves your edited translation to the source and waits for **Translate**. Automatic source asks the model to infer the language; it does not provide detected-language metadata for swapping.

Closing a window preserves the shared draft in memory. Quitting warns about untranslated/failed source drafts, popup manual-entry drafts, or manual translation edits; copy important text before quitting. No translation history is saved. The popup offers source expansion, the active glossary, the request's glossary snapshot, and explicit retranslation reminders. The workflow takes basic text controls as a reference from [DeepL](https://support.deepl.com/hc/en-us/articles/9851524013468-Get-started-DeepL-for-Microsoft-Word); it uses only your configured LLM server. Alternative-word suggestions, file translation, speech, tone controls, and saved history are outside Phase 5.

### Glossaries

Open **Glossaries…** from the menu bar or translation popup. Create a glossary, add or edit entries, and choose it under **Glossary for translation**. Choose **None** to disable glossary references. The manager supports search, renaming, and confirmed deletion; the existing five Settings tabs stay the same.

Each entry has a source term, preferred translation, source/target language codes, context notes, case sensitivity, and an enabled flag. Latin terms use word boundaries; Japanese terms can match within a sentence. With automatic source language, matching uses the text and target direction. Only matching enabled entries are sent. Conflicting preferred translations are shown and excluded from the reference data. After completion, preferred terms missing from the output are flagged for review; wording is never forcibly replaced, and real models may ignore preferences.

Selections and edits affect the next request. The current result retains the glossary snapshot used for that request; use **Retranslate** to apply changes. **Try translation** in Connection continues to use only its fixed sample, without a glossary.

**Import CSV…** previews every record and offers **Skip duplicates**, **Replace duplicates**, or **Keep both**. Replacement uses the last imported row for a matching source/direction/case key; exact duplicates are not added by Keep both. Any invalid record blocks the entire import. **Export CSV…** exports the selected glossary, including disabled entries, and an empty glossary exports a header template. The UTF-8 format (optional BOM) uses this header; quoted fields support commas, quotes, and line breaks:

```csv
source,target,source_language,target_language,context,case_sensitive,enabled
voltage,電圧,en,ja,Electrical circuit,false,true
```

Languages must be different nonautomatic codes from the app catalog (`en`, `ja`, `zh-Hans`, `zh-Hant`, `pt-BR`, `pt-PT`, etc.); flags are `true`/`false`. CSV preserves literal text; spreadsheet applications may interpret formula-like values, so use a text import mode when opening untrusted CSV. The version-1 library lives at `~/Library/Application Support/KotoFloat/glossaries.json`. Writes are atomic, and invalid/unknown-version or externally changed data is not overwritten. **Reload saved data** refreshes after restoring a valid file or resolving another instance's changes. Close an edit or import preview before reloading; save failures retain its draft. Copy the JSON file for a complete backup (IDs, all glossaries, and active selection); CSV contains one glossary's entries only.

Limits are 100 glossaries, 10,000 total entries, 16 MiB per library/CSV, and 120/256/1,024/2,048 characters for names/source terms/translations/context. A translation request permits at most 100 matching entries and 64 KiB of reference JSON; exceeding this stops the request and explains how to reduce it. Actual window/file-panel accessibility and real-model adherence remain unverified. See [Phase 4 verification](docs/testing/phase-4.md).

### Project structure

- `App/`: the macOS application entry point.
- `Sources/KotoFloatKit/`: AppKit popup management, selected-text capture, clipboard transactions, SwiftUI views, preferences, and localized resources.
- `Tests/KotoFloatKitTests/`: capture lifecycle, clipboard safety, placement, persistence, and native window behavior tests.
- `KotoFloat.xcodeproj/`: the app wrapper linking the local Swift package.
- `docs/superpowers/plans/`: the [seven-phase roadmap](docs/superpowers/plans/2026-10-29-initial-release-phases.md) and detailed phase plans.

### Goals for the first version

- Translate text selected in another app with a keyboard shortcut and display the result in a floating popup.
- Include glossaries from the first version, using preferred translations and contextual notes to guide translation.
- Connect to a self-hosted local LLM server without tying the app to a specific model. LM Studio's OpenAI-compatible API is the first integration target.
- Let users copy translations and edit them in a shared main window.

The first release includes all seven phases. Final model selection and click-based alternative translations come afterward. Translation and glossary logic will remain separate from the UI so that the popup and main window can share it.

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

第6段階で **検索付き言語選択とお気に入り** を追加しました。**第7段階：通し検証と配布準備** では、前段階から残る実利用者による受け入れ確認も扱います。[改訂した開発計画](docs/superpowers/plans/2026-10-29-initial-release-phases.md)を参照してください。

第1〜第6段階を実装しました。移動・サイズ変更できるポップアップ、選択文章の取得、OpenAI互換のストリーミング翻訳、CSV入出力付きのローカル用語集、共有翻訳エディタ、お気に入り付きの検索可能な言語選択、メニューバー常駐に対応しています。ポップアップは表示時に元アプリのフォーカスを奪わず、フォーカスが移っても表示を維持し、キーボードフォーカスがあるときだけEscで閉じます。位置・サイズの保存、カーソル付近への配置、独立した最前面固定の切り替えに対応しています。ショートカットの初期設定は **Control–Option–Command–T** で、設定から変更・解除できます。固定API応答とローカルの実LM Studioによる英日翻訳の疎通を確認済みで、遠隔HTTPS／VPNは未確認です。

AutoRaiseを使わない方を想定した **標準** の動作が初期設定です。ポップアップを操作した後にホバーでフォーカスが移らなくなる場合は、**設定 → ポップアップ → フォーカス → ウィンドウの動作 → AutoRaise互換** を選んでください。設定は保存され、位置・サイズ・文章を維持したまま即座に切り替わります。AutoRaiseの設定によって動作が異なるため、すべてのウィンドウ管理アプリへの対応を保証するものではありません。KotoFloatはマウスポインターを移動しません。

設定画面は **一般・ポップアップ・文章取得・接続・翻訳** の5つのタブに分かれ、翻訳タブはお気に入り設定のためにスクロールできます。**一般 → アプリの言語** から **システムに従う**（初期設定）、**English**、**日本語** を選べます。選択は保存され、KotoFloatの画面とメニューにすぐ反映されます。システムの優先言語に対応言語がない場合は英語になります。システムのダイアログと一部の標準部品はmacOSの言語に従います。**文章取得** の **再確認** を押すと、状態が変わらない場合も、確認時刻と権限の有効・無効を表示します。

現在は **ローカル開発用プレビュー** です。用語集と翻訳エディタは実装済みです。実画面の編集、共有画面間の移動、ローカル実モデル、Keychainの永続化を確認しました。実IME／VoiceOver／AutoRaiseと一部の視覚的な受け入れ条件は未確認です。公証済みの配布版はまだありません。実際の確認結果と制限は、[第1段階](docs/testing/phase-1.md)・[第2段階](docs/testing/phase-2.md)・[第3段階](docs/testing/phase-3.md)・[第4段階](docs/testing/phase-4.md)・[第5段階](docs/testing/phase-5.md)・[第6段階の検証記録](docs/testing/phase-6.md)を参照してください。

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

**接続** でベースURL（このMacで動かすサーバーなら例：`http://127.0.0.1:1234/v1`）、モデルID、任意のAPIトークンを入力します。**接続確認** はモデル一覧の取得までで、生成できることの確認ではありません。**試し翻訳** は入力中の値を使い、明示した固定文を送ります。**保存** で選択文章の翻訳に適用し、トークンは接続先ごとにキーチェーンへ保存します。トークンが空欄ならその接続先の保存済み値を維持し、削除の選択肢で消去できます。別の接続先へ変更すると、未保存のトークン・削除指定・HTTP許可をリセットし、以前の保存済みトークンも引き継ぎません。

翻訳元は自動判定、翻訳先は日本語が初期設定です。ポップアップやエディタの言語名を押すと、簡体字／繁体字中国語、ブラジル／ポルトガルのポルトガル語を含む26言語を検索できます。英語名・日本語名・現地名・言語コードで検索し、上下矢印とReturnで選択、Escで選択画面を閉じます。**設定 → 翻訳** でお気に入りの翻訳先を最大5件、追加・削除・並べ替えできます。フォーカス中のポップアップ／エディタでボタンまたは **Command-1〜5** を使って切り替えます。他アプリ・設定・言語選択画面ではこのショートカットは動作しません。一覧はアプリで選択できる言語であり、全モデルで翻訳品質を検証したものではありません。変更は次の要求から反映し、現在の文章には **再翻訳** を使います。**停止** で要求をキャンセルします。ポップアップを閉じた場合はエディタが非表示のとき、エディタを閉じた場合はポップアップが非表示のときにキャンセルし、どちらも下書きは保持します。中断した文章は未完了と表示し、コピーボタンは空でない完成訳（手編集した内容を含む）だけに使用できます。自動再試行やクラウドへの代替接続はありません。

LLMがない場合は、ループバック専用の固定応答サーバーでバックグラウンド検証できます。

```sh
python3 scripts/test_with_mock_server.py
```

手動で試す場合は `python3 scripts/mock_llm_server.py` を起動し、ベースURLを `http://127.0.0.1:8765/v1`、モデルを `kotofloat-fixture` にします。常にテスト用と明示した固定文を返し、本物の翻訳は行いません。通常のアプリに、自動で固定応答へ切り替わる機能はありません。実モデルの品質、遠隔HTTPS／VPN接続、署名済みアプリからのキーチェーン利用、新しい実画面の確認は今後必要です。

上記のコマンドは、意図的にアプリをビルドして起動する手順です。ネイティブウィンドウのテストにはログイン済みのmacOS画面が必要で、テスト中は一時的にウィンドウが表示されます。画面を操作してよいタイミングで、明示的に `swift test --jobs 2` を実行してください。設定保存先はテスト専用です。配置計算と保存のテストだけなら `swift test --filter 'PopupGeometryTests|PopupPreferencesTests'` でも実行できます。Xcodeでパッケージのテストを実行するときは `Package.swift` を開いてください。アプリのスキームはビルド・起動用です。

### メイン翻訳画面と編集

メニューバーまたはポップアップの **翻訳画面を開く…** を選びます。サイズ変更可能な画面が原文・要求・訳文・編集内容をポップアップと共有し、開くだけでは再翻訳しません。左側に入力・貼り付けし、翻訳元／翻訳先言語（翻訳元は自動も可）を選んで **翻訳** を押します。原文・言語・用語集の変更だけでは送信しません。送信原文はUTF-8で128 KiBまでで、文字数は別に表示します。

右側の完成訳を直接編集できます。編集後の **生成された元の訳文** で元の出力を確認でき、**訳文をコピー** は現在の編集内容をコピーします。**取り消す／やり直す** とCommand–Z／Shift–Command–Zは現在の文書内で働きます。新しい翻訳、確認後のクリア／入れ替えでUndo履歴を消し、古い文章が新しい文書へ戻ることを防ぎます。生成中の原文編集は要求を停止し、既存結果には要求時の原文・方向を表示します。未完了の出力は編集できません。

編集訳の再翻訳、編集済み／未翻訳の下書きを新取得文で置換、**クリア**、**言語と文章を入れ替える** ではアプリ内で確認します。**編集を続ける** で保持し、確認待ち中にさらに編集すると確認を無効化します。入れ替えには翻訳元の明示選択と現在の原文・方向に一致する完成訳が必要です。編集訳を原文へ移し、**翻訳** の操作を待ちます。翻訳元の自動はモデルに推定を指示しますが、入れ替えに使う判定言語情報は返しません。

画面を閉じても共有下書きはメモリに残ります。未翻訳／失敗した原文、ポップアップの未確定手入力、編集訳を残してアプリを終了する場合は確認します。重要な文章は終了前にコピーしてください。翻訳履歴は保存しません。ポップアップには原文の展開、有効な用語集、要求時の用語集、再翻訳の案内を表示します。[DeepL](https://support.deepl.com/hc/en-us/articles/9851524013468-Get-started-DeepL-for-Microsoft-Word)の基本的な文章操作を参考にしていますが、接続先は設定したLLMサーバーだけです。単語の代替候補、文書翻訳、音声、文体指定、履歴保存は第5段階の範囲外です。

### 用語集

メニューバーまたは翻訳ポップアップの **用語集…** を開きます。用語集を作成して項目を登録・編集し、**翻訳に使う用語集** で選択してください。**なし** を選ぶと参照を無効にします。管理画面は検索、名前変更、確認付き削除に対応します。設定画面は既存の5タブのままです。

項目には原語、指定訳語、翻訳元／翻訳先の言語コード、文脈の補足、大文字小文字の区別、有効状態を保存します。欧文は単語境界を考慮し、日本語は文中の部分文字列と照合します。翻訳元が自動の場合は原文との一致と翻訳先を使います。一致する有効項目だけを送信し、競合する訳語は表示して参照データから除外します。完成訳に指定訳語が見当たらない場合は要確認と表示します。訳文を強制置換せず、実モデルの用語遵守は保証しません。

選択・編集は次の要求から反映します。現在の結果には要求時の用語集を保持し、変更は **再翻訳** で適用します。接続画面の **試し翻訳** は引き続き固定文だけを使い、用語集を付けません。

**CSVを取り込む…** は全レコードをプレビューし、**重複をスキップ・重複を置換・両方保持** を選べます。原語・言語方向・大文字小文字設定が同じ項目の置換は最後の行を採用し、両方保持でも完全一致は追加しません。不正な行があれば全体を取り込みません。**CSVを書き出す…** は無効な項目も含めた選択中の用語集を書き出します。空の用語集からはヘッダーテンプレートを書き出せます。UTF-8（BOM可）で、列は英語セクションの例を使います。引用符で囲めばカンマ・引用符・改行を保持できます。

言語はアプリ一覧の自動以外の異なるコード（`en`、`ja`、`zh-Hans`、`zh-Hant`、`pt-BR`、`pt-PT`など）、真偽値は`true`／`false`です。CSVは文字列をそのまま保持するため、表計算アプリで出所不明のCSVを開く際は数式として評価しないテキスト取り込みを使ってください。形式バージョン1の保存先は`~/Library/Application Support/KotoFloat/glossaries.json`です。原子的に保存し、不正・未知バージョン・外部で更新されたデータを上書きしません。有効なファイルを復元した後や別インスタンスの変更を反映する際は **保存済みデータを再読込** を使います。編集や取り込みの確認画面は閉じてから再読込してください。保存失敗時は下書きを維持します。全用語集・ID・有効選択を含むバックアップにはJSONファイルをコピーしてください。CSVは1つの用語集の項目だけを含みます。

上限は用語集100個、全項目10,000件、保存ファイル／CSV 16 MiB、名前120・原語256・訳語1,024・文脈2,048文字です。1要求では一致項目100件・参照JSON 64 KiBまでとし、超過時は送信を止めて削減方法を案内します。実画面・ファイルパネルの操作性とアクセシビリティ、実モデルでの適用は未確認です。[第4段階の検証記録](docs/testing/phase-4.md)を参照してください。

### フォルダ構成

- `App/`：macOSアプリの起動処理。
- `Sources/KotoFloatKit/`：AppKitのポップアップ制御、選択文章取得、クリップボード処理、SwiftUI画面、設定、言語リソース。
- `Tests/KotoFloatKitTests/`：取得要求の管理、クリップボード保護、配置、保存、実際のウィンドウ動作のテスト。
- `KotoFloat.xcodeproj/`：ローカルのSwiftパッケージを利用するアプリ。
- `docs/superpowers/plans/`：[7段階の開発計画](docs/superpowers/plans/2026-10-29-initial-release-phases.md)と各段階の詳細計画。

### 初期版で目指すこと

- 他のアプリで選択した文章を、ショートカットで翻訳してポップアップ表示する。
- 用語集を初期版から搭載し、指定した訳語や文脈を翻訳に反映する。
- 自分で運用するローカルLLMサーバーへ接続し、モデルを固定しない。最初の接続対象はLM StudioのOpenAI互換API。
- 翻訳結果をコピーし、共通のメイン画面で編集できるようにする。

初期版には7段階すべてを含めます。最終的なモデル選定とクリックによる別訳候補の選択はその後です。翻訳・用語集の処理を画面から分離し、ポップアップとメイン画面で共有します。

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
