# Phase 3 verification / 第3段階の検証

## English

### Implemented scope

OpenAI-compatible model listing and streaming Chat Completions, endpoint/model settings, endpoint-scoped Keychain tokens, translation direction, stop/retranslate/copy controls, and capture-to-translation handoff are implemented. Direct selection and confirmed manual input can translate; copied text waits for confirmation. The default is automatic source detection into Japanese. UI language and translation direction remain separate.

Request IDs invalidate late callbacks after cancellation, replacement, manual entry, or popup close. Identical active requests are coalesced. Language changes apply to the next request; Retranslate explicitly applies them to current text. Partial/failed output is labeled incomplete and cannot be copied using the copy button. Stream callbacks do not change popup geometry.

### Background evidence (2026-10-30)

- `python3 scripts/test_with_mock_server.py`: **82 tests pass**, including settings/credential contracts, streaming parsing, translation/connection state, and real loopback HTTP integration.
- New settings, client, lifecycle, and connection-state tests failed before implementation and passed afterward. They use synthetic input, isolated preferences, named pasteboards, and an in-memory credential store; the login Keychain is not modified.
- URLSession and parser tests cover fragmented UTF-8/SSE, request construction, model lists, malformed/interrupted output, authentication/model/rate-limit errors, and timeouts. Reasoning fields are ignored; completion requires a normal stop plus the terminal SSE marker.
- The loopback server verifies the actual client, redirect rejection, interrupted/malformed streams, unavailable models, authentication failures, and confirmed manual input reaching a complete result. It returns a clearly labeled fixed test response, not a real translation.
- Debug and universal Release (arm64/x86_64) builds passed in `.build/validation`; both local signatures verified and English/Japanese keys matched. The `.build/xcode` app executable's checksum did not change.
- No app launch/restart, synthesized input, or focus changes were used. The 15 native-window tests were excluded; their earlier Phase 2 success is not a new Phase 3 result.
- An independent whole-branch review found one important issue: an endpoint edit could carry an unsaved token, token-removal intent, and HTTP approval to another server. Regression tests reproduced it before the fix. Changing normalized endpoint identity now clears all three, while equivalent URL formatting preserves them. The full 82-test background suite passed afterward. No deferred minor findings remain.

### Transport and data boundaries

Requests occur only after connection checks, disclosed trial translations, or confirmed text using saved settings. Tokens belong to the normalized endpoint. A failed credential write leaves connection preferences unchanged. Blank token input preserves that endpoint's token; removal is explicit. Redirects, embedded URL credentials, queries, and fragments are rejected. Sessions disable cookies, credential storage, and caching; HTTPS uses system certificate validation.

ATS permits custom HTTP endpoints because users choose their own servers. Application validation permits loopback HTTP automatically and requires explicit opt-in for other HTTP; opt-in does not encrypt data. Prefer HTTPS or a trusted VPN remotely. Real HTTPS over Tailscale was verified below; signed-app local-network permission behavior was not exercised in this background pass.

Limits: 128 KiB source input, 1 MiB model-list response, 4 MiB SSE input, and 1 MiB generated output. The inactivity timeout is 120 seconds and session resource timeout is 300 seconds. There are no automatic retries, cloud fallback, source/output logs, or history. The fixture binds only to `127.0.0.1` and does not log bodies or tokens.

### Host LLM verification (2026-11-01)

The user reported that the actual app already connected and its test succeeded. This additional background pass used the saved HTTPS Tailscale endpoint and `hy-mt2-7b`, with HTTP opt-in disabled. The host was online in Tailscale. The production URLSession client completed requests using system certificate validation, without a certificate override or redirect. The existing endpoint-scoped token was read through `KeychainCredentialStore` without prompting; it was never printed or written to a report. No app preferences, Keychain entries, personal glossaries, or server settings were changed. No app launch, restart, focus change, or input synthesis was used.

**Five opt-in integration tests passed in 57.917 seconds**, sequentially through the production connection/translation models, client, and SSE decoder:

