# Repository Writing Conventions

## English

- Write human-readable prose in repository files in English first, followed by Japanese, by default. This includes documentation and explanatory code comments.
- For Markdown documents, place the complete English section before the complete Japanese section. Keep both versions aligned when editing.
- Keep executable code, identifiers, commands, API fields, and configuration values in their conventional syntax; do not duplicate them solely for translation.
- Write commit messages in English.
- Do not include `codex` in branch names. Use descriptive names such as `feature/phase-1-popup`.

### Background development

- Keep the user's Mac usable during development. Prefer file edits, builds, and tests that do not interact with the desktop. Do not routinely launch or restart KotoFloat, open other apps, switch focus, or synthesize input during verification.
- For routine tests, use `nice -n 10 swift test --jobs 2 --skip PopupControllerTests`. These tests use isolated preferences and named pasteboards. Keep any future desktop-interacting tests out of the background task too.
- For build verification, use `nice -n 10 xcodebuild -project KotoFloat.xcodeproj -scheme KotoFloat -configuration Debug -derivedDataPath .build/validation -jobs 2 build`. Keep verification products separate from the user's running `.build/xcode` app. Limit concurrent builds/tests to reduce load.
- Native window tests and live app checks are separate, explicit steps. Announce any necessary desktop interaction beforehand and coordinate it around the user's work. Do not claim focus, AutoRaise, or visual behavior is verified solely by background tests; report what remains unverified.

## 日本語

- リポジトリ内のファイルに含む説明文は、原則として英語を先に、日本語を後に書く。ドキュメントや説明用のコードコメントも対象とする。
- Markdown文書は英語の全文の後に日本語の全文を配置する。編集時は両言語の内容を揃える。
- 実行コード、識別子、コマンド、APIフィールド、設定値は通常の構文を維持し、翻訳のためだけに複製しない。
- コミットメッセージは英語にする。
- ブランチ名に `codex` を含めない。`feature/phase-1-popup` のような内容が分かる名前を使う。

### バックグラウンドでの開発

- 開発中も利用者がMacを使えるよう、ファイル編集・ビルド・画面を操作しないテストを優先する。通常の検証でKotoFloatの起動・再起動、別アプリの起動、フォーカス変更、入力の送出を行わない。
- 通常のテストは `nice -n 10 swift test --jobs 2 --skip PopupControllerTests` を使う。これらは独立した設定保存先と名前付きクリップボードを使用する。今後追加する画面操作付きのテストもバックグラウンド用タスクから除外する。
- ビルド確認は `nice -n 10 xcodebuild -project KotoFloat.xcodeproj -scheme KotoFloat -configuration Debug -derivedDataPath .build/validation -jobs 2 build` を使う。検証用の生成物を、利用者が起動している `.build/xcode` のアプリから分離する。負荷を抑えるためビルド・テストの同時実行を控える。
- ネイティブウィンドウのテストと実アプリの確認は、独立した明示的な手順とする。必要な画面操作は事前に伝え、利用者の作業に合わせて実施する。バックグラウンドのテストだけでフォーカス・AutoRaise・見た目を確認済みとせず、未確認の範囲を報告する。
