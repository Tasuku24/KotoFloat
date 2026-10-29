# Phase 4: Glossaries Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## English

**Goal:** Manage local glossaries, preview and import/export CSV, and pass relevant terms to translation with review warnings.

**Architecture:** Value types describe a versioned glossary library. One observable store owns validated, atomic persistence and active selection. Pure CSV and matching functions feed a dedicated glossary window and immutable translation request snapshots. Existing translation cancellation and capture confirmation remain authoritative.

**Tech Stack:** Swift 6, Foundation Codable/JSON, AppKit, SwiftUI; no new dependencies. A versioned JSON document replaces the roadmap's proposed SwiftData storage: bounded libraries can be validated and replaced as one transaction, with explicit rejection of unknown versions and concurrent edits.

**Spec:** [Initial release roadmap](2026-10-29-initial-release-phases.md), Phase 4.

### Global constraints and design decisions

- macOS 15+, English then Japanese prose, English commits, `feature/phase-4-glossaries` in the existing checkout.
- Background tests: `nice -n 10 swift test --jobs 2 --skip PopupControllerTests`. Build: `nice -n 10 xcodebuild -project KotoFloat.xcodeproj -scheme KotoFloat -configuration Debug -derivedDataPath .build/validation -jobs 2 build`. Never launch apps or synthesize input.
- Store `Application Support/KotoFloat/glossaries.json`, schema version 1. Missing file means an empty library; unreadable, invalid, future-version, or externally changed files must not be overwritten. Failed saves must leave in-memory and disk state unchanged. Tests use temporary directories only.
- One active glossary, or none. Entries include source/target language (`en`/`ja`, distinct), source term, preferred translation, context, case sensitivity, enabled flag, and stable ID. Selection and edits affect the next request; retranslation is explicit.
- Limits: 100 glossaries, 10,000 total entries, 16 MiB file/CSV, names 120 characters, source terms 256, preferred translations 1,024, context 2,048. At most 100 matching entries and 64 KiB reference JSON per request; exceedance blocks that request with an actionable error.
- CSV UTF-8 (optional BOM), exact columns `source,target,source_language,target_language,context,case_sensitive,enabled`; booleans `true`/`false`. Support CRLF/LF/CR records, quotes, commas, and embedded newlines. Invalid rows block the whole import. Preview duplicate policies: skip, replace, keep both. Replacement matches source/language/case key; last imported duplicate wins. Exact duplicate additions are suppressed.
- Latin terms use word boundaries, Japanese terms allow substring matching; case handling is explicit. Automatic source uses matching text and target direction, without claiming source-language detection. Conflicting preferred translations for the same matched occurrence are displayed and excluded from reference data. Missing preferred terms are advisory after completion, never string replacements.
- Only relevant enabled entries enter requests. Encode reference data separately from source text and instruct the model to treat it as data. No history or glossary logging; fixed trial translations remain glossary-free.

### Review focus

- Failed/invalid imports and future schemas must not erase existing data.
- Two app instances or edits after preview must not silently overwrite newer data.
- Case-insensitive duplicates, Japanese/Latin boundaries, and conflicting entries must not silently choose an arbitrary translation.
- Cancellation, glossary switches, and edits during streaming must preserve the request's original snapshot.
- CSV preview and editors must retain drafts after save errors and require confirmation for deletion.

### Task 1: Library and persistence

**Files:** `Glossary.swift`, `GlossaryStore.swift`, `GlossaryStoreTests.swift`; add Codable to `TranslationLanguage`.

**Interfaces:** `GlossaryEntry`, `Glossary`, `GlossaryLibrary`; `GlossaryStore(url:)`, `reload()`, `create(name:) -> UUID`, `rename(id:name:)`, `delete(id:)`, `select(_:)`, `saveEntry(_:in:)`, `deleteEntry(id:in:)`, `replaceEntries(_:in:expectedRevision:)`. Mutations throw `GlossaryFailure`; successful saves increment `revision`.