- Model discovery and the connection settings' fixed trial translation completed. The selected model was present in the model list.
- Missing and deliberately invalid tokens were rejected as authentication failures; the saved token allowed model discovery and generation.
- Confirmed manual input generated a nonempty complete result. Generated/edited separation, Undo/Redo, edited-result copying to a named pasteboard, Keep editing, confirmed retranslation, document/undo reset, swap without sending, and clear confirmation passed.
- Cancellation after an actual text callback raised `CancellationError`.
- Eight recorded English/Japanese samples completed, including automatic source selection, two-paragraph text, and two glossary terms in each explicit direction. Glossary snapshots matched the selected entries, and no preferred term was missing.

Manual content review found that all eight samples preserved meaning, numbers/units, target language, and paragraph breaks where present, with no prompt echo or unrelated explanation. Both glossary directions used the requested terms. Unit spacing was normalized in one Japanese paragraph sample (`5 V` to `5V`, `0.2 A` to `0.2A`). This is a small acceptance sample, not a general translation-quality benchmark. Source and output are in [host-llm-acceptance.json](host-llm-acceptance.json); only synthetic test sentences are recorded. Model file, quantization, context length, and host inference settings were not inspected or changed.

To repeat against an already configured, authenticated server:

```sh
mkdir -p .build/host-llm-acceptance
KOTOFLOAT_USE_SAVED_SERVER=1 KOTOFLOAT_EVALUATION_REPORT="$PWD/.build/host-llm-acceptance/content.json" nice -n 10 swift test --jobs 2 --skip PopupControllerTests --filter LocalModelIntegrationTests
```

This mode reads the app's saved endpoint/model and its Keychain token; isolated preferences, in-memory credentials, temporary glossaries, and named pasteboards own test changes. It requires a saved token and checks that the server rejects missing/invalid credentials. Without either `KOTOFLOAT_USE_SAVED_SERVER=1` or the existing `KOTOFLOAT_LOCAL_MODEL` opt-in, the real-model suite stays disabled. Output recording additionally requires `KOTOFLOAT_EVALUATION_REPORT`. The original loopback mode remains available. Test deadlines allow the production 300-second resource timeout to finish. Local logs are in the ignored `.build/host-llm-acceptance/` directory. No production code changed, so no additional app build was needed.

The subsequent `python3 scripts/test_with_mock_server.py` background run passed: 129 tests reported, with the five opt-in real-model tests skipped and 124 executed. `git diff --check` also passed.

### Acceptance status

- [x] Real compatible host LLM: model list, trial translation, English/Japanese samples, and HTTPS over Tailscale with the existing token through the production client. The user separately reported successful app connection/testing.
- [x] System Keychain read for the host endpoint and live rejection of missing/invalid credentials. Signed-app Keychain save/read/delete with a disposable loopback token was previously verified in [Phase 5](phase-5.md).
- [ ] Independently observed remote signed-app desktop acceptance, including applicable permission behavior and credential persistence across restart. Personal host credentials were not deleted/replaced for testing.
- [ ] Both UI languages, all five settings tabs without scrolling/clipping, streaming progress, completed-copy behavior, cancellation, and retranslation in the actual app.
- [ ] Native-window tests and real Chrome/Preview selection, AutoRaise, focus/Escape, long output, and popup geometry. The running Phase 2 app was intentionally left untouched.

Implementation, fixed-fixture evidence, and the intended host's production-client path are verified. The unchecked desktop criteria remain separate; earlier desktop evidence is recorded in [Phase 5](phase-5.md). This is an ad-hoc-signed, non-notarized development preview.

## 日本語

### 実装範囲

OpenAI互換のモデル一覧取得とChat Completionsのストリーミング、接続先・モデル設定、接続先別のKeychainトークン、翻訳方向、停止・再翻訳・コピー、文章取得から翻訳への接続を実装しました。直接取得した選択文と確定した手入力文を翻訳し、コピー経由の文章は確認を待ちます。初期値は翻訳元が自動判定、翻訳先が日本語です。表示言語と翻訳方向は別設定です。

要求IDにより、停止・置き換え・手入力・ポップアップ終了後の遅い応答を無効化し、処理中の同一要求を重複送信しません。言語変更は次の要求から反映し、現在の文章には再翻訳で適用します。途中・失敗した訳文は未完了と表示し、コピーボタンからはコピーできません。応答処理はポップアップの位置・サイズを変更しません。

