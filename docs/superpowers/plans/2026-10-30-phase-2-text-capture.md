# Phase 2: Selected-text capture / 第2段階：選択文章の取得

## English

**Goal:** Bring selected text from Chrome and Preview into the existing popup, with clear permission guidance and safe fallbacks. No networking or translation yet.

**Spec:** [Initial release phases](2026-10-29-initial-release-phases.md), Phase 2 and global constraints. Work in the existing checkout on `feature/phase-2-text-capture`, based on merged Phase 1. Use executing-plans and test-driven-development.

**Design:** An Accessibility reader returns only selected text, never the entire field value. Capture records the source app and optional selection bounds. A separate copy transaction snapshots all available clipboard representations, waits for shortcut modifiers to be released, sends a targeted Copy, and accepts only a fresh, stable clipboard change while the source remains active. It restores the snapshot only while the observed clipboard generation is still current and no intervening input/app change occurred. A copy result always needs explicit confirmation, because some applications copy a line or object without a text selection. Known empty selections and secure fields never trigger Copy. Permission denial and failures offer manual text entry/paste. Capture state stays in memory; closing, manual input, sample display, or a newer request invalidates older work.

### Task 1: Capture contracts and request lifecycle

**Files:** `SelectionCapture.swift`, `CaptureModel.swift`, `SelectionCaptureTests.swift`.
**Interfaces:** Source application identity, selected text/bounds, explicit failure cases, direct vs. copy vs. manual origin; an injectable capture environment; observable UI state with request identity.

- [x] Write failing tests for direct capture, missing permission/source, empty/secure selections, copy confirmation, app changes, cancellation, and stale completions.
- [x] Implement the contracts, orchestration, and in-memory state; keep native reads injectable at the OS boundary.
- [x] Run `swift test`. Expected: all tests pass. Commit this slice.

### Task 2: Native Accessibility and clipboard adapters

**Files:** `AccessibilitySelectionReader.swift`, `ClipboardCapture.swift`, `SystemCaptureEnvironment.swift`, adapter tests.
**Interfaces:** Implement Task 1's environment; clipboard snapshot/generation and an input session isolate OS events from deterministic transaction tests.

- [x] Write failing tests for stale clipboard, non-text copy, multi-format restoration, newer-copy preservation, timeout, source/input changes, held modifiers, and cancellation.
- [x] Implement bounded AX reads, secure-field checks, selection range/bounds, source identity checks, permission opening, and targeted Copy with no pointer movement.
- [x] Implement snapshot size limits and generation-checked restoration. Never clear the clipboard before Copy. Fail closed on uncertain state; copy results require user confirmation.
- [x] Run `swift test`. Expected: all tests pass. Commit this slice.

### Task 3: Popup, settings, and shortcut integration

**Files:** Existing popup/delegate/settings/geometry/localization files, `CaptureContentView.swift`, popup and geometry tests.
**Interfaces:** Task 1's state feeds the existing popup; Task 2 supplies the live environment. Keep the existing shortcut storage key and Phase 1 sample tools.

- [x] Write failing tests for captured/error/manual content, cancelled requests on close, mode switching, and selection-based placement with pointer fallback.
- [x] Make the shortcut capture text. Add permission status/actions, a manual paste editor, copy-result confirmation, source labels, and a clear “translation comes later” state in both languages.
- [x] Keep focus, Escape, geometry, and AutoRaise behavior. Add standard Edit actions for manual input.
- [x] Run `swift test` and Debug/Release Xcode builds. Expected: pass. Commit this slice.

### Task 4: Real-app verification and documentation

**Files:** `docs/testing/phase-2.md`, README, phased roadmap.

- [x] Use synthetic non-private fixtures in Chrome and Preview. Do not move the pointer. Record actual selection/bounds and clipboard results; label permission/environment blocks explicitly.
- [x] Record automated and live evidence, pending user checks, and copy limitations in English followed by Japanese. Update the roadmap without claiming unverified acceptance.
- [x] Run final relevant checks and obtain one fresh whole-branch review under executing-plans. Fix important findings with regression tests. Commit and leave the branch ready for review.

### Review focus

- Clipboard updates after the first Copy must survive restoration; clipboard APIs do not provide an atomic compare-and-swap across processes.
- Copy without a selection may return a line or object; copied text must remain unconfirmed until the user accepts it.
- Delayed completion after close, manual input, or another capture must not reopen or overwrite the popup.
- AX permissions, protected text, unresponsive applications, selection coordinates on multiple displays, and focus changes need native evidence beyond injected tests.
- No source text, clipboard content, or personal app data in logs or committed fixtures. No network calls or pointer warping.

## 日本語

**目標:** Chromeとプレビューで選択した文章を既存ポップアップへ取り込み、権限案内と安全な代替操作を提供する。通信・翻訳はまだ実装しない。

