# Local Translation History Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement each task in this session. The user selected local storage and authorized implementation on main. Preserve existing uncommitted work.

**Goal:** Save successful translations locally and provide searchable history, reopening, and deletion in the Translator.

**Architecture:** A native SQLite database at `~/Library/Application Support/KotoFloat/History/history.sqlite` owns persistence on an actor. An observable store serializes mutations and provides paged summaries. The shared translation model records completed results and subsequent edits; a compact native history popover in the Translator reopens entries without sending requests.

**Tech Stack:** Swift 6, macOS 15+, SQLite3, Observation, SwiftUI/AppKit. No new third-party dependency.

**Spec:** The design and acceptance requirements below implement the user's selected local-storage proposal.

## Design and Global Constraints

- Save source, displayed translation, requested languages, creation time, and update time. Save no tokens or server credentials.
- Group automatic source edits, explicit retranslation, and alternative-word edits within the same draft. A new capture or clearing the document starts a new history entry.
- Failed/cancelled/partial translations do not replace a saved completed result.
- Reopening is local-only. Protect active streams, drafts, and manual edits using the existing confirmation path. A reopened entry is a saved baseline; new edits remain undoable.
- Deleted entries stay deleted when the current draft later updates. Deletion and writes must be ordered, and updating a missing entry must not recreate it.
- Search uses bound parameters and paged summaries (50 per page); opening loads the complete entry. No silent retention limit or automatic deletion.
- Preserve unreadable or unsupported database files, report failures, and keep translation usable. Database access stays off the main actor. Restrict new history-directory/file permissions to the current user.
- Keep popup layout and app lifecycle unchanged. Use the existing low-priority two-job background verification and separate hidden native tests. Do not launch/restart the app.
- Repository prose is English first, then Japanese; work stays on main with existing changes uncommitted.

## Review Focus

- Restart persistence and Unicode/newline round trips: database tests reopen the same temporary file.
- Search punctuation/SQL-like input: literal matching tests prevent wildcard/injection mistakes.
- Deletion racing queued saves: store/model tests verify update-only writes cannot resurrect deleted items.
- Unsupported/corrupt storage: tests compare original bytes after failed access.
- Loading history during a pending automatic translation: model tests verify confirmation, cancellation, and no server request.

## Tasks

### 1. SQLite persistence and observable history store

**Files:** Create `TranslationHistory.swift`, `TranslationHistoryDatabase.swift`, `TranslationHistoryStore.swift`, and `TranslationHistoryTests.swift` under the existing source/test directories.

**Interfaces:** `TranslationHistoryEntry` and `TranslationHistorySummary` are Sendable values. `TranslationHistoryDatabase` provides save(create:), search(query:offset:limit:), entry(id:), delete(id:), and clear(). `TranslationHistoryStore` provides serialized save/delete/clear, flush(), search(), loadMore(), and entry(id:), with observable summaries, loading/error state, and revision.

- [x] Write and run failing persistence tests for round trips, replacement, literal search, pagination, update-only deletion, and invalid storage.
- [x] Implement native SQLite bound statements, schema/version checks, atomic mutations, and ordered observable operations.
- [x] Run focused tests; verify original corrupt/unsupported bytes remain intact.

### 2. Shared document integration

**Files:** Modify `TranslationModel.swift`, `KotoFloatDelegate.swift`; create `TranslationHistoryModelTests.swift`.

- [x] Write failing tests for successful saves, draft grouping, incomplete-result protection, edited results, local restore, confirmation, and deleted-entry updates.
- [x] Inject the optional history store into the shared model; provide a real store at app startup. Preserve history identity across retranslation while new captures/clear reset it.
- [x] Extend PendingAction with local restore, protect current work, and never trigger automatic translation merely by reopening a record.
- [x] Flush pending history mutations before actual application termination.
- [x] Run focused model tests and the background suite.

### 3. Translator history UI and delivery

**Files:** Create `TranslationHistoryView.swift`; modify `TranslationEditorView.swift`, localized strings, README; add a hidden native acceptance test.