### バックグラウンドでの検証（2026-10-30）

- `python3 scripts/test_with_mock_server.py`：**82テスト成功**。設定・認証情報、ストリーム解析、翻訳・接続状態、実際のループバックHTTP通信を含みます。
- 新しい設定・クライアント・要求管理・接続状態のテストは、実装前に失敗、実装後に成功しました。合成文章、独立した設定・名前付きクリップボード、メモリ内の認証情報ストアを使い、ログインキーチェーンは変更していません。
- URLSessionと解析のテストで、分割UTF-8/SSE、要求内容、モデル一覧、不正・中断応答、認証・モデル・要求過多のエラー、タイムアウトを確認しました。推論用フィールドは表示せず、正常な停止とSSE終端がそろってから完了とします。
- ループバックのサーバーで、本体の通信処理、リダイレクト拒否、中断・不正応答、モデル不在、認証エラー、確定した手入力から訳文の完了までを確認しました。テスト用と明示した固定文を返すもので、本物の翻訳ではありません。
- `.build/validation` でDebug・ユニバーサルRelease（arm64/x86_64）のビルドと両方のローカル署名検証が成功し、英日キーも一致しました。`.build/xcode` のアプリ実行ファイルのチェックサムは変わっていません。
- アプリ起動・再起動、入力の送出、フォーカス変更は行っていません。ウィンドウを表示する15件は除外しました。以前の第2段階の成功は、第3段階の再確認にはなりません。
- 独立した全体レビューで、接続先の編集時に入力途中のトークン・削除指定・HTTP許可を別サーバーへ持ち越す問題が1件見つかりました。修正前に回帰テストで再現し、正規化後の接続先が変わった場合は3つともリセットするよう修正。同じURLの表記変更では維持します。修正後は82件のバックグラウンドテストがすべて成功しました。保留した軽微なレビュー指摘はありません。

### 通信とデータの境界

接続確認・明示した固定文の試し翻訳・保存設定を使った確定文章の翻訳でのみ通信します。トークンは正規化した接続先に属し、認証情報の保存失敗時は接続設定を維持します。トークンが空欄ならその接続先の保存済み値を維持し、削除は明示的な操作です。リダイレクト、URL中の認証情報、クエリ、フラグメントは拒否します。セッションではCookie・認証情報ストレージ・キャッシュを無効にし、HTTPSはシステムの証明書検証を使います。

利用者がサーバーを選ぶため、ATSでは任意のHTTP接続先を扱えるようにしています。アプリ内の検証でループバックHTTPを自動許可し、それ以外には明示的な有効化を要求します。有効化しても暗号化されません。遠隔接続にはHTTPSまたは信頼するVPNを推奨します。Tailscale経由の実HTTPS通信は以下で確認済みですが、署名済みアプリのローカルネットワーク権限の挙動は今回の背景検証で操作していません。

上限は原文128 KiB、モデル一覧1 MiB、SSE入力4 MiB、生成文1 MiBです。応答が来ない場合は120秒、セッション全体は300秒でタイムアウトします。自動再試行、クラウドへの代替接続、原文・訳文ログ、履歴はありません。テスト用サーバーは `127.0.0.1` だけで待ち受け、本文やトークンを記録しません。

### ホストLLMでの検証（2026-11-01）

利用者から、実アプリで接続済みでテストも成功したとの報告を受けました。追加の背景検証では、保存済みのHTTPS／Tailscale接続先と`hy-mt2-7b`を使用し、HTTP許可は無効のままでした。Tailscaleでホストがオンラインであることも確認しました。本番URLSessionクライアントは、証明書の例外やリダイレクトなしでシステムの証明書検証を通して通信しました。既存の接続先別トークンは`KeychainCredentialStore`でダイアログを出さずに読み取り、表示・報告ファイルへの記録はしていません。アプリの設定、Keychain項目、個人用語集、サーバー設定は変更していません。アプリの起動・再起動、フォーカス変更、入力送出も行っていません。

本番の接続・翻訳モデル、クライアント、SSEデコーダを順番に通し、**明示実行の統合テスト5件が57.917秒で成功**しました。

