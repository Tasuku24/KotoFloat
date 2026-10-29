# Phase 4 verification / 第4段階の検証

## English

### Implemented scope

Local glossary creation, renaming, deletion, search, entry editing, active selection/None, CSV preview/import/export, relevant-term matching, and translation review warnings are implemented. The manager is a separate resizable window opened from the menu bar or popup; Settings retains its five tabs. Each entry stores source/preferred translation, English/Japanese direction, context, case sensitivity, and enabled state.

The library uses a version-1 JSON document in `~/Library/Application Support/KotoFloat/glossaries.json`. Foundation Codable and atomic file replacement were chosen instead of the roadmap's proposed SwiftData: this bounded library needs a single validated transaction, with explicit unknown-version and concurrent-write protection. Future versions must add a deliberate migration; version 1 does not guess how to read newer data. Missing files initialize an empty library. Invalid/unreadable files block saving and translation until resolved and reloaded. Saves publish in-memory changes only after disk success; a file lock and comparison with the loaded data prevent competing app instances from silently overwriting one another.

CSV uses the seven documented UTF-8 columns. Preview exposes records, duplicate handling, and validation failures; one invalid record blocks the entire import. Imports use the preview's revision and commit once. Replacement preserves the first existing ID and uses the last incoming duplicate; Keep both suppresses exact duplicates. CSV exports literal values, including disabled entries; it is not a full-library backup and does not sanitize spreadsheet formulas. JSON copies preserve all glossaries, IDs, and active selection.

Translation snapshots the selected glossary at request start. Matching runs off the main actor, honors case/direction/enabled state, uses boundaries for Latin terms and substring matching for Japanese, and includes only relevant entries. Automatic source uses target direction and literal matching, not language detection. Same-occurrence entries with different preferred translations are reported and excluded. Reference JSON is a separate user message, with system instructions treating it as data. The final user message remains the source. Trial translation remains glossary-free. Review checks completed output for preferred terms; they are advisory, with no unconditional replacement or guarantee of model adherence.

### Background evidence (2026-10-30)

- New storage, CSV, matching/request, and state contracts were exercised before implementation; their initial missing-feature failures and subsequent passing suites were observed.
- `python3 scripts/test_with_mock_server.py`: **103 tests passed**, including the existing background suites. The 15 native-window tests remain excluded.
- The new loopback scenario validates the exact synthetic reference JSON, rejects missing/extra terms, and returns a clearly labeled fixed response. The integration test reloads a saved library, confirms manual source text, uses the actual URLSession client, and checks completion and review state. It initially failed because the old fixture rejected the new three-message request, then passed after the fixture update. This proves serialization and transport, not real translation or model adherence.
- Storage tests cover create/edit/delete/selection across reopen, validation, duplicate suppression, corrupt/future files, failed saves, concurrent stores, and stale preview revisions. CSV tests cover BOM, quoted commas/quotes/CRLF, malformed data, invalid languages/flags, in-file and existing duplicates, and all-or-none application.
- Matching/state tests cover partial-word rejection, punctuation, case-sensitive distinctions, Japanese text, direction/disabled filtering, conflict exclusion, reference limits, relevant-only request contents, missing preferred terms, and edits/retranslation while a request is active. Existing cancellation, delayed-response, clipboard-confirmation, and duplicate-request tests pass.
- The required Debug app build in `.build/validation` succeeded. No app was launched/restarted, no input was synthesized, and no focus was changed.

### Limits and pending acceptance

Storage/CSV is bounded to 16 MiB, 100 glossaries and 10,000 total entries. Names/source terms/preferred translations/context are limited to 120/256/1,024/2,048 characters. Requests permit at most 100 matching entries and 64 KiB of reference JSON; over-limit requests fail explicitly instead of silently dropping references. Data and source text are not logged.

- [ ] Actual English/Japanese manager layout, keyboard/VoiceOver access, entry editing, search, deletion confirmation, and error recovery.
- [ ] Native file panels, CSV import/export to user-selected locations, spreadsheet interoperability, and backup/restore in the signed app.
- [ ] Popup selection, long warning lists, resize/focus/Escape/AutoRaise behavior on the user's desktop.
- [ ] Real LLM adherence, context-dependent terms, conflicting terminology, and false positives/negatives in advisory missing-term detection.
- [ ] Previously pending real-server/HTTPS/VPN/Keychain checks from Phase 3 remain pending. This is an ad-hoc-signed development preview; Phase 5 editing and Phase 6 release acceptance are not implemented here.

## 日本語

### 実装範囲

