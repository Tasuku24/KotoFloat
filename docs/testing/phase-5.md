# Phase 5 verification / 第5段階の検証

## English

### Implemented scope

The reusable main translator shares the popup's `TranslationModel`, including the current request, source draft, generated output, optional manual edits, revision, and document identity. Opening the editor has no translation side effect. Source and result use native plain-text editors in a resizable two-pane window; the source supports ordinary paste, and only completed results are editable. Controls include language selection, character counts, explicit Translate/Retranslate/Stop, copy, clear, language/text swap, Undo/Redo, and original generated-output disclosure. Menus, labels, hints, and confirmations are available in English and Japanese.

Source edits cancel generation and invalidate request IDs. Language/glossary changes wait for an explicit request, while the old result retains its source, direction, and glossary snapshot. Manual edits remain separate from the generated output; glossary review and copying use the displayed edited result. Incomplete or empty output cannot use the copy-result button. Copy tests use named pasteboards only.

Retranslation with edits and replacement of an edited/untranslated draft defer to a shared confirmation. Clear and swap also require confirmation. A content revision and direction/settings/glossary snapshot prevent a stale confirmation from discarding newer work. UndoManager retains up to 100 groups within the current document; starting a new generation or confirming clear/swap resets it. Switching to sample/manual capture and unconfirmed copy capture preserves the shared document. Copy-fallback text must still be confirmed before it can become a translation candidate.

Swap requires a completed nonempty result matching the current source and explicit language direction. It places the edited result in the source, swaps languages, and does not send until Translate. Automatic source provides no detected-language metadata, so swap is disabled for it. English/Japanese remain the supported explicit directions. Source requests remain limited to 128 KiB of UTF-8.

Closing the popup cancels generation only when the editor is not visible; closing the editor cancels only when the popup is not visible. Both retain the document. Quitting asks about untranslated source changes or manual output edits. No source/result history is written to disk. These native-window behaviors are implemented but need desktop acceptance.

### Background evidence (2026-10-30)

- New editor contracts first failed because the editor API was absent, then passed after implementation. Twelve focused editor tests cover generated/edited separation, undo/redo, retranslation and capture protection, stale confirmations, late tokens, source edits, clear/swap, input bounds, and named-pasteboard copying. Existing capture/translation/glossary regressions also pass.
- The initial `nice -n 10 swift test --jobs 2 --skip PopupControllerTests` run succeeded with **112 tests**; loopback-dependent cases are disabled without the fixture environment. The final fixture runner uses this same background command with the three added review regressions.
- `python3 scripts/test_with_mock_server.py`: **115 tests passed**, with the loopback cases enabled. The real URLSession flow confirms manual input, obtains a fixed response, edits and copies it to an isolated pasteboard, preserves the original output, confirms retranslation, and checks a new document with cleared undo. It proves transport/state behavior, not real-model translation quality.
- The required low-priority, two-job Debug app build succeeded in `.build/validation`. Xcode reported an unrelated simulator-version diagnostic and skipped optional AppIntents metadata extraction; the macOS build completed successfully.
- All **228** English/Japanese resource keys match, static localization references and format placeholders resolve, and both string files pass `plutil`. `git diff --check` passes.
- No app was launched or restarted; no input/focus was synthesized. `.build/xcode` was not used for verification. Native-window tests remain excluded.

### Independent review

A read-only independent review found three important issues, all fixed with regressions that failed before the fixes and passed in the final 115-test fixture run: preflight failures incorrectly removed source-draft protection; cancelling a pending capture could indirectly stop the visible editor's translation; and termination protection omitted the popup's unsubmitted manual text. Failed/cancelled requests now retain source protection, capture navigation/cancellation leaves the translation lifecycle to its explicit owners, and quit checks both draft locations. No critical or minor findings were reported. The review did not assess desktop layout, native menu/IME behavior, accessibility, or AutoRaise; these remain the acceptance list below.

### Pending desktop acceptance

- [ ] English/Japanese layout at minimum/larger sizes, scrolling long text and glossary warnings, light/dark mode, character counts, and source expansion.
- [ ] Native paste, selection, Japanese IME composition, Command–Z / Shift–Command–Z, Edit menu routing, selection/caret behavior during undo, and generated-original disclosure.
- [ ] Keyboard/VoiceOver access and labels for both text panes, disabled controls, confirmation actions, and language swap hints.
- [ ] Repeated popup-to-editor navigation during streaming/after edits, close/reopen/minimize combinations, frame restoration, quit confirmation, focus/Escape, and AutoRaise on the user's desktop.
- [ ] Real LLM behavior and the previously pending HTTPS/VPN/Keychain/glossary adherence checks. The app remains a locally signed development preview; Phase 6 acceptance/signing/notarization is separate.

Click-based alternative translations, speech, tone controls, document translation, OCR, and saved history are not implemented in Phase 5. The DeepL reference concerns basic text interactions, not service integration or complete parity.

## 日本語

### 実装範囲

再利用するメイン翻訳画面は、現在の要求、原文の下書き、生成訳、手編集、版番号、文書IDを含む`TranslationModel`をポップアップと共有します。開くだけでは翻訳しません。サイズ変更できる2ペインにネイティブのプレーンテキスト入力を使い、原文は標準の貼り付け、訳文は完成後の編集に対応します。言語選択、文字数、明示的な翻訳／再翻訳／停止、コピー、クリア、言語と文章の入れ替え、Undo/Redo、生成訳の展開表示を備えます。メニュー・ラベル・案内・確認は英日対応です。