- [ ] Add tests for CRUD/selection across reload, normalization/validation, duplicates, failed writes, corrupt/future versions, and stale concurrent stores.
- [ ] Run the background suite; expected new contracts fail before implementation.
- [ ] Implement bounded validation and atomic storage with file locking and optimistic disk comparison.
- [ ] Run the background suite; expected pass. Commit the slice.

### Task 2: CSV preview and atomic import

**Files:** `GlossaryCSV.swift`, `GlossaryCSVTests.swift`.

**Interfaces:** `GlossaryCSV.preview(data:existing:policy:) -> GlossaryImportPreview`, `export(_:) -> Data`; preview exposes rows, issues, duplicate count, and resulting entries. Apply through the store with the preview revision.

- [ ] Test quoted/multiline/BOM data, malformed records and invalid fields, duplicates under each policy, round trip, invalid imports, and stale previews.
- [ ] Run background tests; expected new contracts fail.
- [ ] Implement a bounded CSV state machine and all-or-none preview/application.
- [ ] Run background tests; expected pass. Commit the slice.

### Task 3: Matching and translation integration

**Files:** `GlossaryMatcher.swift`, `TranslationClient.swift`, `TranslationModel.swift`, glossary matching/request/state tests.

**Interfaces:** `GlossaryMatcher.context(for:source:target:glossary:) -> GlossaryContext`, `GlossaryContext.missingTerms(in:)`; `TranslationInput.glossary` defaults empty. Inject optional `GlossaryStore` into `TranslationModel` and snapshot at start.

- [ ] Test word boundaries, punctuation, Japanese, case/direction/disabled filtering, conflict exclusion, request bounds, missing terms, serialized relevant-only reference data, and edits/retranslation/cancellation.
- [ ] Run background tests; expected new contracts fail.
- [ ] Implement matching, request snapshots, structured reference data and review state. Preserve existing requests without a glossary.
- [ ] Run background tests; expected pass. Commit the slice.

### Task 4: Management UI, verification, and documentation

**Files:** `GlossaryView.swift`, `GlossaryEntryEditor.swift`, `GlossaryImportView.swift`, delegate/menu integration, `TranslationContentView.swift`, English/Japanese resources, README, roadmap, `docs/testing/phase-4.md`.

- [ ] Add a reusable glossary window: create/rename/delete, entry editor, search, active selection, import preview/policy and export. Use native file panels only on explicit clicks, with deletion confirmation and visible save/load errors.
- [ ] Show active selection, request snapshot and review warnings in the popup. Changes require explicit retranslation.
- [ ] Run background tests, the fixture runner, a separate Debug build, and localization consistency checks; expected pass. Do not claim actual UI or real-model acceptance.
- [ ] Update aligned English/Japanese documentation, perform one independent whole-branch review, fix material findings, and commit. Leave the branch unmerged.

## 日本語

**目標:** ローカル用語集の管理、CSVの確認付き取り込み・書き出し、関連用語の翻訳への反映と要確認表示を実装する。

**構成:** バージョン付き用語集を値型で表し、共有ストアが検証・原子的な保存・有効な用語集の選択を所有する。CSVと照合処理は画面から分離し、専用ウィンドウと要求ごとの固定スナップショットから利用する。既存の翻訳キャンセルと取得文の確認条件は維持する。

**技術:** Swift 6、Foundation Codable/JSON、AppKit、SwiftUI。依存追加なし。ロードマップで候補としたSwiftDataに代え、上限付きの用語集を一括検証・置換でき、未知バージョンと同時更新を明示的に拒否できるJSONを使う。

**仕様:** [初期版の開発計画](2026-10-29-initial-release-phases.md)の第4段階。

### 制約と設計判断

