# Phase 6 verification: languages and favorites

## English

### Implemented behavior

As of 2026-10-31, `feature/language-picker-and-favorites` extends latest `main` (`e9980e3`) with a shared searchable native language picker in popup, editor, settings, and glossary entry editing. Search covers English/Japanese/native names and codes. Arrows move the highlighted row; Return selects; Escape dismisses only the picker. Selection does not send a translation. Source Automatic remains available; target Automatic is excluded and rejected in preferences/client validation.

The catalog has 26 target choices: `en`, `ja`, `zh-Hans`, `zh-Hant`, `ko`, `fr`, `de`, `es`, `pt-BR`, `pt-PT`, `it`, `nl`, `ru`, `uk`, `pl`, `cs`, `sv`, `da`, `nb`, `fi`, `el`, `tr`, `ar`, `id`, `vi`. These are app-selectable languages, not a statement of model support or translation quality. Request prompts explicitly distinguish Chinese scripts and Portuguese regions. App UI still supports English/Japanese.

Settings → Translation allows up to five ordered favorites, defaults to Japanese/English, and supports add, remove, reorder, and an empty list. Popup/editor buttons and Command-1–5 use that order. Only exact Command plus an available number in the control's own key window qualifies; no global favorite shortcut is registered. Picker/settings/other-app input is not handled by these controls. A horizontal scroller retains access when favorite names are long.

Language/favorite selection preserves text, edits and undo. Requests keep their original language/glossary snapshot until explicit retranslation; edited results still require confirmation. Legacy `automatic`/`en`/`ja` preference values, JSON library version 1 and CSV fields remain unchanged. Expanded language variants round-trip and match exact glossary directions; no migration is needed. Unknown glossary values still fail closed rather than erasing data.

### Evidence

- `nice -n 10 swift test --jobs 2 --filter 'LanguageTests|TranslationSettingsTests'`: 9 tests passed for the initial catalog/preferences increment after observing the missing feature fail. Search aliases/scripts, stable raw values, Codable round trips, normalized duplicate/invalid/over-limit favorites, empty-list restoration, legacy settings and invalid targets were covered.
- `python3 scripts/test_with_mock_server.py`: 127 background tests reported, with **124 executed successfully and 3 real-model tests skipped**. Real URLSession loopback tests ran. New checks cover every target prompt, expanded glossary JSON/CSV, Chinese script separation, active-request language snapshots, edited-draft/undo preservation, stale confirmation rejection, explicit retranslation and late callbacks. No heavy model was started.
- `nice -n 10 swift test --jobs 2 --filter PopupControllerTests`: **21 native tests passed**. New checks send actual app-local events through NSApplication, prove hosted favorite-bar installation and monitor removal, reject wrong windows/modifiers/unavailable numbers, type into the native picker search field, route Down/Return through the popover window, and route Escape without closing/resizing the parent. Existing editor/window tests also passed.
- Picker controller tests cover no-results recovery, selection/dismissal without submission, excluding existing favorites, and leaving marked-text commands to the native input context. This is API-level marked-text evidence, not physical Japanese IME acceptance.
- Debug app build succeeded with `nice -n 10 xcodebuild -project KotoFloat.xcodeproj -scheme KotoFloat -configuration Debug -derivedDataPath .build/validation -jobs 2 build`. `codesign --verify --deep --strict` passed for the locally signed build. The build is not Developer ID signed/notarized for distribution.
- Both localization files pass `plutil`; all 240 English/Japanese keys match. `git diff --check` passes.
- Independent source review found a missing visible From/To label in the new controls; labels were restored. Review-requested native dispatch/attachment tests were added and passed. No remaining significant source finding was reported.

### Remaining acceptance

- [ ] Physical Japanese IME candidate conversion/cancellation in search and real VoiceOver navigation/announcements.
- [ ] Actual AutoRaise compatibility, focus transitions between another app and the picker, and shortcuts under that environment. The automated picker keyboard checks cover Standard mode. An attempted compatibility-mode test could not acquire a key standard window in the command-line test host; activating that host disturbed other focus assertions. No product change or success claim was based on this host limitation.
- [ ] Complete English/Japanese visual matrix with five long favorites, minimum popup/editor sizes, right-to-left text, and light/dark appearances. Existing editor minimum-size/appearance tests are useful but do not establish this full matrix.
- [ ] Settings add/remove/reorder and glossary entry controls with physical keyboard and screen reader.
- [ ] Real-model quality for expanded languages, language variants and glossary adherence; existing small Qwen samples do not establish multilingual quality. Existing matcher boundary rules are preserved; morphology and word segmentation across all new languages have not been evaluated.
- [ ] Outstanding Phase 1–5 desktop acceptance and distribution/signing remain in their records and Phase 7. Host HTTPS/Tailscale was subsequently verified in [Phase 3](phase-3.md). This development branch was not merged or published.

## 日本語

### 実装内容