**仕様:** [初期版の段階計画](2026-10-29-initial-release-phases.md)の第2段階と全体制約。マージ済み第1段階を基に、既存の作業場所の `feature/phase-2-text-capture` で進める。executing-plansとtest-driven-developmentを使用する。

**設計:** Accessibilityでは選択文章だけを読み、入力欄全体の値を代用しない。取得元アプリと取得可能な選択位置を記録する。コピー処理を分離し、クリップボードの全形式を保存して修飾キーの解放を待ち、対象アプリへコピーを送る。同じアプリが有効な間の新しい安定した変更だけを採用する。観測したクリップボードの世代が変わらず、別の入力・アプリ切り替えもない場合にだけ元へ戻す。選択がなくても行やオブジェクトをコピーするアプリがあるため、コピー結果は必ず利用者の確認を経て採用する。空選択と保護された入力欄ではコピーしない。権限不足や失敗時は手入力・貼り付けを案内する。文章はメモリ内に保持し、閉じる操作、手入力、サンプル表示、新しい要求で古い処理を無効化する。

### タスク1：取得の契約と要求管理

**ファイル:** `SelectionCapture.swift`、`CaptureModel.swift`、`SelectionCaptureTests.swift`。
**接続仕様:** 取得元アプリ、選択文章・位置、明確な失敗理由、直接取得・コピー・手入力の区別、差し替え可能な取得環境、要求IDを持つ画面状態。

- [x] 直接取得、権限・取得元なし、空選択・保護欄、コピー確認、アプリ切り替え、キャンセル、古い完了を検証する失敗テストを作る。
- [x] 契約・取得手順・メモリ内状態を実装し、OSとの境界だけを差し替え可能にする。
- [x] `swift test` で全件成功を確認し、コミットする。

### タスク2：Accessibilityとクリップボードの実装

**ファイル:** `AccessibilitySelectionReader.swift`、`ClipboardCapture.swift`、`SystemCaptureEnvironment.swift`、関連テスト。
**接続仕様:** タスク1の取得環境を実装する。クリップボードのスナップショット・世代と入力監視でOS操作を決定的なテストから分離する。

- [x] 古いクリップボード、非テキスト、複数形式の復元、新しいコピーの保持、タイムアウト、取得元・入力変更、修飾キー、キャンセルの失敗テストを作る。
- [x] 時間制限付きAX読み取り、保護欄判定、選択範囲・位置、取得元確認、権限案内、対象を指定したコピーを実装する。ポインターは動かさない。
- [x] 保存容量の上限と世代確認付き復元を実装する。コピー前にクリップボードを消去しない。不明確な状態は採用せず、コピー結果には利用者確認を求める。
- [x] `swift test` で全件成功を確認し、コミットする。

### タスク3：ポップアップ・設定・ショートカットとの接続

**ファイル:** 既存のポップアップ・デリゲート・設定・配置・言語ファイル、`CaptureContentView.swift`、画面と配置のテスト。
**接続仕様:** タスク1の状態を既存ポップアップへ渡し、タスク2で実際に取得する。ショートカットの保存キーと第1段階のサンプル操作を維持する。

- [x] 取得・エラー・手入力の表示、閉じる際のキャンセル、モード切り替え、選択付近への配置とカーソルへの代替の失敗テストを作る。
- [x] ショートカットで文章を取得する。権限状態・操作、貼り付け入力欄、コピー結果の確認、取得元、翻訳は後続段階である表示を英日で追加する。
- [x] フォーカス、Esc、位置、AutoRaiseの動作を維持し、入力用の標準編集操作を追加する。
- [x] `swift test` とDebug/Releaseビルドの成功を確認し、コミットする。

### タスク4：実アプリ確認と文書

**ファイル:** `docs/testing/phase-2.md`、README、段階計画。

- [x] 非個人情報のテスト文章をChromeとプレビューで使用する。ポインターは動かさない。選択・位置・クリップボードの実際の結果と、権限・環境の制約を記録する。
- [x] 自動・実機検証、利用者確認の残り、コピーの制限を英語→日本語で記載する。未確認を完了扱いにせず計画を更新する。
- [x] 最終確認とexecuting-plansに従う独立したブランチ全体レビューを行う。重要な指摘は回帰テストで修正する。コミットしてレビュー可能な状態にする。

### レビュー重点項目

- 最初のコピー後の新しいクリップボード更新を復元で壊さない。クリップボードAPIにはプロセス間で原子的に比較・更新する機能がない。
- 選択なしのコピーが行・オブジェクトを返す場合があり、コピー文章は利用者の確認まで未確定とする。
- 閉じる、手入力、新しい取得の後に古い処理が完了しても、再表示・上書きしない。
- AX権限、保護欄、応答しないアプリ、複数画面での座標、フォーカス変更は差し替えテスト以外の実機証拠も必要。
- 原文・クリップボード・個人アプリ情報をログや公開テストデータへ含めない。通信やポインター移動はしない。