原文編集は生成を止め、要求IDを無効化します。言語・用語集の変更は明示要求を待ち、既存結果は要求時の原文・方向・用語集を保持します。編集訳と生成訳を区別し、用語集の要確認判定とコピーは表示中の編集訳を使います。未完了または空の訳文では結果コピーボタンを使えません。テストでは名前付きクリップボードだけを使います。

編集訳の再翻訳と編集済み／未翻訳下書きの置換は共有の確認を待ちます。クリアと入れ替えも確認が必要です。内容の版と方向・設定・用語集のスナップショットにより、古い確認が新しい作業を破棄することを防ぎます。UndoManagerは現在の文書内で最大100グループを保持し、新しい生成・確認後のクリア／入れ替えで消去します。サンプル・手入力への切り替えや未確認のコピー取得では文書を保持します。コピー取得文は、従来どおり確認後だけ翻訳候補にできます。

入れ替えには、現在の原文と明示した言語方向に一致する、空でない完成訳が必要です。編集訳を原文に移し、言語を交換して、翻訳ボタンまでは送信しません。翻訳元が自動の場合は判定言語情報がないため無効です。明示言語は引き続き英日で、原文送信はUTF-8で128 KiBまでです。

ポップアップを閉じる場合はエディタ非表示のときだけ、エディタを閉じる場合はポップアップ非表示のときだけ生成を止め、どちらも文書を保持します。未翻訳の原文変更や編集訳を残して終了する場合は確認します。原文・結果の履歴はディスクに保存しません。これらのネイティブウィンドウ動作は実装済みですが、実画面での受け入れは未確認です。

### バックグラウンドでの検証（2026-10-30）

- 新しい編集APIが存在しないためテストが失敗することを先に確認し、実装後に成功しました。編集用12件は生成訳と編集訳の区別、Undo/Redo、再翻訳・取得置換の保護、古い確認、遅延応答、原文編集、クリア／入れ替え、入力上限、名前付きクリップボードを検証します。既存の取得・翻訳・用語集の回帰テストも成功しています。
- 初回の`nice -n 10 swift test --jobs 2 --skip PopupControllerTests`は **112テスト**で成功。固定サーバー環境がない場合はループバック依存のケースを無効にします。最終の固定サーバー検証も、レビュー後の回帰テスト3件を加えて同じ背景コマンドを使います。
- `python3 scripts/test_with_mock_server.py`：ループバックのケースを有効にして **115テスト成功**。実URLSessionで手入力を確定し、固定応答を取得、編集して独立クリップボードへコピー、生成訳の維持、確認付き再翻訳、新しい文書とUndo履歴消去を確認しました。通信と状態遷移の証明であり、実モデルの翻訳品質は検証しません。
- 指定の低優先度・2ジョブによる`.build/validation`へのDebugビルド成功。Xcodeから関連しないSimulatorのバージョン診断と任意のAppIntentsメタデータ抽出のスキップが出ましたが、macOSビルドは正常終了しました。
- 英日 **228キー** が一致し、静的な参照と書式引数、両ファイルの`plutil`検査、`git diff --check`が成功しました。
- アプリの起動・再起動、入力やフォーカスの送出は行っていません。検証に`.build/xcode`を使わず、ネイティブウィンドウテストも除外しています。

### 独立レビュー

読み取り専用の独立レビューで重要な指摘が3件あり、いずれも修正前に回帰テストが失敗し、修正後の固定APIを含む115テストで成功しました。送信前エラー後に原文下書きの保護が外れる点、取得中断が表示中エディタの翻訳を間接的に止める点、終了保護がポップアップの未確定手入力を見落とす点です。失敗／中断した要求の原文を保護し、取得画面の移動・中断では翻訳を止めず、両方の下書きを終了前に確認するよう修正しました。重大・軽微の指摘はありません。実配置、ネイティブのメニュー／IME、アクセシビリティ、AutoRaiseはレビューの対象外であり、以下に残しています。

### 実画面での受け入れ確認

- [ ] 英日での最小／拡大サイズの配置、長文と用語警告のスクロール、明暗表示、文字数、原文の展開。
- [ ] 標準貼り付け、選択、日本語IME、Command–Z／Shift–Command–Z、編集メニュー、Undo時の選択とカーソル、生成訳の展開。
- [ ] 両入力欄、無効な操作、確認、入れ替えの案内のキーボード／VoiceOver対応。
- [ ] 生成中／編集後のポップアップとエディタ間の反復移動、閉じる／再表示／最小化、位置復元、終了確認、フォーカス／Esc／AutoRaise。
- [ ] 実LLMと、従来から保留中のHTTPS／VPN／Keychain／用語集遵守。ローカル署名の開発プレビューであり、第6段階の受け入れ・署名・公証は別作業です。

単語クリックによる代替訳、音声、文体指定、文書翻訳、OCR、履歴保存は第5段階で実装していません。DeepLは基本的な文章操作の参考であり、サービス接続や全機能の同等性を意味しません。