2026-10-31時点で、最新`main`（`e9980e3`）から作った`feature/language-picker-and-favorites`に、ポップアップ・エディタ・設定・用語編集で共有するネイティブの検索付き言語選択を追加しました。英語名・日本語名・現地名・コードを検索し、上下矢印で候補移動、Returnで選択、Escで選択画面だけを閉じます。選択では翻訳を送信しません。翻訳元の自動は維持し、翻訳先の自動は画面と設定／クライアントの検証で拒否します。

翻訳先は`en`、`ja`、`zh-Hans`、`zh-Hant`、`ko`、`fr`、`de`、`es`、`pt-BR`、`pt-PT`、`it`、`nl`、`ru`、`uk`、`pl`、`cs`、`sv`、`da`、`nb`、`fi`、`el`、`tr`、`ar`、`id`、`vi`の26種類です。アプリで選べる言語であり、モデルの対応や品質の保証ではありません。要求では中国語の字体とポルトガル語の地域を区別します。アプリ表示は英日を維持します。

設定→翻訳でお気に入りを順序付きで最大5件登録し、追加・削除・並べ替え・空の一覧に対応します。初期値は日本語／英語です。ポップアップ／エディタのボタンとCommand-1〜5は登録順を使います。その操作部品があるキーウィンドウへの、修飾キーがCommandだけの有効番号のみを扱い、グローバル登録はしません。言語選択・設定・他アプリの入力は処理しません。長いお気に入り名は横スクロールで参照できます。

言語／お気に入りの変更で文章・編集・Undoを失いません。明示的な再翻訳まで要求時の言語／用語集を保持し、編集訳の再翻訳では確認します。旧`automatic`／`en`／`ja`、JSON版1、CSV列を変更しません。新しい字体・地域も保存往復と厳密な方向照合に対応し、移行は不要です。未知の用語集値は従来どおり読み込み失敗とし、空データで上書きしません。

### 検証結果

- 初回の言語一覧／設定テストは機能不足で失敗することを確認後、`nice -n 10 swift test --jobs 2 --filter 'LanguageTests|TranslationSettingsTests'`で9テスト成功。名称・字体検索、保存値とCodable、重複／不正／過大なお気に入り、空一覧の復元、旧設定と不正な翻訳先を確認しました。
- `python3 scripts/test_with_mock_server.py`は背景127テストを報告し、**124件実行成功、実モデル3件はスキップ**。実URLSessionのループバック検証も実行しました。全翻訳先の要求名、用語集JSON/CSV、中国語字体の区別、生成中の言語情報、編集とUndo保持、古い確認の拒否、明示的再翻訳、遅延応答を確認しました。重いモデルは起動していません。
- `nice -n 10 swift test --jobs 2 --filter PopupControllerTests`で**ネイティブ21テスト成功**。NSApplication経由のローカル入力、画面内お気に入り部品の接続と監視解除、不正な画面／修飾キー／番号の拒否、検索欄への入力、選択画面経由のDown／Return、親画面を閉じたりリサイズしたりしないEscを確認しました。既存の編集／ウィンドウテストも成功しました。
- 選択画面のテストは検索0件からの復帰、送信しない選択／終了、既存お気に入りの除外、変換中のキー操作を入力コンテキストに残すことを確認します。これはAPIの変換中文字列の証拠であり、実IMEの受け入れ確認ではありません。
- `.build/validation`を保存先にした低優先度・2ジョブのDebugビルドが成功し、`codesign --verify --deep --strict`も成功しました。配布用Developer ID署名／公証は行っていません。
- 英日240キーが一致し、両ファイルの`plutil`と`git diff --check`が成功しました。
- 独立レビューで新しい部品の翻訳元／先の可視ラベル不足を指摘され、復元しました。追加を求められた入力配送・画面接続のテストも成功し、重要な未解決のソース指摘はありません。

### 残る受け入れ確認

- [ ] 検索欄での実日本語IME候補の変換／取消、VoiceOverの移動と読み上げ。
- [ ] 実AutoRaise、他アプリと選択画面を行き来するフォーカスと、その環境のショートカット。自動キー検証は標準モードです。互換モードも試しましたが、コマンドラインのテスト実行元では通常ウィンドウをキーにできず、実行元の有効化は他のフォーカス検証も乱しました。この実行元の制限に基づく製品変更や成功判定はしていません。
- [ ] 長いお気に入り5件、最小ポップアップ／エディタ、右から左の文章、ライト／ダーク、英日表示の全組み合わせ。既存の最小サイズ／外観テストだけではこの全体を確認したことにはしません。
- [ ] 設定の追加・削除・並べ替え、用語編集の実キーボード／読み上げ操作。
- [ ] 追加言語・字体・地域・用語集の実モデル品質。既存の小型Qwenの例は多言語品質の証拠ではありません。用語照合の境界規則は維持し、全言語の形態・分かち書きは未評価です。
- [ ] 第1〜第5段階の実画面の残項目と配布・署名は元の記録と第7段階で管理します。ホストHTTPS／Tailscaleはその後[第3段階](phase-3.md)で確認しました。この開発ブランチはマージ・公開していません。