- モデル一覧と接続設定の固定文の試し翻訳が完了し、選択モデルが一覧に含まれていました。
- トークンなし・意図的に誤ったトークンは認証エラーとなり、保存済みトークンではモデル一覧と生成が成功しました。
- 確定した手入力から空でない訳文が完了しました。生成訳と編集訳の区別、Undo/Redo、名前付きクリップボードへの編集訳コピー、編集続行、確認付き再翻訳、文書・Undoのリセット、送信しない入れ替え、クリア確認も成功しました。
- 実際の文字列受信後に中断し、`CancellationError`になりました。
- 自動判定、2段落の文章、明示した各方向で用語2件を含む英日8サンプルが完了しました。要求時の用語集は選択項目と一致し、指定訳語の不足はありませんでした。

内容を目視評価し、8例とも意味、数値・単位、出力言語、原文にある段落区切りを維持し、指示文の繰り返しや無関係な説明はありませんでした。両方向の用語集も指定訳語を使用しました。日本語の段落例では単位前の空白が正規化されています（`5 V`→`5V`、`0.2 A`→`0.2A`）。少数の受け入れ例であり、モデル全体の翻訳品質のベンチマークではありません。原文と出力は[host-llm-acceptance.json](host-llm-acceptance.json)に記録し、合成したテスト文章だけを含めています。モデルファイル、量子化、コンテキスト長、ホストの推論設定は調査・変更していません。

設定済みの認証付きサーバーで再実行する場合：

```sh
mkdir -p .build/host-llm-acceptance
KOTOFLOAT_USE_SAVED_SERVER=1 KOTOFLOAT_EVALUATION_REPORT="$PWD/.build/host-llm-acceptance/content.json" nice -n 10 swift test --jobs 2 --skip PopupControllerTests --filter LocalModelIntegrationTests
```

アプリの保存済み接続先・モデルとKeychainトークンを読み取り、テストの変更は独立した設定・メモリ内認証情報・一時用語集・名前付きクリップボードで行います。保存済みトークンが必要で、トークンなし／誤った値をサーバーが拒否することも確認します。`KOTOFLOAT_USE_SAVED_SERVER=1`と既存の`KOTOFLOAT_LOCAL_MODEL`のどちらも指定しない通常のテストでは、実モデルのスイート全体を無効にします。出力記録にはさらに`KOTOFLOAT_EVALUATION_REPORT`が必要です。従来のループバック用モードも維持しました。テストの待機期限は本番の300秒の通信期限まで待てるようにしています。ローカルログは追跡対象外の`.build/host-llm-acceptance/`に保存しました。本番コードに変更がないため、アプリの追加ビルドは行っていません。

その後の`python3 scripts/test_with_mock_server.py`による背景検証も成功しました。報告129件のうち、明示時だけ動く実モデル5件はスキップし、124件を実行しています。`git diff --check`も成功しました。

### 受け入れ状況

- [x] 本物の互換ホストLLMで、モデル一覧・試し翻訳・英日サンプル、既存トークンを用いたTailscale経由のHTTPS通信を本番クライアントで確認。実アプリの接続・テスト成功は、別途利用者から報告を受けています。
- [x] ホスト接続先のシステムKeychain読み取りと、実際のトークンなし／誤った値の拒否を確認。署名済みアプリによる検証専用ループバックトークンの保存・再読み取り・削除は[第5段階](phase-5.md)で確認済みです。
- [ ] 遠隔接続先での署名済みアプリの実画面を独立して確認すること。該当する権限の挙動や再起動後の認証維持を含みます。個人のホスト認証情報は検証のために削除・置換していません。
- [ ] 英日UI、5つの設定タブがスクロール・欠けなしで収まること、進行表示、完了訳文のコピー、停止・再翻訳を実アプリで確認する。
- [ ] ウィンドウ用テスト、実際のChrome・プレビューからの取得、AutoRaise、フォーカス・Esc、長文、位置・サイズを確認する。起動中の第2段階のアプリは意図的に変更していない。

実装、固定応答の検証、目的のホストへの本番クライアント経路は確認済みです。未チェックの実画面項目は別途残し、以前の実画面の証拠は[第5段階](phase-5.md)に記録しています。引き続きアドホック署名の、公証していない開発用プレビューです。