ローカル用語集の作成・名前変更・削除・検索、項目編集、有効選択／なし、CSVの確認付き取り込み・書き出し、関連用語の照合、訳文の要確認表示を実装しました。管理画面はメニューバーまたはポップアップから開く、サイズ変更可能な独立ウィンドウです。設定画面は5タブを維持します。各項目は原語・指定訳語・英日方向・文脈・大文字小文字の区別・有効状態を持ちます。

保存先は`~/Library/Application Support/KotoFloat/glossaries.json`、形式バージョンは1です。ロードマップで候補としたSwiftDataに代え、上限付きの用語集を一括検証・保存し、未知形式と同時更新を明示的に保護するFoundation Codableと原子的なファイル置換を採用しました。将来の形式変更では明示的な移行が必要です。バージョン1は新しい形式を推測して読みません。ファイル不在のみを空として初期化し、不正・読み込み不能なら解決と再読込まで保存・翻訳を止めます。保存成功後にメモリ状態を変更し、ファイルロックと読込時データの比較で別インスタンスによる黙った上書きを防ぎます。

CSVは文書化したUTF-8の7列を使います。全レコード、重複方針、検証エラーをプレビューし、不正行が1件でもあれば全体を取り込みません。確認時の版番号で検証して一度だけ保存します。置換は最初の既存IDを維持し、最後の取り込み行を採用します。両方保持でも完全一致は追加しません。書き出しは無効項目も含む文字列そのままのCSVです。全用語集のバックアップではなく、表計算の数式も無害化しません。JSONのコピーは全用語集・ID・有効選択を保持します。

翻訳開始時に選択中の用語集を固定します。照合はメインアクター外で行い、大文字小文字・方向・有効状態、欧文の単語境界、日本語の部分文字列を考慮し、関連項目だけを選びます。翻訳元が自動の場合は翻訳先と文字列一致を使い、言語判定済みとは扱いません。同じ出現箇所に異なる訳語があれば表示し、参照から除外します。参照JSONは別のuserメッセージに入れ、system側でデータとして扱うよう指示します。最後のuserメッセージが原文です。試し翻訳は用語集を使いません。完成訳での指定訳語確認は補助であり、無条件の置換やモデル遵守の保証は行いません。

### バックグラウンドでの検証（2026-10-30）

- 保存・CSV・照合／要求・状態管理の新しい契約を実装前に実行し、未実装による失敗と実装後の成功を確認しました。
- `python3 scripts/test_with_mock_server.py`：既存のバックグラウンド検証を含む **103テスト成功**。ウィンドウを表示する15件は引き続き除外しています。
- 新しいループバックのシナリオは、合成した参照JSONを完全比較し、項目の不足・余分な項目を拒否して、テスト用と明示した固定文を返します。保存済み用語集の再読込、手入力の確定、本体URLSession、結果の完了と要確認状態まで確認しました。旧サーバーが3メッセージの要求を拒否して失敗することを確認後、対応を追加して成功しました。証明するのはデータ生成と通信であり、実翻訳や用語遵守ではありません。
- 保存のテストは登録・編集・削除・選択の再読込、検証、重複抑止、破損・将来版、保存失敗、同時更新、古いプレビューを扱います。CSVはBOM、引用符・カンマ・CRLF、不正形式、言語・真偽値エラー、ファイル内／既存との重複、一括反映を確認しました。
- 照合と状態管理は単語の部分一致拒否、句読点、大文字小文字の区別、日本語、方向・無効項目、競合除外、参照上限、関連項目だけの要求、指定訳語欠落、処理中の編集と再翻訳を確認しました。既存のキャンセル・遅延応答・コピー確認・重複要求のテストも成功しています。
- 指定された`.build/validation`でのDebugアプリビルドが成功しました。アプリ起動・再起動、入力の送出、フォーカス変更は行っていません。

### 上限と今後の確認

保存／CSVは16 MiB、用語集100個、全項目10,000件までです。名前・原語・指定訳語・文脈は120・256・1,024・2,048文字までです。1要求は一致項目100件・参照JSON 64 KiBまでとし、超過時は黙って省略せず説明して失敗します。用語集や原文はログに記録しません。

- [ ] 英日管理画面の配置、キーボード／VoiceOver、項目編集、検索、削除確認、エラー復旧の実操作。
- [ ] ファイルパネル、指定場所へのCSV入出力、表計算との相互利用、署名済みアプリでのバックアップ／復元。
- [ ] ポップアップの選択、長い要確認一覧、リサイズ・フォーカス・Esc・AutoRaiseの実機動作。
- [ ] 実LLMでの用語遵守、文脈に依存する訳語、用語競合、指定訳語欠落の補助判定の誤検出・見逃し。
- [ ] 第3段階で保留した実サーバー・HTTPS／VPN・Keychainも引き続き未確認です。アドホック署名の開発用プレビューであり、第5段階の編集と第6段階の配布受け入れは今回の実装範囲に含みません。