- [x] Add a labeled History toolbar button and a compact search/list popover with language/time/snippets, Open, individual delete, Load more, retry, and confirmed Delete all.
- [x] Show storage failures without removing current drafts. Keep source/result text areas and popup layout unchanged.
- [x] Verify hidden native list/restore behavior without changing desktop focus.
- [x] Run background tests, relevant hidden native tests, Debug build, strict signature verification, and diff checks. Record remaining live acceptance limits; leave changes uncommitted.

## Execution record

All three tasks were completed on main, preserving prior uncommitted work. Background verification passed 202 tests in 30 suites; the four relevant hidden native tests passed. The final UI-only refinement also passed its focused native history check. Debug build, strict signature verification, embedded English/Japanese history strings, localization parity, and diff checks passed.

Ruling: a saved history item opens as a new baseline with no old Undo stack; continuous edits/retranslation share its identity until a new capture or clear. This avoids arbitrary time-based grouping while preserving the user's saved wording.

Final independent review found failed saves being lost on actual Quit and an uncancelled asynchronous open after History dismissal. Both were corrected and re-reviewed. Failed entries remain retryable and block an unacknowledged Quit; opening tasks are canceled on dismissal. The real app was not launched/restarted. Physical popover/VoiceOver and the native failure-Quit dialog remain live checks.

## 日本語

利用者が選択したMac内保存を実装し、作業はmainで既存の未コミット変更を保持したまま進める。保存先は`~/Library/Application Support/KotoFloat/History/history.sqlite`。Swift 6・macOS 15以降のSQLite3、Observation、SwiftUI／AppKitを使い、外部依存は増やさない。

保存・検索はactorで行い、原文・表示中の訳文・言語・作成日時・更新日時を保持する。自動翻訳の連続入力、再翻訳、単語候補からの編集は同じ下書きの履歴を更新する。新しい取得・文書の消去で別の履歴にする。失敗・取消・未完成の訳文は完成済みの履歴を置き換えない。履歴を開く操作では通信しない。進行中の翻訳・下書き・編集済み訳文は既存の確認操作で保護する。

検索結果は50件ずつ概要を読み、選んだ履歴だけ全文を取得する。削除と保存の順序を維持し、削除後の更新で履歴を復活させない。自動削除や保持件数の制限は設けない。認証情報は保存しない。保存先の作成時は利用者だけがアクセスできる権限とし、不正・未対応形式の既存ファイルを作り直さず、失敗を画面へ通知する。翻訳処理は維持する。

手順は、①一時ファイルによる往復・検索・ページ分け・削除・破損保護のテストとSQLite保存層、②完成時・編集時の保存と同一下書きの管理・通信しない再表示・破棄確認・終了時の保存待ち、③Translatorの履歴ボタンと検索・表示・個別削除・追加読込・再試行・確認付き全削除を備える画面の順とする。

通常テスト、非表示の標準ウィンドウテスト、独立したDebugビルド、厳密な署名検査、差分検査を行う。原文・訳文欄とポップアップの配置は維持し、アプリの起動・再起動やフォーカス変更は行わない。実際のポインター・VoiceOverなどの未確認範囲を報告する。

3つの作業をmainで完了し、以前からの未コミット変更を保持した。通常テストは30スイート・202件、関連する非表示ネイティブテストは4件が成功した。最後の表示調整後も対象の履歴テストが成功した。Debugビルド、厳密な署名検査、アプリ内の英語・日本語の履歴文言、文言キーの一致、差分検査も成功した。

判断として、履歴を開いた文は過去のUndoを引き継がない新しい基準とし、新しい取得・消去まで同じ履歴を更新する。時間による恣意的な集約を避け、保存済みの文を維持する。

独立した最終レビューで、保存失敗後の終了による消失と、履歴を閉じた後の非同期の再表示を検出した。両方を修正して再レビューし、未保存分の再試行と終了確認、読み込み中の「開く」の取り消しを追加した。実アプリは起動・再起動していない。実際の候補画面・VoiceOver・保存失敗時の終了ダイアログは実画面での確認として残る。
