# Phase 6: Searchable languages and favorites

## English

**Design:** Extend the existing Codable language enum with a fixed, model-independent catalog. Keep `automatic`, `en`, and `ja` unchanged, so preferences, JSON glossaries (version 1), and CSV need no migration. Use Foundation Locale for English, Japanese, and native search names; use explicit English prompt names, including Chinese scripts and Portuguese regions. App UI remains English/Japanese.

**Interaction:** Use a shared searchable popover for source/target selection in popup, editor, settings, and glossary entry editing. Only source selection offers Automatic. Search supports names and codes, arrows move a highlighted row, Return selects, Escape dismisses only the picker. No selection sends a request. Keep explicit retranslation and the existing request snapshot, edited-result confirmation, and stale-response guards.

**Favorites:** User selected buttons plus Command-1 through Command-5. Persist up to five unique nonautomatic target languages in order; default Japanese then English, allow an empty list. Settings provides add/remove/reorder; popup/editor share the list and selection. Bind shortcuts only to controls in those windows, never globally or in settings. Favorite changes must not invalidate translation confirmations or change request direction.

**Approaches:** A new language settings service would duplicate existing preferences; a second picker per screen would duplicate interaction logic. Extend TranslationPreferences and reuse one native-platform popover instead. No dependency or glossary schema change.

### Task 1: Catalog and preferences

- [x] Add tests for search aliases/scripts, stable Codable values, legacy preferences, invalid/duplicate/oversized favorites, empty favorites and persistence; observe failure.
- [x] Implement TranslationLanguage catalog/search/prompt names and normalized favorite persistence in TranslationPreferences.
- [x] Run `nice -n 10 swift test --jobs 2 --filter 'Language|TranslationSettingsTests'`; expect pass. Commit.

### Task 2: Shared controls and lifecycle

- [x] Add request tests for expanded direction, active-request snapshots, edited-draft preservation, stale confirmations, and glossary JSON/CSV direction round trips.
- [x] Replace language controls, add searchable keyboard-operated popover, favorite buttons/local shortcuts and settings ordering. Add aligned English/Japanese strings.
- [x] Run background tests and a separate Debug build; expect pass. Commit.

### Task 3: Verification and documentation

- [x] Verify actual keyboard/picker behavior in native windows where available; record limitations honestly. Run loopback fixture tests, localization parity, and diff checks.
- [x] Review whole diff for target Automatic, focus/Escape handling, shortcut scope, IME interaction, persistence, and draft/request protection. Fix material findings.
- [x] Update README, roadmap, and Phase 6 verification in English then Japanese. Commit; leave branch unmerged.

**Review focus:** Invalid saved target/favorites, variants in glossary matching, search after no results, Escape closing parent, duplicate window shortcuts, language changes during streaming/confirmation, and favorites stealing another app's input. Remaining physical IME/VoiceOver/AutoRaise and remote transport acceptance stays open for Phase 7. Do not start a heavy model for fixture checks.

## 日本語

**設計:** 既存のCodable言語列挙に固定の言語一覧を追加する。`automatic`、`en`、`ja`を変えず、設定・用語集JSON（版1）・CSVの移行は不要とする。Foundation Localeで英語・日本語・現地名を検索し、要求には中国語の字体とポルトガル語の地域を区別した英語名を使う。アプリの表示言語は英日を維持する。

**操作:** ポップアップ・エディタ・設定・用語編集で検索付きの言語選択を共有する。自動は翻訳元のみ。上下矢印で候補、Returnで選択、Escで選択画面だけを閉じる。選択で送信せず、明示的再翻訳・要求時の情報・編集保護・古い応答の排除を維持する。

**お気に入り:** 利用者がボタン＋Command-1〜5を選択した。自動以外を重複なく最大5件、順序付きで保存し、初期値は日本語・英語。空も許可する。設定で追加・削除・並べ替え、ポップアップとエディタで共有する。ショートカットはその画面内だけとし、設定や他アプリでは扱わない。お気に入り変更では要求方向や翻訳確認を無効化しない。

**方式:** 設定専用サービスや画面ごとの重複実装は増やさず、既存TranslationPreferencesと共通のネイティブプラットフォームの選択画面を使う。依存や用語集形式は変更しない。

### 第1作業：言語と設定

- [x] 検索・字体・Codable互換・旧設定・不正／重複／過大なお気に入り・空と再読込を先にテストする。
- [x] 言語一覧・検索・要求名と正規化したお気に入り保存を実装する。
- [x] 対象テストを通してコミットする。

### 第2作業：共通操作と保護

- [x] 新しい方向・実行中の要求情報・編集保持・古い確認・JSON/CSVの方向をテストする。
- [x] 言語選択・キーボード・お気に入りボタンと画面内ショートカット・設定の並べ替え・英日表示を実装する。
- [x] 背景テストと別保存先のDebugビルドを通してコミットする。

### 第3作業：検証と記録

- [x] 可能な範囲でネイティブ操作、ループバック、翻訳キーと差分を検証し、制限を記録する。
- [x] 自動の誤選択・Esc・ショートカットの範囲・IME・設定保持・編集保護をレビューして重要な問題を修正する。
- [x] README・ロードマップ・検証記録を英語の後に日本語で更新し、コミットする。マージしない。

**重点:** 不正保存値・用語集の字体／地域区別・検索0件後・親画面を閉じないEsc・複数画面のショートカット・生成／確認中の言語変更・別アプリ入力。実IME／VoiceOver／AutoRaiseと遠隔接続の未確認事項は第7段階に残す。固定応答の検証では重いモデルを起動しない。
