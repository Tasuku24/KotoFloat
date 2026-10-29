# KotoFloat Initial Release Phases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

[English](#english) | [日本語](#日本語)

## English

**Goal:** Deliver the first version of a macOS app that translates selected text through a self-hosted LLM, includes glossaries, and keeps its popup open while using AutoRaise.

**Architecture:** Combine SwiftUI screens with AppKit window management and text capture. The popup and main window share translation state; glossary and networking logic remain separate from the UI.

**Tech Stack:** Swift 6, SwiftUI, AppKit, URLSession, SwiftData, Keychain, and Swift Package Manager. KeyboardShortcuts is the proposed shortcut library. LM Studio's OpenAI-compatible API is the first integration target.

**Spec:** The requirements summary in this document and the design discussion in the project chat. This is a phased roadmap; file-level implementation steps, types, and detailed tests will be defined before starting each phase.

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

### Review focus

- AutoRaise moves focus to another app: verify on the actual setup in Phase 1 that the popup stays open and does not interfere with Esc in other apps.
- Another copy occurs immediately after text capture: verify in Phase 2 that clipboard restoration preserves the newer content.
- A response arrives after cancellation: test in Phase 3 that it cannot restore or overwrite a result.
- Conflicting glossary entries or a partially invalid CSV: test in Phase 4 that conflicts are visible and invalid imports do not partially update existing data.
- Retranslation or window changes after manual edits: verify in Phase 5 that edits are not silently lost.

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

- [ ] Provide settings for the endpoint URL, model, and a token stored in Keychain.
- [ ] Separate connection checks through GET /v1/models from trial translations through POST /v1/chat/completions.
- [ ] Implement language settings, streaming, copying, retranslating, and cancellation.
- [ ] Test malformed responses, authentication failures, unavailable models, timeouts, and interrupted streams using fixed responses.
- [ ] Use request IDs to discard stale responses and prevent duplicate requests from repeated shortcuts. Do not present interrupted output as complete.
- [ ] When the endpoint is available, verify live integration with a provisional model. Verify remote access over HTTPS and a VPN on real devices.

**Completion criteria:** Selection, translation, and copying work end to end. Final model selection is unnecessary, but an untested real server must remain explicitly unverified.

### Phase 4: Glossary integration

- [ ] Implement glossary and entry creation, editing, searching, deletion, and glossary selection.
- [ ] Store source terms, preferred translations, language direction, context notes, case handling, and enabled state.
- [ ] Implement CSV import preview, validation, duplicate handling, and export.
- [ ] Extract relevant terms for translation requests and flag conflicts or missing preferred translations for review.
- [ ] Test partial-word matches, Japanese text, duplicate entries, quoted or multiline CSV fields, invalid rows, and save failures.
- [ ] Verify restoration after restart and a versioned storage schema.

**Completion criteria:** Glossaries persist and are included in translation requests. Check adherence with a real model, without promising perfect compliance or applying unconditional string replacements.

### Phase 5: Main translation window and editing

- [ ] Provide source input, the generated translation, an editable translation, copying, and undo.
- [ ] Transfer the same translation state from the popup to the main window.
- [ ] Track edits and revision numbers so retranslating does not silently discard changes.
- [ ] Complete source expansion, active glossary display, and explicit retranslation after changing a language or glossary in the popup.

**Completion criteria:** Users can edit without regenerating, and navigation or delayed responses cannot corrupt edits. Click-based alternative translations are not implemented yet.

### Phase 6: End-to-end verification and distribution preparation

- [ ] Verify the complete flow: first launch, permissions, connection, selected-text translation, glossary use, and editing.
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

Use Phase 1 as the first review point. Before each phase, define detailed implementation steps, implement the smallest complete behavior and necessary tests, and commit before moving on. The initial version includes all six phases and glossaries; the translation demo in Phase 3 is not the finished release.

---

## 日本語

> **エージェント向け:** この計画をタスク単位で実装する際は、superpowers:subagent-driven-development（推奨）またはsuperpowers:executing-plansスキルを使用する。進捗はチェックボックス（`- [ ]`）で管理する。

**目標:** 用語集を備え、自分のLLMサーバーで選択文章を翻訳でき、AutoRaise利用中も消えないmacOSアプリの初期版を完成させる。

**構成:** SwiftUIの画面とAppKitのウィンドウ・文字取得処理を組み合わせる。ポップアップとメイン画面は同じ翻訳結果を共有し、用語集・通信処理は画面から分離する。

**技術構成:** Swift 6、SwiftUI、AppKit、URLSession、SwiftData、Keychain、Swift Package Manager。ショートカットはKeyboardShortcutsを採用する案。LM StudioのOpenAI互換APIを最初の検証対象とする。

**仕様:** 本書の「要求の整理」とチャットでの設計議論。これは段階分けの計画であり、各段階のファイル・型・詳細テストを定義する実装手順は着手前に具体化する。

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

### 重点確認項目

- AutoRaiseで別アプリへフォーカスが移る条件：ポップアップが残り、他アプリのEscも妨げないことを第1段階で実機確認する。
- コピー直後に別のコピーが起きる条件：新しいクリップボードを復元処理で壊さないことを第2段階で検証する。
- キャンセル後に応答が届く条件：結果が復活・上書きされないことを第3段階でテストする。
- 同じ用語の競合やCSVの一部不正：競合を表示し、不正な取り込みで既存データを部分更新しないことを第4段階でテストする。
- 手動編集後の再翻訳や画面移動：編集内容を黙って失わないことを第5段階で検証する。

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

- [ ] 接続先URL、モデル、Keychainに保存するトークンを設定できるようにする。
- [ ] GET /v1/modelsによる接続確認と、POST /v1/chat/completionsによる試し翻訳を分ける。
- [ ] 言語設定、ストリーミング、コピー、再翻訳、キャンセルを実装する。
- [ ] 不正応答、認証失敗、モデル不在、タイムアウト、通信途中の切断を固定応答でテストする。
- [ ] 要求IDで古い応答を排除し、連打による重複送信を防ぐ。中断結果を完成訳として扱わない。
- [ ] 接続先が用意できたら仮モデルで実接続を確認する。外出先利用はHTTPSとVPN経由の実機確認を行う。

**完了条件:** 選択→翻訳→コピーが通る。モデル最終選定は不要だが、実サーバー未確認ならその旨を残し、通信の実機検証完了とはしない。

### 第4段階：用語集を翻訳へ組み込む

- [ ] 用語集と項目の登録・編集・検索・削除・切り替えを実装する。
- [ ] 原語、訳語、言語方向、文脈の補足、大文字小文字の扱い、有効状態を保存する。
- [ ] CSV取り込みのプレビュー・検証・重複処理と、書き出しを実装する。
- [ ] 関連用語を抽出して翻訳へ渡し、競合と指定訳語が見当たらない結果を要確認として示す。
- [ ] 単語の部分一致、日本語、重複項目、引用符や改行を含むCSV、不正行、保存失敗をテストする。
- [ ] 再起動後の復元と、バージョンを持つ保存形式を確認する。

**完了条件:** 用語集が永続化され、翻訳要求へ反映される。用語の適用は実モデルでも確認するが、必ず従うという保証や無条件の文字列置換は行わない。

### 第5段階：メイン翻訳画面と編集

- [ ] 原文入力、生成訳、編集可能な訳文、コピー、取り消しを用意する。
- [ ] ポップアップから同じ翻訳状態をメイン画面へ引き継ぐ。
- [ ] 手動編集の有無と版番号を管理し、再翻訳で変更を黙って失わない動作を用意する。
- [ ] ポップアップでの原文展開、使用中の用語集表示、言語・用語集変更後の明示的な再翻訳を整える。

**完了条件:** 再生成なしで訳文を編集でき、画面移動や遅延応答で編集内容が壊れない。単語クリックによる別訳候補はまだ実装しない。

### 第6段階：初期版の通し検証と配布準備

- [ ] 初回設定→権限許可→接続→選択翻訳→用語集→編集の一連の操作を確認する。
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

第1段階を最初の確認点とする。各段階の詳細手順を作成し、最小限の実装と必要なテストを行い、コミットしてから次へ進む。用語集を含む第6段階までを初期版とし、第3段階の翻訳デモで完成とはしない。
