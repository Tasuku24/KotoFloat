# Phase 3: LLM connection and translation / 第3段階：LLM接続と翻訳

## English

**Goal:** Implement the roadmap's Phase 3 without requiring a running LLM. Keep real-server, VPN, translation quality, and live desktop acceptance explicitly pending.

**Spec:** [Initial release roadmap](2026-10-29-initial-release-phases.md), Phase 3, and the user's background-development preference.

**Architecture:** Keep endpoint validation, Keychain credentials, the OpenAI-compatible client, and translation state separate from capture and SwiftUI. One request owns each result. Only confirmed capture enters translation. Use URLSession with ephemeral sessions, no redirects, bounded responses, and no request-body logging. Test with synthetic fixtures; never substitute fixture output in the production app.

**API reference:** [LM Studio Chat Completions](https://lmstudio.ai/docs/developer/openai-compat/chat-completions). Use GET `/v1/models` for reachability and POST `/v1/chat/completions` with `stream: true` for translation. Keep the model editable. Prompt the model to translate source content rather than act on instructions inside it.

**Constraints:** macOS 15+, Swift 6, English then Japanese documentation, no `codex` in branch names. Reuse `/Users/s26037/Developer/KotoFloat` on `feature/phase-3-translation` after the Phase 2 merge. Run background checks only; do not launch apps or modify the running `.build/xcode` product. No automatic retries or cloud fallback. Default source language is automatic and target is Japanese; both English and Japanese are supported translation directions. HTTPS is supported; loopback HTTP is allowed for local development, and other HTTP requires explicit opt-in. Credentials belong to the normalized endpoint and are never copied to a new endpoint implicitly.

**Review focus:** Tokens across endpoint changes and redirects; partial streams mistaken for complete; delayed chunks after cancellation/new input/close; duplicate shortcuts; unconfirmed copied text reaching the network; settings views exceeding the no-scroll layout; background checks interacting with the user's desktop.

### Task 1: Validated settings and credential storage

**Files:** `TranslationSettings.swift`, `CredentialStore.swift`, `TranslationSettingsTests.swift`.

**Interfaces:** Validated `ServerConfiguration` provides models/chat URLs. `TranslationPreferences` persists non-secret settings. `CredentialStore` reads/writes endpoint-scoped tokens; the Keychain adapter reports failures without prompting during background work.

- [ ] Add failing tests for URL normalization/rejection, HTTP opt-in, persistence, and endpoint-scoped credentials.
- [ ] Implement the contracts and Keychain adapter. Preserve saved settings if credential writes fail.
- [ ] Run `nice -n 10 swift test --jobs 2 --skip PopupControllerTests`. Expected: background suite passes. Commit the slice.

### Task 2: OpenAI-compatible streaming client

**Files:** `TranslationClient.swift`, `SSEDecoder.swift`, `TranslationClientTests.swift`.

**Interfaces:** `TranslationServing` lists model IDs and streams text through an async callback. Requests snapshot configuration, credentials, source, and direction. `TranslationFailure` is a content-free, localizable error.

- [ ] Add failing contract tests for requests, fragmented UTF-8/SSE, valid completion, malformed/truncated responses, authorization/model errors, and redirects.
- [ ] Implement bounded parsing, connection checks, streaming, cancellation, timeouts, and explicit completion. Do not display reasoning/tool calls as translations.
- [ ] Run the background suite. Expected: passing contracts without a remote service. Commit the slice.

### Task 3: Translation lifecycle and capture handoff

**Files:** `TranslationModel.swift`, `CaptureModel.swift`, `TranslationModelTests.swift`, `SelectionCaptureTests.swift`.

**Interfaces:** `TranslationModel` exposes idle/running/completed/cancelled/failed states and partial output. Confirmed capture starts translation; manual entry, failures, and closing invalidate obsolete work. Repeated identical active requests are coalesced. Retranslate is explicit and snapshots the current direction.

- [ ] Add failing tests for progress, errors, cancellation, late responses, repeated input, changed settings, and copy/manual confirmation.
- [ ] Implement request IDs and a headless capture-to-translation handoff. Preserve source content and distinguish incomplete output.
- [ ] Run the background suite. Expected: old requests cannot overwrite current results, and unconfirmed copies never translate. Commit the slice.

### Task 4: Connection settings and popup integration

**Files:** `ConnectionModel.swift`, `ConnectionSettingsView.swift`, `TranslationContentView.swift`, settings/popup/delegate integration, localized resources, `ConnectionModelTests.swift`.

**Interfaces:** The shared preferences feed a saved endpoint/model and Keychain token. Connection check fetches models; trial translation uses a fixed, disclosed sample. The popup offers direction, progress, cancel, retry, and copy, without changing window geometry.

- [ ] Add failing state tests for connection checking, token-write failure, and obsolete connection results.
- [ ] Add non-scrolling settings tabs for connection and translation. Keep UI language separate from translation direction. Update popup controls and cancel on close/sample/manual entry.
- [ ] Run background tests and a separate Debug build. Expected: compilation succeeds; live layout/focus remains unverified. Commit the slice.

### Task 5: Offline fixture, verification, and documentation

**Files:** `scripts/mock_llm_server.py`, integration tests, README, roadmap, `docs/testing/phase-3.md`.

- [ ] Provide a loopback-only fixture server with fixed, clearly identified output and no source/token logging. Verify the real client against it using synthetic text.
- [ ] Run background tests, Debug/universal Release builds in `.build/validation`, signature checks, and localization consistency checks. Expected: all pass without desktop interaction.
- [ ] Record exactly what fixtures establish and what still needs a real LLM or desktop session. Update English then Japanese documentation.
- [ ] Perform one independent whole-branch review, fix material findings with regression tests, and commit. Do not merge.

## 日本語

**目標:** 稼働中のLLMなしで第3段階を実装する。実サーバー・VPN・翻訳品質・実画面の確認は未確認として残す。

**仕様:** [初期版の開発計画](2026-10-29-initial-release-phases.md)の第3段階と、利用者のバックグラウンド開発の希望。

**構成:** 接続先検証、Keychain、OpenAI互換通信、翻訳状態を、文章取得・SwiftUIから分離する。一つの要求が一つの結果を所有し、確定した取得文だけを翻訳する。URLSessionは一時セッションを使い、リダイレクトを追わず、応答量を制限し、要求本文をログへ出さない。テストでは合成資料を使い、本番アプリでテスト用の訳文へ置き換えない。

**API資料:** [LM Studio Chat Completions](https://lmstudio.ai/docs/developer/openai-compat/chat-completions)。接続確認はGET `/v1/models`、翻訳はPOST `/v1/chat/completions` と `stream: true`。モデルは編集可能にする。原文中の指示を実行せず翻訳するよう、モデルへ指示する。

**制約:** macOS 15以降、Swift 6、文書は英語→日本語、ブランチ名に `codex` を含めない。第2段階のマージ後、既存の `/Users/s26037/Developer/KotoFloat` と `feature/phase-3-translation` を使う。検証はバックグラウンドのみで、アプリ起動や稼働中の `.build/xcode` 製品の変更は行わない。自動再試行やクラウドへの代替接続をしない。翻訳元は自動判定、翻訳先は日本語を初期値とし、英語・日本語の方向を選べる。HTTPSに対応し、開発用のループバックHTTPを許可。それ以外のHTTPは明示的な有効化が必要。トークンは正規化した接続先ごとに保存し、別の接続先へ暗黙に引き継がない。

**レビューの重点:** 接続先変更・リダイレクト時のトークン、未完了の応答の完了扱い、停止・新入力・終了後の遅い応答、連続ショートカット、未確認のコピー文の送信、設定画面のスクロール不要条件、検証による画面操作。

### 第1作業：設定検証と認証情報

URLの正規化・拒否、HTTP許可、保存、接続先別トークンを先にテストする。`ServerConfiguration`、`TranslationPreferences`、`CredentialStore`とKeychain実装を追加する。認証情報の保存失敗時は設定を変更しない。バックグラウンドテスト成功後にコミットする。

### 第2作業：OpenAI互換のストリーミング通信

要求内容、分割UTF-8/SSE、完了、不正・中断応答、認証・モデルエラー、リダイレクトの失敗テストを追加する。`TranslationServing`、`TranslationFailure`、応答量制限、タイムアウト、キャンセル、明示的な完了判定を実装する。推論文やツール呼び出しを訳文として表示しない。実サーバーなしでテストしコミットする。

### 第3作業：翻訳の状態管理と文章取得との接続

進行・失敗・停止・遅延応答・同一入力・設定変更・コピーと手入力の確認を先にテストする。`TranslationModel`で要求IDと途中の訳文を管理し、処理中の同一要求を重複送信しない。再翻訳は明示的な操作とし、原文を保持して未完了を区別する。未確認のコピー文を送信せず、古い結果が上書きしないことを確認してコミットする。

### 第4作業：接続設定とポップアップ

接続確認・トークン保存失敗・古い接続結果のテストを追加する。接続・翻訳の設定タブをスクロールなしで追加し、表示言語と翻訳方向を分離する。モデル一覧の取得と、内容が明確な固定文による試し翻訳を別操作にする。ポップアップに進行・停止・再翻訳・コピーを追加し、終了・サンプル・手入力時に不要な処理を停止する。バックグラウンドテストと別保存先のDebugビルドを確認し、実画面の見た目・フォーカスは未確認としてコミットする。

### 第5作業：テスト用サーバーと検証記録

ループバックだけで動作し、原文やトークンをログへ出さない、固定応答のテスト用サーバーを用意する。本物のクライアントを合成資料で接続検証する。バックグラウンドテスト、`.build/validation` でのDebug・ユニバーサルReleaseビルド、署名・翻訳キーを確認する。実LLMと実画面で残る確認をREADME・開発計画・検証記録へ記載する。最後に独立レビューを一度行い、重要な指摘を回帰テスト付きで直してコミットする。マージは行わない。
