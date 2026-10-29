# KotoFloat

[English](#english) | [日本語](#日本語)

## English

Translate selected text without leaving your current task. KotoFloat is a macOS translation app project built around glossaries and local LLMs.

### Development status

The project is in its initial planning stage. There is no working app or downloadable release yet.

### Goals for the first version

- Translate text selected in another app with a keyboard shortcut and display the result in a floating popup.
- Include glossaries from the first version, using preferred translations and contextual notes to guide translation.
- Connect to a self-hosted local LLM server without tying the app to a specific model.
- Let users copy the translation and return to their original task.

### Proposed architecture

- macOS client: Swift / SwiftUI / AppKit.
- Inference server: an OpenAI-compatible API provided by LM Studio or Ollama, potentially running on a separate PC.
- Glossaries: local storage, with entry management, search, and CSV import/export under consideration.
- Translation window: text input and manual editing of translations under consideration.

These are proposals. The server, model, minimum supported macOS version, and detailed interactions are still to be decided.

### Future direction

Develop a translation editor that lets users select words or phrases in a translation, choose alternatives, and refine the result in context. Translation and glossary logic should be separate from the UI so that the popup and main window can share it.

### Data handling principles

- Send translation input only to the endpoint configured by the user.
- Keep credentials, personal glossaries, translation history, and model files out of Git.
- Plan to store credentials in the macOS Keychain.
- Clearly distinguish implemented features from planned features.

### License

No license has been selected. This project does not currently grant an open-source license.

---

## 日本語

選択した文章を、その場で翻訳する。用語集とローカルLLMを活用するmacOS向け翻訳アプリの開発プロジェクトです。

### 開発状況

初期準備段階です。現在は仕様の整理のみで、動作するアプリや配布版はまだありません。

### 初期版で目指すこと

- 他のアプリで選択した文章を、ショートカットで翻訳してポップアップ表示する。
- 用語集を初期版から搭載し、指定した訳語や文脈を翻訳に反映する。
- 自分で運用するローカルLLMサーバーへ接続する。モデルをアプリに固定しない。
- 翻訳結果をコピーし、元の作業へ戻れるようにする。

### 検討中の構成

- macOSクライアント：Swift / SwiftUI / AppKit。
- 推論サーバー：LM StudioまたはOllamaのOpenAI互換API。別PC上での実行を想定する。
- 用語集：ローカル管理。登録・編集・検索とCSV入出力を検討する。
- 基本の翻訳画面：原文の貼り付けと訳文の手動編集を検討する。

これらは設計案であり、サーバー、モデル、対応OSの下限、詳細な操作仕様は今後確定します。

### 将来の方向性

訳文の単語やフレーズから別の翻訳候補を選び、文脈に合わせて調整できる翻訳エディタを目指します。翻訳・用語集の処理を画面から分離し、ポップアップとメイン画面で共有できる構成を検討します。

### データの取り扱い方針

- 翻訳対象は、ユーザーが指定した接続先へ送信する。
- 接続資格情報、個人の用語集、翻訳履歴、モデルファイルをGitへ登録しない。
- 資格情報はmacOSキーチェーンでの保存を予定する。
- 実装済みの機能と計画中の機能を区別して記載する。

### ライセンス

未選定です。現時点ではオープンソースライセンスを付与していません。
