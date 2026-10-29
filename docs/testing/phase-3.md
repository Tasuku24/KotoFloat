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

ATS permits custom HTTP endpoints because users choose their own servers. Application validation permits loopback HTTP automatically and requires explicit opt-in for other HTTP; opt-in does not encrypt data. Prefer HTTPS or a trusted VPN remotely. Real remote access and local-network permission remain unverified.

Limits: 128 KiB source input, 1 MiB model-list response, 4 MiB SSE input, and 1 MiB generated output. The inactivity timeout is 120 seconds and session resource timeout is 300 seconds. There are no automatic retries, cloud fallback, source/output logs, or history. The fixture binds only to `127.0.0.1` and does not log bodies or tokens.

### Remaining acceptance

- [ ] Actual app connection to LM Studio or another compatible LLM: model list, trial translation, and English/Japanese quality. A provisional model is sufficient.
- [ ] Remote HTTPS/VPN, real authentication token, local-network permission, and Keychain save/read/delete in the signed app. Storage tests use an injected store, not the system Keychain.
- [ ] Both UI languages, all five settings tabs without scrolling/clipping, streaming progress, completed-copy behavior, cancellation, and retranslation in the actual app.
- [ ] Native-window tests and real Chrome/Preview selection, AutoRaise, focus/Escape, long output, and popup geometry. The running Phase 2 app was intentionally left untouched.

Implementation and fixed-fixture evidence are ready. Real-server and desktop acceptance remain pending. This is an ad-hoc-signed, non-notarized development preview.

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

利用者がサーバーを選ぶため、ATSでは任意のHTTP接続先を扱えるようにしています。アプリ内の検証でループバックHTTPを自動許可し、それ以外には明示的な有効化を要求します。有効化しても暗号化されません。遠隔接続にはHTTPSまたは信頼するVPNを推奨します。実際の遠隔接続とローカルネットワーク権限は未確認です。

上限は原文128 KiB、モデル一覧1 MiB、SSE入力4 MiB、生成文1 MiBです。応答が来ない場合は120秒、セッション全体は300秒でタイムアウトします。自動再試行、クラウドへの代替接続、原文・訳文ログ、履歴はありません。テスト用サーバーは `127.0.0.1` だけで待ち受け、本文やトークンを記録しません。

### 今後必要な確認

- [ ] 実アプリからLM Studioなどへ接続し、モデル一覧・試し翻訳・英日品質を確認する。仮モデルでよい。
- [ ] 遠隔HTTPS／VPN、実トークン、ローカルネットワーク権限、署名済みアプリのKeychain保存・読み取り・削除を確認する。保存テストは差し替えたストアを使用しており、システムKeychainの確認ではない。
- [ ] 英日UI、5つの設定タブがスクロール・欠けなしで収まること、進行表示、完了訳文のコピー、停止・再翻訳を実アプリで確認する。
- [ ] ウィンドウ用テスト、実際のChrome・プレビューからの取得、AutoRaise、フォーカス・Esc、長文、位置・サイズを確認する。起動中の第2段階のアプリは意図的に変更していない。

実装と固定応答での検証は整いました。実サーバー・実画面の確認は保留です。引き続きアドホック署名の、公証していない開発用プレビューです。