- macOS 15以降。説明文は英語→日本語、コミットは英語。既存フォルダの`feature/phase-4-glossaries`で開発する。
- テストとビルドは上記の低優先度・2ジョブ・ウィンドウテスト除外・`.build/validation`保存のコマンドを使う。アプリ起動や入力の送出をしない。
- 保存先は`Application Support/KotoFloat/glossaries.json`、形式バージョンは1。ファイル不在だけを空と扱い、読めない・不正・将来版・外部更新済みのファイルを上書きしない。保存失敗時はメモリとディスクを維持する。テストは一時フォルダを使う。
- 有効な用語集は1つまたはなし。項目は原語・訳語・異なる英日言語方向・文脈・大文字小文字の区別・有効状態・固定IDを持つ。変更は次の要求に反映し、再翻訳は明示的な操作とする。
- 上限は用語集100、全項目10,000、ファイル／CSV 16 MiB、名前120文字、原語256文字、訳語1,024文字、文脈2,048文字。要求は関連項目100件・参照JSON 64 KiBまでとし、超過時は説明して送信しない。
- CSVはUTF-8（BOM可）、上記7列、真偽値は`true`／`false`。CRLF・LF・CR、引用符、カンマ、フィールド内改行に対応する。不正行があれば一切取り込まない。重複はスキップ・置換・両方保持から選ぶ。原語・言語方向・大文字小文字設定で重複を判定し、置換は最後の行を採用する。完全一致の追加は抑止する。
- 欧文は単語境界、日本語は部分文字列を照合する。自動言語では原文との一致と翻訳先を使い、言語判定済みとは扱わない。同じ出現箇所に異なる訳語があれば表示し、参照データから除く。完成訳に指定訳語が見当たらない場合は注意表示だけを行い、文字列置換しない。
- 関連する有効項目だけを原文と分けた参照データとして送信する。履歴・用語集ログは保存しない。固定文の試し翻訳には用語集を付けない。

### レビューの重点

不正取り込み・保存失敗・未知形式による消失、別インスタンスやプレビュー後の変更の上書き、大文字小文字・日英境界・訳語競合、ストリーム途中の切り替えやキャンセルによるスナップショットの破壊、エラー時の下書き維持と削除確認を検証する。

### 第1作業：用語集と保存

`Glossary.swift`と`GlossaryStore.swift`に値型とストアを追加する。登録・編集・削除・選択・再起動復元、正規化と検証、重複、書き込み失敗、破損・将来版、同時更新のテストを先に実行して失敗を確認する。ファイルロックと外部変更検出を備えた原子的な保存を実装し、バックグラウンドテスト成功後にコミットする。

### 第2作業：CSV

`GlossaryCSV.swift`にプレビューと書き出しを実装する。引用符・改行・BOM、不正形式・値、各重複方針、往復変換、不正取り込み、古いプレビューのテストを先に失敗させる。検証済みの全行だけをストアの版番号付きで反映し、テスト成功後にコミットする。

### 第3作業：照合と翻訳

`GlossaryMatcher.swift`と既存のクライアント・翻訳状態へ接続する。境界・句読点・日本語・大文字小文字・方向・無効項目、競合、上限、指定訳語欠落、関連用語だけの送信、編集・再翻訳・キャンセルを先にテストする。要求開始時に内容を固定し、用語集なしの動作を維持する。成功後にコミットする。

### 第4作業：画面と検証

専用用語集ウィンドウ、項目編集、検索、有効選択、CSVプレビューと重複方針、書き出しを追加する。ファイルパネルは利用者の明示操作だけで開く。削除確認と保存・読み込みエラーを表示する。ポップアップには選択中の用語集・要求時の内容・要確認事項を表示する。バックグラウンドテスト、固定API検証、別保存先のDebugビルド、英日キー一致を確認する。README・計画・検証記録を英日で更新し、独立レビューで重要な指摘を直してコミットする。マージはしない。実画面と実モデルでの適用確認は未確認として残す。
