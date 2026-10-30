# Phase 5: Shared translation editor

## English

**Goal:** Implement the roadmap's main translation window and editing workflow, using DeepL's basic text-translation operations as a reference.

**Design:** Extend the existing `TranslationModel` as the single owner of source draft, immutable generated output, edited output, request snapshots, revisions, and undo. A reusable native main window and the popup observe the same instance. Opening/closing the editor never starts a request or clears text. No additional dependencies or translation service.

**Decisions:** A separate editor copy would need synchronization and could lose edits; a shared model fits the existing roadmap. Keep explicit Translate/Retranslate instead of automatic sending. Support automatic source instructions and English/Japanese, as already supported by the client; do not invent detected-language metadata. Swapping requires an explicit source language and current completed output, moves the edited result into the source, and waits for Translate. Alternatives, history, OCR, document translation, speech, and tone controls remain outside this phase.

**Reference:** [DeepL text translation and glossary controls](https://support.deepl.com/hc/en-us/articles/9851524013468-Get-started-DeepL-for-Microsoft-Word). This is an interaction reference, not a DeepL service integration or feature-parity claim.

### Invariants and review focus

- Generated output remains distinct from manual edits. Copy uses the displayed edited result only when generation completed and the result is nonempty.
- Source edits cancel an active request; late tokens/completion cannot overwrite a newer revision. Changed source/direction/glossary is labeled and only explicit translation applies it.
- Retranslating edited output, clearing a draft, swapping, and replacing a draft with captured text require an in-app confirmation. Editing invalidates pending confirmation. Failure/unconfirmed capture and sample/manual views preserve the editor draft.
- Undo/redo applies within the current document; replacing/clearing/retranslating resets its stack so old text cannot enter a new document. Windows share the same document and undo history.
- Popup-to-editor navigation preserves request IDs and text. Closing the popup cancels only when no editor is visible; editor close retains the draft. Exit confirms when a draft/manual edits would be lost.
- Keep input limits, glossary request snapshots, confirmation before copy-fallback transmission, and incomplete-output labels. Do not persist source/output or read the clipboard without an explicit paste/copy action.

### Task 1: Shared editing and request lifecycle

**Files:** `TranslationModel.swift`, `TranslationModelTests.swift`, new `TranslationEditorTests.swift`.
**Interfaces:** `sourceText`, `resultText`, `hasEdits`, `sourceChanged`, `directionChanged`, `revision`, `documentID`, `undoManager`; `editSource(_:)`, `editTranslation(_:)`, `translateSource()`, `clearDocument()`, `swapLanguages()`, `confirmPendingAction()`, `keepEditing()`; existing start/retranslate/cancel/bind remain the request entry points.

- [x] Write and observe failing tests for edit/generated separation, real undo/redo, retranslation/new-capture confirmation, stale confirmation invalidation, source edits during streaming, empty/oversized input, clear, swap, and capture-confirmation boundaries.
- [x] Extend the model, keeping stream guards and one request snapshot. Use Foundation UndoManager; bound history and reset it on document changes.
- [x] Run `nice -n 10 swift test --jobs 2 --skip PopupControllerTests`; expect all background tests to pass. Commit.

### Task 2: Main window and popup

**Files:** new `TranslationEditorView.swift`, native text editor, `KotoFloatDelegate.swift`, `PopupController.swift`, `CaptureContentView.swift`, `TranslationContentView.swift`, localization resources.
**Interfaces:** The delegate retains one editor window using the popup's `TranslationModel`. Native text controls send changes to model edit methods and use its undo manager. Shared status/glossary/actions/confirmation views consume the same model.

- [x] Build a resizable two-pane editor with source input, paste through normal native editing, character count, language selection/swap, clear, explicit translation/stop, editable completed result, generated-original disclosure, copy and undo/redo.
- [x] Add menu/popup navigation, preserve draft on close, coordinate popup cancellation, and confirm exit for drafts. Expand/collapse popup source; show result/source/settings mismatch and request glossary snapshot.
- [x] Localize all visible controls in English/Japanese. Run background tests and the required separate Debug build; expect pass without launching the app. Commit.

### Task 3: Verification and documentation

**Files:** README, roadmap, `docs/testing/phase-5.md`, relevant regression tests.

- [x] Exercise actual URLSession with the existing loopback fixture, editor edits, copying to a named pasteboard, and retranslation. Run localization consistency checks and `git diff --check`.
- [x] Independently review the whole phase against the invariants, fix material findings with regression tests, and record evidence and limitations.
- [x] Update aligned English/Japanese documentation and checklist. Commit and leave `feature/phase-5-editor` unmerged.

**Verification boundary:** Only low-priority, two-job background commands. No app launch, focus/input synthesis, or native-window suite. Actual editor layout, keyboard/VoiceOver, focus/AutoRaise, native undo/menu interaction, and real-model quality remain explicit desktop acceptance checks.

## 日本語

**目標:** ロードマップの翻訳メイン画面と編集を実装し、DeepLの基本的な文章翻訳操作を参考にする。

**設計:** 既存の`TranslationModel`が原文の下書き、生成訳、編集訳、要求時の情報、版番号、Undoを一元管理する。再利用するネイティブメイン画面とポップアップが同じインスタンスを参照し、画面の開閉で送信や消去を行わない。依存や翻訳サービスを追加しない。

**判断:** エディタ専用コピーは同期と編集消失の問題を増やすため、既存計画に沿って状態を共有する。入力だけで送信せず翻訳／再翻訳を明示する。翻訳元の自動指示と英日を維持し、未取得の判定言語を表示しない。入れ替えは翻訳元の明示選択と現在の完成訳が必要で、編集訳を原文に移して翻訳操作を待つ。代替訳、履歴、OCR、文書翻訳、音声、文体指定は今回の範囲外とする。

**参考:** [DeepLの文章翻訳と言語・用語集操作](https://support.deepl.com/hc/en-us/articles/9851524013468-Get-started-DeepL-for-Microsoft-Word)。操作の参考であり、DeepL接続や同等機能の保証ではない。

### 保持する条件とレビュー重点

- 生成訳と手編集を区別する。コピーは生成完了かつ空でない表示中の編集訳を対象にする。
- 原文編集は実行中の要求を止め、遅延応答は新しい版を上書きしない。原文・方向・用語集の変更を表示し、明示的な翻訳だけで反映する。
- 編集訳の再翻訳、下書きのクリア、入れ替え、新取得文での置換はアプリ内で確認する。確認待ち中の編集は確認を無効化する。取得失敗・未確認コピー・サンプルや手入力画面は既存下書きを保持する。
- Undo/Redoは現在の文書内に限定し、置換・クリア・再翻訳で履歴を消す。両画面は同じ文章と履歴を共有する。
- エディタへの移動で要求IDや文章を変えない。ポップアップを閉じてもエディタ表示中なら翻訳を継続し、エディタを閉じても下書きを保持する。未送信原文や編集訳がある状態での終了は確認する。
- 文字量制限、要求時の用語集、コピー取得文の送信前確認、不完全な訳文表示を維持する。文章を保存せず、明示的な貼り付け／コピー以外でクリップボードを読まない。

### 第1作業：共有編集状態

`TranslationModel.swift`と既存・新規の編集テストを更新する。生成訳と編集訳、Undo/Redo、再翻訳・取得置換の確認、古い確認の無効化、生成中の原文編集、空／過大入力、クリア、入れ替え、コピー確認を先に失敗させる。Foundation UndoManagerと既存の要求ガードを使い、文書変更で履歴をリセットする。指定バックグラウンドテストを通してコミットする。

### 第2作業：画面

新規エディタ画面とネイティブ文章入力、delegate、popup、共有操作と英日リソースを追加・更新する。原文と訳文の2ペイン、標準貼り付け、文字数、言語選択と入れ替え、クリア、翻訳／停止、完成訳編集、生成訳の展開表示、コピー、Undo/Redoを備える。メニュー／ポップアップから移動でき、終了時の下書き確認と画面ごとのキャンセルを整える。ポップアップ原文の展開と変更通知を追加する。背景テストと別保存先のDebugビルドを通してコミットする。

### 第3作業：検証と記録

既存ループバックAPIと実URLSession、編集、名前付きクリップボードへのコピー、再翻訳を検証する。翻訳キーと差分も確認する。独立レビューで重要な指摘を回帰テスト付きで修正し、README・計画・検証記録を英日で更新してコミットする。`feature/phase-5-editor`はマージしない。

**検証範囲:** 低優先度・2ジョブの背景コマンドのみ。起動、フォーカス変更、入力の送出、ネイティブウィンドウテストは行わない。実際の配置、キーボード／VoiceOver、フォーカス／AutoRaise、ネイティブUndo／メニュー、実モデルの品質は実機確認として残す。
