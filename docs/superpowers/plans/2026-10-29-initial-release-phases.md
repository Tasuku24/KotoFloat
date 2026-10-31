# KotoFloat Initial Release Phases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

[English](#english) | [日本語](#日本語)

## English

**Goal:** Deliver the first version of a macOS app that translates selected text through a self-hosted LLM, includes glossaries, and keeps its popup open while using AutoRaise.

**Architecture:** Combine SwiftUI screens with AppKit window management and text capture. The popup and main window share translation state; glossary and networking logic remain separate from the UI.

**Tech Stack:** Swift 6, SwiftUI, AppKit, URLSession, versioned JSON glossary storage, Keychain, and Swift Package Manager. KeyboardShortcuts is the proposed shortcut library. LM Studio's OpenAI-compatible API is the first integration target.

**Spec:** The requirements summary in this document and the design discussion in the project chat. This is a phased roadmap; file-level implementation steps, types, and detailed tests will be defined before starting each phase.

### Revised sequence (2026-10-31)

The initial release now has seven phases. Phase 5 has been merged into `main`, but its remaining acceptance work is still open. Language selection and favorite languages are Phase 6; the former Phase 6 becomes Phase 7. Phase 6 is implemented on its feature branch, with remaining acceptance recorded separately. A merge does not establish acceptance completion.

| Phase | Scope | Status |
| --- | --- | --- |
| 1 | App foundation and popup | Implemented; actual AutoRaise acceptance remains open. |
| 2 | Selected-text capture | Implemented; remaining physical-user checks stay in the verification record. |
| 3 | LLM connection and basic translation | Implemented; local models and host HTTPS/Tailscale verified; remaining desktop/distribution checks are open. |
| 4 | Glossary integration | Implemented; model adherence has limitations and desktop acceptance remains open. |
| 5 | Main translation window and editing | Merged into `main`; remaining acceptance work is tracked below. |
| 6 | Searchable language selection and favorites | Implemented; verification and remaining acceptance are recorded in Phase 6. |
| 7 | End-to-end verification and distribution preparation | Follows Phase 6 and closes outstanding acceptance work from earlier phases. |

Develop Phase 6 on `feature/language-picker-and-favorites` from the latest `main`, rather than continuing the merged Phase 5 branch. Define its detailed design and implementation plan before product-code changes. Fix any newly discovered draft-loss or stale-response defect before building on the affected behavior; unresolved acceptance items remain visible and block release claims.

### Global constraints

- The initial version is Mac-only, with macOS 15 or later as the proposed deployment target.
- Final model selection happens after development. Use fixed responses for API contract tests and a provisional model for live integration checks.
- Glossaries belong in the initial version. Selecting alternative translations by clicking text belongs in a later version.
- Work in /Users/s26037/Developer/KotoFloat.
- Write human-readable prose in files destined for GitHub in English first, followed by Japanese, by default. Keep code and configuration syntax and identifiers in their conventional forms; write commit messages in English.
- Keep credentials, real translation input, personal glossaries, and model files out of the public repository.
- Keep the app working at each phase and record evidence for completion criteria. Do not report unverified behavior as successful.

### Requirements summary

- Capture selected text with a shortcut and request a translation from a local LLM server.
- Make the popup movable and resizable. Reusing its previous position is the proposed default.
- Also offer placement near the selection, falling back to the pointer when selection bounds are unavailable.
- Keep the popup open when it loses focus, the user clicks outside it, or time passes.
- Close it with Esc while it has focus, its close button, or application exit.
- Normally preserve the source app's focus when showing the popup; do not intercept Esc in another app.
- Keep always-on-top behavior separate from dismissal behavior. Enabled is the proposed default.
- Do not automatically move or resize the popup as translation text arrives. Scroll long results inside it.
- Reuse one popup. Stale responses must not overwrite newer results.
- Store glossaries on the Mac and send only relevant entries with a translation request.
- Distinguish source text, generated translation, and edited translation. Moving to the editor must not generate a new translation.
- Open a searchable target-language dropdown by clicking the language name in the popup, and configure a few favorite languages in settings for quick switching. Phase 6 uses up to five favorite buttons with Command-1–5 active only in the focused popup/editor.

### Review focus

- AutoRaise moves focus to another app: verify on the actual setup in Phase 1 that the popup stays open and does not interfere with Esc in other apps.
- Another copy occurs immediately after text capture: verify in Phase 2 that clipboard restoration preserves the newer content.
- A response arrives after cancellation: test in Phase 3 that it cannot restore or overwrite a result.
- Conflicting glossary entries or a partially invalid CSV: test in Phase 4 that conflicts are visible and invalid imports do not partially update existing data.
- Retranslation or window changes after manual edits: verify in Phase 5 that edits are not silently lost.
- Language changes and favorite shortcuts: verify in Phase 6 that existing drafts and request-language snapshots remain intact, and that controls do not intercept input in another app.

---

### Phase 1: App foundation and popup

Implementation and automated checks are ready. Physical AutoRaise acceptance remains pending; see the [verification record](../../testing/phase-1.md).

- [x] Set up the Xcode project, menu bar presence, settings, and a customizable shortcut.
- [x] Use fixed sample translations to implement movement, resizing, scrolling, and always-on-top behavior.
- [x] Implement focus and Esc rules, position and size persistence, and multiple-display handling.
- [ ] Check moving between the source and popup using the actual AutoRaise configuration.

**Completion criteria:** The popup works without translation, stays open across focus changes, and can be moved away from the source. Esc closes it only while the popup is active. No automatic movement or resizing occurs.

### Phase 2: Selected-text capture

Implementation is ready. The app captured synthetic Chrome and Preview selections through its shortcut after permission approval; remaining physical-user checks are tracked in the [verification record](../../testing/phase-2.md).

- [x] Add Accessibility permission guidance and capture selected text, its source, and selection bounds when available.
- [x] Add copy-based capture when direct access fails, plus manual paste when capture fails.
- [x] Handle empty selections, copy failure, stale clipboard content, and app switches during capture.
- [x] Verify the browsers and PDF viewer used in practice and record which apps were confirmed to work.

**Completion criteria:** The actual selected text reaches the popup. Unselected text is not accidentally sent, new clipboard content is not overwritten, and capture failures are explained.

### Phase 3: LLM connection and basic translation

Implementation, fixed fixtures, and the intended `hy-mt2-7b` host over HTTPS/Tailscale are verified. Signed-app loopback Keychain evidence is in Phase 5; remaining desktop boundaries are in [Phase 3 verification](../../testing/phase-3.md).

- [x] Provide settings for the endpoint URL, model, and a token stored in Keychain.
- [x] Separate connection checks through GET /v1/models from trial translations through POST /v1/chat/completions.
- [x] Implement language settings, streaming, copying, retranslating, and cancellation.
- [x] Test malformed responses, authentication failures, unavailable models, timeouts, and interrupted streams using fixed responses.
- [x] Use request IDs to discard stale responses and prevent duplicate requests from repeated shortcuts. Do not present interrupted output as complete.
- [x] Verify real host integration over HTTPS and Tailscale through the production client: model list, trial, authentication, translation/cancellation, and English/Japanese samples (2026-11-01). Separate remote signed-app desktop checks remain in the Phase 3 record.

**Completion criteria:** Selection, translation, and copying work end to end. Final model selection is unnecessary, but an untested real server must remain explicitly unverified.

### Phase 4: Glossary integration

Implementation and background/loopback checks are ready; real-model adherence and actual glossary-window/file-panel acceptance remain pending. See [Phase 4 verification](../../testing/phase-4.md).

- [x] Implement glossary and entry creation, editing, searching, deletion, and glossary selection.
- [x] Store source terms, preferred translations, language direction, context notes, case handling, and enabled state.
- [x] Implement CSV import preview, validation, duplicate handling, and export.
- [x] Extract relevant terms for translation requests and flag conflicts or missing preferred translations for review.
- [x] Test partial-word matches, Japanese text, duplicate entries, quoted or multiline CSV fields, invalid rows, and save failures.
- [x] Verify restoration after restart and a versioned storage schema.

- [ ] Verify glossary adherence with a real model and the glossary window/import/export on the desktop.

**Completion criteria:** Glossaries persist and are included in translation requests. Check adherence with a real model, without promising perfect compliance or applying unconditional string replacements.

### Phase 5: Main translation window and editing

Merged into `main` through PR #5 on 2026-10-31; acceptance is still in progress. Recorded verification includes 115 background/loopback tests and 17 native tests passing. Authorized desktop checks covered editing/undo, selected window transitions, a local real model, and Keychain. Actual IME/VoiceOver/AutoRaise and the remaining visual/lifecycle matrix still need acceptance; host HTTPS/Tailscale was subsequently verified in Phase 3; see [Phase 5 verification](../../testing/phase-5.md).

- [x] Provide source input, the generated translation, an editable translation, copying, and undo.
- [x] Transfer the same translation state from the popup to the main window.
- [x] Track edits and revision numbers so retranslating does not silently discard changes.
- [x] Complete source expansion, active glossary display, and explicit retranslation after changing a language or glossary in the popup.
- [ ] Complete the remaining editor IME, keyboard/VoiceOver, visual, and active-generation lifecycle checks recorded in Phase 5 verification. Include actual AutoRaise and the remaining remote signed-app desktop acceptance from Phase 3 in Phase 7; do not mark them passed because of the merge.

**Completion criteria:** Users can edit without regenerating, and navigation or delayed responses cannot corrupt edits. Click-based alternative translations are not implemented yet.

### Phase 6: Searchable language selection and favorites

Implemented on `feature/language-picker-and-favorites`; see the [detailed plan](2026-10-31-phase-6-languages.md) and [verification record](../../testing/phase-6.md). Final model selection and remaining physical-user acceptance are separate.

- [x] Define 26 selectable languages, English/Japanese/native search names and codes, and Chinese-script/Portuguese-region variants. State model-quality limits in the picker.
- [x] Implement a shared native search dropdown, selected-language indicator, arrows/Return, and picker-only Escape without sending a request.
- [x] Persist up to five ordered favorites, with add/remove/reorder in Translation settings; default Japanese/English and allow an empty list.
- [x] User chose favorite buttons plus Command-1–5, active only in the focused popup/editor.
- [x] Share preferences between windows; keep `automatic`/`en`/`ja`, JSON schema version 1, CSV codes, and exact glossary direction matching. No storage migration is needed.
- [x] Keep explicit retranslation, request-language snapshots, draft protection, and stale-response rejection.
- [x] Verify catalog/search/persistence, requests/glossary compatibility, edited drafts, and native focus/Escape/keyboard behavior; record remaining physical IME/VoiceOver/layout acceptance.

**Completion criteria:** Users can search for and select a target language from the popup and quickly select configured favorites. Both translation windows agree on the selection, existing data and edits remain safe, and language/model limitations and desktop verification results are recorded. Final model selection is not part of this phase.

### Phase 7: End-to-end verification and distribution preparation

This is the former Phase 6. Close outstanding acceptance items from Phases 1–6, retaining links to their original evidence rather than resetting their status.

- [ ] Verify the complete flow: first launch, permissions, connection, selected-text translation, language search/favorite switching, glossary use, and editing.
- [ ] Check AutoRaise, wake from sleep, network loss, display changes, long text, and repeated actions on real devices.
- [ ] Check keyboard access, VoiceOver labels, text size, and light/dark appearance.
- [ ] Verify glossary backup and preservation during upgrades, plus diagnostics that exclude credentials and translation content.
- [ ] Add macOS builds and logic tests to CI, and update the README and known limitations.
- [ ] Create an installable app and complete Developer ID signing and notarization before general distribution. If signing credentials are unavailable, clearly identify it as a local verification build.

**Completion criteria:** The initial features work together, real-device results and limitations are recorded, and upgrades preserve glossaries. Publishing source code alone does not mean the app is notarized.

### After the initial version

- Final model selection: compare fluency, accuracy, technical terminology, glossary adherence, and latency using actual text.
- Alternative translations: design word/phrase selection, contextual suggestions, apply/undo, and stale-suggestion invalidation.
- Evaluate OCR, translation history, and additional server support in separate plans.

### Execution approach

Use Phase 1 as the first review point. Before each phase, define detailed implementation steps, implement the smallest complete behavior and necessary tests, and commit before moving on. Track implementation, merge status, and acceptance separately. The initial version includes all seven phases, glossaries, and searchable language selection/favorites; the translation demo in Phase 3 and the Phase 5 merge are not the finished release.

---

## 日本語

> **エージェント向け:** この計画をタスク単位で実装する際は、superpowers:subagent-driven-development（推奨）またはsuperpowers:executing-plansスキルを使用する。進捗はチェックボックス（`- [ ]`）で管理する。

**目標:** 用語集を備え、自分のLLMサーバーで選択文章を翻訳でき、AutoRaise利用中も消えないmacOSアプリの初期版を完成させる。

**構成:** SwiftUIの画面とAppKitのウィンドウ・文字取得処理を組み合わせる。ポップアップとメイン画面は同じ翻訳結果を共有し、用語集・通信処理は画面から分離する。

**技術構成:** Swift 6、SwiftUI、AppKit、URLSession、バージョン付きJSON形式の用語集保存、Keychain、Swift Package Manager。ショートカットはKeyboardShortcutsを採用する案。LM StudioのOpenAI互換APIを最初の検証対象とする。

**仕様:** 本書の「要求の整理」とチャットでの設計議論。これは段階分けの計画であり、各段階のファイル・型・詳細テストを定義する実装手順は着手前に具体化する。

### 開発順序の改訂（2026-10-31）

初期版を7段階に変更する。第5段階は`main`へマージ済みだが、残る受け入れ確認は未完了。言語選択・お気に入りを第6段階とし、従来の第6段階を第7段階へ移す。第6段階は専用ブランチで実装し、残る受け入れ確認を別途記録している。マージ済みを受け入れ確認済みとは扱わない。

| 段階 | 範囲 | 状況 |
| --- | --- | --- |
| 1 | アプリの土台とポップアップ | 実装済み。実AutoRaiseの受け入れ確認が残る。 |
| 2 | 選択文章の取得 | 実装済み。残る実操作確認は検証記録で管理する。 |
| 3 | LLM接続と基本翻訳 | 実装済み。ローカル実モデルとホストHTTPS／Tailscaleを確認。残る実画面・配布時の確認は未完了。 |
| 4 | 用語集 | 実装済み。モデルの用語遵守には制限があり、実画面の確認も残る。 |
| 5 | メイン翻訳画面と編集 | `main`へマージ済み。残る受け入れ確認は以下で管理する。 |
| 6 | 検索付き言語選択とお気に入り | 実装済み。検証と残る受け入れ確認は第6段階に記録。 |
| 7 | 通し検証と配布準備 | 第6段階後に実施し、前段階から残る受け入れ確認を完了する。 |

第6段階は、マージ済みの第5段階のブランチを継続せず、最新の`main`から`feature/language-picker-and-favorites`を作って開発する。製品コードの変更前に詳細設計と実装手順を定義する。下書き消失や古い応答による上書きが新たに判明した場合は、その動作へ機能を積み重ねる前に修正する。未完了の受け入れ項目は保持し、リリース完了の扱いを妨げる条件とする。

### 全体の制約

- 初期版はMac専用。macOS 15以降を設計上の対象とする案。
- モデルの最終選定は開発後。通信契約のテストには固定応答を使い、実接続には仮のモデルを使う。
- 用語集は初期版に含める。クリックによる別訳候補の選択は後続版。
- 作業場所は /Users/s26037/Developer/KotoFloat。
- GitHubに上げるファイル内の説明文は、原則として英語を先に、日本語を後に配置する。コード・設定の構文や識別子は通常の形式を維持し、コミットメッセージは英語にする。
- 認証情報、実際の翻訳文、個人の用語集、モデルファイルを公開リポジトリに含めない。
- 各段階で動作する状態を保ち、完了条件の証拠を残す。未検証を成功として扱わない。

### 要求の整理

- 選択文章をショートカットで取得し、ローカルLLMサーバーへ翻訳を依頼する。
- ポップアップは移動・リサイズ可能。前回位置を使う方式を初期設定として提案する。
- 選択箇所の近くへ配置する方式も提供し、位置が取得できない場合はカーソル付近を使う。
- フォーカス喪失、外側クリック、時間経過でポップアップを閉じない。
- ポップアップにフォーカスがあるときのEsc、閉じるボタン、アプリ終了で閉じる。
- 表示時は元アプリのフォーカスを原則維持し、別アプリのEscを横取りしない。
- 最前面固定は閉じる条件と独立した設定。初期状態はオンを提案する。
- 翻訳が増えても自動移動・自動リサイズしない。長文はスクロールする。
- 一つのポップアップを再利用する。古い応答は新しい結果を上書きしない。
- 用語集はMac内に保存し、関係する項目のみを翻訳要求へ含める。
- 原文、生成訳、編集後の訳文を区別する。編集画面への移動で再翻訳しない。
- ポップアップの言語名を押すと検索付きの翻訳先言語プルダウンを開き、設定で数個のお気に入り言語を登録して素早く切り替えられるようにする。第6段階では最大5個のボタンと、フォーカス中のポップアップ／エディタ内だけで有効なCommand-1〜5を使う。

### 重点確認項目

- AutoRaiseで別アプリへフォーカスが移る条件：ポップアップが残り、他アプリのEscも妨げないことを第1段階で実機確認する。
- コピー直後に別のコピーが起きる条件：新しいクリップボードを復元処理で壊さないことを第2段階で検証する。
- キャンセル後に応答が届く条件：結果が復活・上書きされないことを第3段階でテストする。
- 同じ用語の競合やCSVの一部不正：競合を表示し、不正な取り込みで既存データを部分更新しないことを第4段階でテストする。
- 手動編集後の再翻訳や画面移動：編集内容を黙って失わないことを第5段階で検証する。
- 言語変更とお気に入りのショートカット：下書きと要求時の言語情報を保持し、別アプリの入力を横取りしないことを第6段階で検証する。

---

### 第1段階：アプリの土台とポップアップ

実装と自動検証は完了しています。実際のAutoRaise操作の確認は保留です。[検証記録](../../testing/phase-1.md)を参照してください。

- [x] Xcodeプロジェクト、メニューバー常駐、設定画面、変更可能なショートカットを用意する。
- [x] 固定のサンプル訳文で移動・リサイズ・スクロール・最前面固定を実装する。
- [x] フォーカスとEscの条件、位置・サイズの保持、複数ディスプレイを扱う。
- [ ] AutoRaiseを使う実際の設定で、原文とポップアップを行き来する操作を確認する。

**完了条件:** 翻訳機能なしでも操作でき、フォーカスが移っても消えず、原文を隠したら移動できる。Escはポップアップがアクティブなときだけ閉じる。自動移動・リサイズは発生しない。

### 第2段階：選択文章の取得

実装は完了し、権限許可後にChromeとプレビューのテスト資料をアプリのショートカットから取得できることを確認しました。実際の利用者環境で残る確認は[検証記録](../../testing/phase-2.md)で管理します。

- [x] Accessibility権限案内と、選択文章・取得元・取得可能なら選択範囲の位置を取得する処理を用意する。
- [x] 直接取得できない場合のコピー取得と、失敗時の手動貼り付けを用意する。
- [x] 空選択、コピー失敗、古いクリップボード、処理中のアプリ切り替えを扱う。
- [x] 普段使うブラウザとPDFビューアで検証し、動作を確認できたアプリを記録する。

**完了条件:** 実際に選択した原文をポップアップへ渡せる。選択していない文章を誤送信せず、ユーザーの新しいコピーを上書きしない。取得失敗を説明できる。

### 第3段階：LLM接続と基本翻訳

実装・固定応答と、目的の`hy-mt2-7b`ホストへのHTTPS／Tailscale通信は確認済みです。署名済みアプリのループバックKeychainの証拠は第5段階にあり、実画面の残る範囲は別途管理します。[第3段階の検証記録](../../testing/phase-3.md)を参照してください。

- [x] 接続先URL、モデル、Keychainに保存するトークンを設定できるようにする。
- [x] GET /v1/modelsによる接続確認と、POST /v1/chat/completionsによる試し翻訳を分ける。
- [x] 言語設定、ストリーミング、コピー、再翻訳、キャンセルを実装する。
- [x] 不正応答、認証失敗、モデル不在、タイムアウト、通信途中の切断を固定応答でテストする。
- [x] 要求IDで古い応答を排除し、連打による重複送信を防ぐ。中断結果を完成訳として扱わない。
- [x] 実ホストへHTTPSとTailscale経由で本番クライアントを接続し、モデル一覧・試し翻訳・認証・翻訳／停止・英日サンプルを確認する（2026-11-01）。遠隔の署名済みアプリの実画面確認は第3段階の記録に別途残します。

**完了条件:** 選択→翻訳→コピーが通る。モデル最終選定は不要だが、実サーバー未確認ならその旨を残し、通信の実機検証完了とはしない。

### 第4段階：用語集を翻訳へ組み込む

実装とバックグラウンド・ループバック検証は完了しています。実モデルの用語遵守と用語集画面・ファイルパネルの実操作は未確認です。[第4段階の検証記録](../../testing/phase-4.md)を参照してください。

- [x] 用語集と項目の登録・編集・検索・削除・切り替えを実装する。
- [x] 原語、訳語、言語方向、文脈の補足、大文字小文字の扱い、有効状態を保存する。
- [x] CSV取り込みのプレビュー・検証・重複処理と、書き出しを実装する。
- [x] 関連用語を抽出して翻訳へ渡し、競合と指定訳語が見当たらない結果を要確認として示す。
- [x] 単語の部分一致、日本語、重複項目、引用符や改行を含むCSV、不正行、保存失敗をテストする。
- [x] 再起動後の復元と、バージョンを持つ保存形式を確認する。

- [ ] 実モデルでの用語適用、用語集画面・取り込み・書き出しの実操作を確認する。

**完了条件:** 用語集が永続化され、翻訳要求へ反映される。用語の適用は実モデルでも確認するが、必ず従うという保証や無条件の文字列置換は行わない。

### 第5段階：メイン翻訳画面と編集

2026-10-31にPR #5で`main`へマージ済みですが、受け入れ確認は継続中です。記録済みの検証では、背景／ループバック115テスト、ネイティブ17テストが成功しました。許可を受けた実画面で編集／Undo、一部の画面遷移、ローカル実モデル、Keychainを確認しました。実IME／VoiceOver／AutoRaise、残る視覚・ライフサイクルの組み合わせは受け入れ確認が必要です。ホストHTTPS／Tailscaleはその後第3段階で確認しました。[第5段階の検証記録](../../testing/phase-5.md)を参照してください。

- [x] 原文入力、生成訳、編集可能な訳文、コピー、取り消しを用意する。
- [x] ポップアップから同じ翻訳状態をメイン画面へ引き継ぐ。
- [x] 手動編集の有無と版番号を管理し、再翻訳で変更を黙って失わない動作を用意する。
- [x] ポップアップでの原文展開、使用中の用語集表示、言語・用語集変更後の明示的な再翻訳を整える。
- [ ] 第5段階の検証記録にある、エディタの実IME、キーボード／VoiceOver、表示、生成中の画面操作の残る確認を完了する。実AutoRaiseと、第3段階に残る遠隔の署名済みアプリの実画面確認は第7段階にも含め、マージを理由に確認済みとしない。

**完了条件:** 再生成なしで訳文を編集でき、画面移動や遅延応答で編集内容が壊れない。単語クリックによる別訳候補はまだ実装しない。

### 第6段階：検索付き言語選択とお気に入り

`feature/language-picker-and-favorites`で実装しました。[詳細計画](2026-10-31-phase-6-languages.md)と[検証記録](../../testing/phase-6.md)を参照してください。モデルの最終選定と残る実利用者の受け入れ確認は別です。

- [x] 26言語、英語／日本語／現地名とコード、中国語の字体・ポルトガル語の地域差を定義し、モデル品質の制限を選択画面に表示する。
- [x] 共通のネイティブ検索画面、選択表示、上下矢印／Return、選択画面だけを閉じるEscを実装し、選択では送信しない。
- [x] お気に入りを最大5件、順序付きで保存し、設定の翻訳タブで追加・削除・並べ替える。初期値は日本語／英語、空も許可する。
- [x] 利用者がボタン＋Command-1〜5を選択し、フォーカス中のポップアップ／エディタ内だけで有効にする。
- [x] 両画面で設定を共有し、`automatic`／`en`／`ja`、JSON版1、CSVコード、用語集方向の厳密な一致を維持する。保存移行は不要。
- [x] 明示的な再翻訳、要求時の言語情報、下書き保護、古い応答の排除を維持する。
- [x] 言語一覧・検索・復元、要求・用語集互換、編集保持、ネイティブのフォーカス／Esc／キー操作を検証し、実IME／VoiceOver／画面配置の残項目を記録する。

**完了条件:** ポップアップで翻訳先言語を検索・選択でき、登録したお気に入りへ素早く切り替えられる。両翻訳画面の選択が一致し、既存データと編集内容を保持し、言語・モデルの制限と実画面の確認結果を記録する。モデルの最終選定は本段階に含めない。

### 第7段階：初期版の通し検証と配布準備

従来の第6段階。第1〜第6段階から残る受け入れ項目を、元の証拠へのリンクと進捗を保持して完了する。

- [ ] 初回設定→権限許可→接続→選択翻訳→言語検索・お気に入り切り替え→用語集→編集の一連の操作を確認する。
- [ ] AutoRaise、スリープ復帰、ネットワーク切断、ディスプレイ変更、長文、連続操作を実機で確認する。
- [ ] キーボード操作、VoiceOverのラベル、文字サイズ、ライト／ダーク表示を確認する。
- [ ] 用語集のバックアップと更新時の保全、資格情報・本文を含まない診断を確認する。
- [ ] macOS用のビルド・ロジックテストをCIへ追加し、READMEと既知の制限を更新する。
- [ ] インストール可能なアプリを作成し、一般配布前にDeveloper ID署名と公証を行う。利用可能な署名資格情報がなければローカル検証版として区別する。

**完了条件:** 上記の初期機能が一通り動き、実機確認の結果と制限が記録され、用語集を保持して更新できる。公開ソースコードだけで配布アプリの公証済みとは主張しない。

### 初期版の後

- モデル最終選定：自然さ、意味の正確さ、専門用語、用語集への従い方、遅延を実際の文章で比較する。
- 別訳候補：単語・フレーズの選択、文脈付き候補、適用と取り消し、古い候補の無効化を設計する。
- OCR、翻訳履歴、追加サーバーへの対応は別の計画で判断する。

### 実行上の方針

第1段階を最初の確認点とする。各段階の詳細手順を作成し、最小限の実装と必要なテストを行い、コミットしてから次へ進む。実装、マージ、受け入れ確認の進捗は分けて管理する。用語集・検索付き言語選択・お気に入りを含む第7段階までを初期版とし、第3段階の翻訳デモや第5段階のマージで完成とはしない。
