# Local translation history

## English

The user selected local Mac storage on 2026-11-05. The application supplies the shared translation model with a history store; tests inject isolated temporary database paths. The real user history file is not touched during verification.

Completed generations and later translation edits save source, displayed translation, requested languages, creation time, and update time at `~/Library/Application Support/KotoFloat/History/history.sqlite`. SQLite runs on an actor with bound statements, version/application checks, private new-file permissions, and ordered writes. Incomplete/failed output never replaces completed history. Unsupported/corrupt files are preserved. Failed saves remain in memory for Retry and are surfaced in the Translator; actual Quit waits for writes and requires an explicit choice if unsaved records remain.

Automatic translation, retranslation, and edits within a draft share one history identity. A new capture or clearing the document starts another. Update-only writes cannot recreate a deleted entry. Search returns 50 summaries per page, with complete text loaded only when opening a result. Opening is local-only, preserves exact text/line breaks, and uses the existing discard confirmation for drafts, manual edits, and active streams. Restoring establishes the saved wording as the new baseline without restoring the old Undo stack or triggering automatic translation. Closing History cancels a pending open task.

### Verification

- `nice -n 10 swift test --jobs 2 --skip PopupControllerTests`: 202 tests in 30 suites passed.
- Database tests reopen the same file, round-trip Unicode/blank lines, search literal punctuation and translation text, paginate, update/delete/clear, preserve invalid/future-version files, serialize saves/deletion, retain failed writes, and retry after storage becomes available.
- Model tests cover same-draft grouping, edited wording and Undo, new captures, incomplete-stream protection, local reopening and confirmation, cancellation of pending automatic translation, and updates after deletion.
- Four separately run hidden native tests passed: history restoration into both real text editors without requests/resizing, Command-Return and marked input, paired review highlights, and long-review viewport stability. The history content was rendered to an untracked preview and inspected without showing a window.
- Fresh source review identified two material issues: failed-save loss on actual Quit and a reopen after History dismissal. Both were fixed and re-reviewed. The store retry test also verifies the unsaved-entry signal used by the termination flow.

Run the native history acceptance separately:

```sh
nice -n 10 swift test --jobs 2 --filter PopupControllerTests/savedHistoryReopensInNativeEditorsWithoutSendingOrResizing
```

The application was not restarted. Physical pointer/keyboard use of the popover, VoiceOver, and the actual native save-failure Quit dialog remain live acceptance checks. The tests establish local persistence and hosted editor behavior, not those desktop interactions. No model-quality claim or new real-server request is part of this history verification.

## 日本語

利用者は2026年11月5日にMac内保存を選択した。アプリは共有翻訳モデルに履歴ストアを渡し、テストでは一時フォルダのデータベースを使う。検証で実際の利用者の履歴ファイルは操作しない。

完成した翻訳とその後の訳文編集について、原文・表示中の訳文・要求時の言語・作成日時・更新日時を`~/Library/Application Support/KotoFloat/History/history.sqlite`に保存する。SQLiteはactorで実行し、パラメータを渡すSQL、形式とアプリ識別の確認、新規ファイルの利用者専用権限、保存順序の管理を使う。未完成・失敗した結果で完成済み履歴を上書きしない。未対応形式・破損ファイルを保持する。保存失敗時は再試行用に内容をメモリへ残し、Translatorに通知する。実際のアプリ終了は保存を待ち、未保存が残る場合は明示的な選択を必要とする。

同じ下書きの自動翻訳・再翻訳・編集は1件の履歴を更新する。新しい取得や文書の消去では別の履歴にする。既存項目の更新で削除済み履歴を復活させない。検索では50件ずつ概要を読み、開く項目だけ全文を取得する。再表示は通信せず、本文・改行を正確に維持し、下書き・編集訳・進行中の翻訳は既存の破棄確認で保護する。保存済みの文を新しい基準とし、過去のUndo履歴は復元せず、自動翻訳も開始しない。履歴画面を閉じると読み込み中の「開く」を取り消す。

### 検証

- 指定の通常テストで30スイート・202件が成功した。
- 保存層では同じファイルの再読込、Unicode・空行の保持、記号を含む検索・訳文検索、ページ分け、更新・削除・全削除、不正・未知形式の保護、保存と削除の順序、失敗した保存の保持、保存先復旧後の再試行を確認した。
- モデルでは下書き内の集約、編集とUndo、新しい取得、未完成出力の保護、通信しない再表示と確認、自動翻訳待ちの取消、削除後の更新を確認した。
- 別途実行した非表示の標準ウィンドウテスト4件が成功した。履歴の左右エディタへの通信・サイズ変更なしの復元、Command-Returnと変換中の入力、対応箇所のハイライト、長い対応範囲での表示位置の維持を確認した。履歴画面の内容は未追跡の画像へ描画し、ウィンドウを表示せずに確認した。
- 独立したソースレビューで、保存失敗後の終了時の消失と、履歴を閉じた後の遅れた再表示の2点を検出し、修正後に再レビューした。再試行テストでは、終了処理が使う未保存フラグも確認する。

ネイティブ履歴テストは上記コマンドで別途実行する。アプリは再起動していない。実際のポインター・キー操作での候補画面、VoiceOver、保存失敗時の標準終了ダイアログは実画面での確認として残る。この検証はローカル保存と内部エディタの連携を確認するものであり、デスクトップ操作の確認やモデル品質の評価ではない。新たな実サーバー通信は行っていない。
