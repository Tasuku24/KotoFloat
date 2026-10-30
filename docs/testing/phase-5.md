# Phase 5 verification / 第5段階の検証

## English

### Implemented scope

The reusable main translator shares the popup's `TranslationModel`, including the current request, source draft, generated output, optional manual edits, revision, and document identity. Opening the editor has no translation side effect. Source and result use native plain-text editors in a resizable two-pane window; the source supports ordinary paste, and only completed results are editable. Controls include language selection, character counts, explicit Translate/Retranslate/Stop, copy, clear, language/text swap, Undo/Redo, and original generated-output disclosure. Menus, labels, hints, and confirmations are available in English and Japanese.

Source edits cancel generation and invalidate request IDs. Language/glossary changes wait for an explicit request, while the old result retains its source, direction, and glossary snapshot. Manual edits remain separate from the generated output; glossary review and copying use the displayed edited result. Incomplete or empty output cannot use the copy-result button. Copy tests use named pasteboards only.

Retranslation with edits and replacement of an edited/untranslated draft defer to a shared confirmation. Clear and swap also require confirmation. A content revision and direction/settings/glossary snapshot prevent a stale confirmation from discarding newer work. UndoManager retains up to 100 groups within the current document; starting a new generation or confirming clear/swap resets it. Switching to sample/manual capture and unconfirmed copy capture preserves the shared document. Copy-fallback text must still be confirmed before it can become a translation candidate.

Swap requires a completed nonempty result matching the current source and explicit language direction. It places the edited result in the source, swaps languages, and does not send until Translate. Automatic source provides no detected-language metadata, so swap is disabled for it. English/Japanese remain the supported explicit directions. Source requests remain limited to 128 KiB of UTF-8.

Closing the popup cancels generation only when the editor is not visible; closing the editor cancels only when the popup is not visible. Both retain the document. Quitting asks about untranslated source changes or manual output edits. No source/result history is written to disk. Desktop evidence and remaining acceptance boundaries are recorded below.

### Background evidence (2026-10-30)

- New editor contracts first failed because the editor API was absent, then passed after implementation. Twelve focused editor tests cover generated/edited separation, undo/redo, retranslation and capture protection, stale confirmations, late tokens, source edits, clear/swap, input bounds, and named-pasteboard copying. Existing capture/translation/glossary regressions also pass.
- The initial `nice -n 10 swift test --jobs 2 --skip PopupControllerTests` run succeeded with **112 tests**; loopback-dependent cases are disabled without the fixture environment. The final fixture runner uses this same background command with the three added review regressions.
- `python3 scripts/test_with_mock_server.py`: **115 tests passed**, with the loopback cases enabled. The real URLSession flow confirms manual input, obtains a fixed response, edits and copies it to an isolated pasteboard, preserves the original output, confirms retranslation, and checks a new document with cleared undo. It proves transport/state behavior, not real-model translation quality.
- The required low-priority, two-job Debug app build succeeded in `.build/validation`. Xcode reported an unrelated simulator-version diagnostic and skipped optional AppIntents metadata extraction; the macOS build completed successfully.
- All **228** English/Japanese resource keys match, static localization references and format placeholders resolve, and both string files pass `plutil`. `git diff --check` passes.
- The initial background pass did not launch the app or synthesize input/focus. The subsequent desktop pass below was explicitly authorized by the user. `.build/xcode` was not used for verification; native-window tests remain excluded from the routine background command.

### Independent review

A read-only independent review found three important issues, all fixed with regressions that failed before the fixes and passed in the final 115-test fixture run: preflight failures incorrectly removed source-draft protection; cancelling a pending capture could indirectly stop the visible editor's translation; and termination protection omitted the popup's unsubmitted manual text. Failed/cancelled requests now retain source protection, capture navigation/cancellation leaves the translation lifecycle to its explicit owners, and quit checks both draft locations. No critical or minor findings were reported. The review did not assess desktop layout, native menu/IME behavior, accessibility, or AutoRaise; later desktop evidence is recorded below.

### Authorized desktop verification (2026-10-30)

- Two failures were reproduced and fixed: native insertion/paste raised an AppKit undo-group exception, and showing a retranslation confirmation enlarged the editor beyond the screen. Native text-coalescing now receives no undo manager, while explicit Undo/Redo still routes to the shared document. The editor's hosting view no longer overrides the user's frame. Regression logs show the exception and frame-growth failure before the fixes, followed by passing tests and a successful Debug build.
- `nice -n 10 swift test --jobs 2 --filter PopupControllerTests`: **17 tests passed**. Added tests cover native insertion, binding, responder Undo/Redo, stable frames after edits/confirmations, marked-text replacement and commit, and both panes scrolling 200 lines at 840 × 600 under Aqua and Dark Aqua. Marked-text API tests do not establish actual Japanese input-method behavior; appearance geometry tests do not establish visual contrast.
- The ad-hoc-signed `.build/validation` app accepted ordinary paste/selection, Command–Z, Shift–Command–Z, and Edit-menu Undo. Generated-original disclosure preserved the generated text. Copy returned the edited result. Control–Tab and Control–Shift–Tab moved focus between the text panes; AX labels, disabled result/copy controls, swap hints, and confirmation actions were observed. English/Japanese controls and character counts were checked in the large light-mode window.
- Edited-result retranslation, Keep editing, language/text swap, and quit protection were exercised. Swap moved the edited result to the source, changed direction, cleared the old result, and waited for explicit translation. Popup Escape/reopen, return to the main editor after edits, main-window minimize/reopen and close/reopen all preserved the document. The main frame also restored across an app restart. The corrected confirmation kept the frame and bottom actions onscreen.
- A disposable slow loopback fixture supplied a partial SSE result for 25 seconds. Popup-to-editor navigation preserved the active request and partial text. Stop retained the partial text, disabled copy/editing, and ignored the later completion. A malformed fixture without a choice index was correctly rejected before the fixture was corrected.
- LM Studio on `http://127.0.0.1:1234/v1`, model `hy-mt2-1.8b` (Hy-MT2 1.8B Q8_0, 4096-token context), translated “The voltage across the resistor is 5 volts.” to “抵抗器にかかる電圧は5ボルトです。” A swapped Japanese edited result also translated back to English. These are concrete smoke checks, not a translation-quality benchmark.
- A disposable glossary requested `voltage → 電位差`. The real model returned `電圧`; the app correctly displayed the missing-term warning. Editing the result to contain `電位差` removed it. The request snapshot and reference count were correct. This demonstrates detection of nonadherence, not guaranteed model adherence.
- A separate loopback endpoint required a disposable test token. The signed app was rejected without it, saved it to Keychain, connected with the input field cleared, connected again after restarting the same build, and was rejected again after removing the saved token. No existing endpoint credential was changed. Temporary preferences and glossary data were restored/removed after verification, and the temporary servers/model were stopped.
- The final loopback-enabled background run passed **115 tests**. Logs are local ignored artifacts in `.build/phase5-acceptance/`; the verification build remains separate from `.build/xcode`.

### SmolLM2 functional verification (2026-10-30)

The user supplied a loaded `smollm2-135m-instruct`: `unsloth/SmolLM2-135M-Instruct-GGUF/SmolLM2-135M-Instruct-Q4_K_M.gguf`, 105,454,144 bytes, 2048-token context, and four available prediction slots. Requests were sent sequentially. The API server was initially stopped; it was started on `127.0.0.1:1234` for this check and stopped afterward. No other model was loaded. SmolLM2 was left loaded and idle, and KotoFloat's original preferences were restored.

Two opt-in integration tests use the production URLSession client and shared model with isolated preferences, in-memory credentials, and a named pasteboard. They passed against SmolLM2 in 2.623 seconds total (a functional test duration, not an inference benchmark). They check model discovery, nonempty completed generation, request direction, manual capture, generated/edited separation, Undo/Redo, edited-result copying, Keep editing and confirmed retranslation, document/undo reset, swap without sending, clear confirmation, and cancellation after receiving an actual text chunk. They make no translation-quality assertions and are disabled in ordinary test runs. The subsequent `python3 scripts/test_with_mock_server.py` run also succeeded: 117 reported tests, including these two skipped local-model tests (115 executed).

To repeat them with an already loaded local model and a running loopback server:

```sh
KOTOFLOAT_LOCAL_MODEL=smollm2-135m-instruct nice -n 10 swift test --jobs 2 --skip PopupControllerTests --filter LocalModelIntegrationTests
```

The validation app also passed connection checking, test-sentence generation, source editing, main-window generation, native Command–Z / Shift–Command–Z, original-output disclosure, Keep editing, confirmed retranslation, and edit preservation after opening and closing the manual-entry popup. Copy was checked on a named pasteboard by the integration test; this pass did not replace the user's general clipboard. The response completed before the settings Stop button could be clicked, so live button cancellation is not claimed for SmolLM2; actual-client cancellation passed above, and the earlier slow-fixture UI check remains separate evidence. No production source changed in this pass, so no additional app build was needed. Local evidence is in `.build/smollm2-acceptance/`.

SmolLM2 responses mixed languages, echoed translation instructions, and introduced an unrequested `100mA` into the five-volts example. These are model-content failures, not successful translation-quality checks. The user deferred the following content checks to Qwen; they were subsequently evaluated below. Checked boxes indicate that evaluation was performed, not that the model passed:

- [x] English → Japanese and Japanese → English meaning, naturalness, and correct target-language output; verify that five volts stays five volts without introducing a current value. Qwen had terminology/meaning failures.
- [x] Return only the translation, without echoed instructions, source repetition, or unrelated explanations; preserve paragraph structure and numeric units. Qwen avoided extra explanations in these samples but lost both paragraph breaks.
- [x] Follow relevant glossary choices in context, including `voltage → 電位差`, and assess remaining missing-term warnings against the actual output. Qwen obeyed both Japanese-to-English entries but missed both English-to-Japanese entries; the app reported both missing terms correctly.

IME, VoiceOver, AutoRaise, visual/lifecycle coverage, and remote transport below are independent of the model; switching to Qwen alone will not verify them. The user confirmed that no remote server is currently available.

### Qwen content evaluation (2026-10-30)

Used the user's already running `qwen2.5-0.5b-instruct`, file `Qwen/Qwen2.5-0.5B-Instruct-GGUF/qwen2.5-0.5b-instruct-q4_k_m.gguf` (491,400,032 bytes), with the existing 32,768-token context and four prediction slots unchanged. The production client uses temperature 0.2. Requests ran sequentially through the actual `TranslationModel`, glossary matching/reference serialization, URLSession, and SSE decoder. No GUI, persistent preferences, personal glossary, or other model was changed; the user's server and loaded model were left running.

The **three opt-in integration tests passed** in 1.714 seconds total: the previous editor/cancellation contracts plus an opt-in six-case output recorder. All six evaluation requests completed and their glossary snapshots matched the selected entries. These assertions verify the application path, not semantic accuracy. The raw sources, outputs, missing-term results, and model configuration are committed in [qwen-0.5b-acceptance.json](qwen-0.5b-acceptance.json).

| Case | Content assessment |
| --- | --- |
| `en-ja-basic` | Failed: “五伏流が、电阻の电压です。” mixes Chinese forms with malformed Japanese and an incorrect voltage unit expression. |
| `ja-en-basic` | Failed: 5 V survived, but 抵抗器 became “reactor.” |
| `en-ja-paragraphs` | Failed: the resistor-replacement instruction was omitted and two paragraphs became one sentence. 5 V and 0.2 A survived. |
| `ja-en-paragraphs` | Failed: 抵抗器 became “valve,” and the paragraph break was lost. 5 V and 0.2 A survived. |
| `en-ja-glossary` | Failed: “5伏流抜きです。” omitted both 電位差 and 抵抗器. The shared model correctly returned two missing-term warnings. |
| `ja-en-glossary` | Passed for this sample: “The potential difference across the resistor is 5 V.” preserves the meaning and both specified terms; no missing-term warning. |

None of the six outputs echoed the prompt or appended unrelated explanations. However, only one sample met all of its content criteria. This is a small acceptance sample, not a general model benchmark. Qwen 0.5B can exercise the app's functional paths, but these results do not establish dependable Japanese translation or glossary adherence. Application-side term warnings work; they do not detect every semantic error or formatting omission. No production-code change was made to compensate for model output.

To repeat the capture with an already loaded model and running loopback server, create the output directory first:

```sh
mkdir -p .build/qwen-acceptance
KOTOFLOAT_LOCAL_MODEL=qwen2.5-0.5b-instruct KOTOFLOAT_EVALUATION_REPORT="$PWD/.build/qwen-acceptance/content.json" nice -n 10 swift test --jobs 2 --skip PopupControllerTests --filter LocalModelIntegrationTests
```

The evaluation recorder is disabled without `KOTOFLOAT_EVALUATION_REPORT`; all real-model tests remain disabled without `KOTOFLOAT_LOCAL_MODEL`. The subsequent background fixture run passed: 118 reported tests, including these three skipped real-model tests (115 executed). No additional app build was necessary because production code did not change.

### Remaining acceptance boundaries

- [ ] Actual Japanese IME candidate conversion/cancellation and caret/selection behavior throughout composition. This Mac had ABC selected and both input-source shortcuts disabled; the supported automation could not switch the input-source menu. Native marked-text insertion/commit passed separately.
- [ ] VoiceOver spoken navigation and complete keyboard traversal, plus actual AutoRaise hover transitions between applications. AX labels and native focus tests passed, but the available automation has no hover-only action or VoiceOver speech capture. AutoRaise was running during the session; that alone is not acceptance.
- [ ] Visual inspection at the minimum size and in dark mode, very long glossary-warning lists, source expansion with long content, and all close/minimize combinations during active generation. Minimum-size scrolling in both appearances passed native tests; the live large/light layout and specific transitions above passed. Do not infer the full matrix from those samples.
- [ ] Real HTTPS/VPN transport and certificate/authentication behavior against the intended remote service. No remote endpoint was available or supplied; the real-model and Keychain checks used loopback HTTP only.

The app remains a locally signed development preview. Release acceptance (now Phase 7 in the [revised roadmap](../superpowers/plans/2026-10-29-initial-release-phases.md)), distribution signing, and notarization are separate. The Phase 5 merge does not close the pending items above.

Click-based alternative translations, speech, tone controls, document translation, OCR, and saved history are not implemented in Phase 5. The DeepL reference concerns basic text interactions, not service integration or complete parity.

## 日本語

### 実装範囲

再利用するメイン翻訳画面は、現在の要求、原文の下書き、生成訳、手編集、版番号、文書IDを含む`TranslationModel`をポップアップと共有します。開くだけでは翻訳しません。サイズ変更できる2ペインにネイティブのプレーンテキスト入力を使い、原文は標準の貼り付け、訳文は完成後の編集に対応します。言語選択、文字数、明示的な翻訳／再翻訳／停止、コピー、クリア、言語と文章の入れ替え、Undo/Redo、生成訳の展開表示を備えます。メニュー・ラベル・案内・確認は英日対応です。

原文編集は生成を止め、要求IDを無効化します。言語・用語集の変更は明示要求を待ち、既存結果は要求時の原文・方向・用語集を保持します。編集訳と生成訳を区別し、用語集の要確認判定とコピーは表示中の編集訳を使います。未完了または空の訳文では結果コピーボタンを使えません。テストでは名前付きクリップボードだけを使います。

編集訳の再翻訳と編集済み／未翻訳下書きの置換は共有の確認を待ちます。クリアと入れ替えも確認が必要です。内容の版と方向・設定・用語集のスナップショットにより、古い確認が新しい作業を破棄することを防ぎます。UndoManagerは現在の文書内で最大100グループを保持し、新しい生成・確認後のクリア／入れ替えで消去します。サンプル・手入力への切り替えや未確認のコピー取得では文書を保持します。コピー取得文は、従来どおり確認後だけ翻訳候補にできます。

入れ替えには、現在の原文と明示した言語方向に一致する、空でない完成訳が必要です。編集訳を原文に移し、言語を交換して、翻訳ボタンまでは送信しません。翻訳元が自動の場合は判定言語情報がないため無効です。明示言語は引き続き英日で、原文送信はUTF-8で128 KiBまでです。

ポップアップを閉じる場合はエディタ非表示のときだけ、エディタを閉じる場合はポップアップ非表示のときだけ生成を止め、どちらも文書を保持します。未翻訳の原文変更や編集訳を残して終了する場合は確認します。原文・結果の履歴はディスクに保存しません。実画面の確認結果と残る受け入れ条件は以下に記録します。

### バックグラウンドでの検証（2026-10-30）

- 新しい編集APIが存在しないためテストが失敗することを先に確認し、実装後に成功しました。編集用12件は生成訳と編集訳の区別、Undo/Redo、再翻訳・取得置換の保護、古い確認、遅延応答、原文編集、クリア／入れ替え、入力上限、名前付きクリップボードを検証します。既存の取得・翻訳・用語集の回帰テストも成功しています。
- 初回の`nice -n 10 swift test --jobs 2 --skip PopupControllerTests`は **112テスト**で成功。固定サーバー環境がない場合はループバック依存のケースを無効にします。最終の固定サーバー検証も、レビュー後の回帰テスト3件を加えて同じ背景コマンドを使います。
- `python3 scripts/test_with_mock_server.py`：ループバックのケースを有効にして **115テスト成功**。実URLSessionで手入力を確定し、固定応答を取得、編集して独立クリップボードへコピー、生成訳の維持、確認付き再翻訳、新しい文書とUndo履歴消去を確認しました。通信と状態遷移の証明であり、実モデルの翻訳品質は検証しません。
- 指定の低優先度・2ジョブによる`.build/validation`へのDebugビルド成功。Xcodeから関連しないSimulatorのバージョン診断と任意のAppIntentsメタデータ抽出のスキップが出ましたが、macOSビルドは正常終了しました。
- 英日 **228キー** が一致し、静的な参照と書式引数、両ファイルの`plutil`検査、`git diff --check`が成功しました。
- 初回の背景検証ではアプリの起動・入力やフォーカスの送出を行っていません。その後、利用者の明示的な許可を受けて以下の実画面検証を実施しました。`.build/xcode`は検証に使わず、通常の背景コマンドからは引き続きネイティブウィンドウテストを除外します。

### 独立レビュー

読み取り専用の独立レビューで重要な指摘が3件あり、いずれも修正前に回帰テストが失敗し、修正後の固定APIを含む115テストで成功しました。送信前エラー後に原文下書きの保護が外れる点、取得中断が表示中エディタの翻訳を間接的に止める点、終了保護がポップアップの未確定手入力を見落とす点です。失敗／中断した要求の原文を保護し、取得画面の移動・中断では翻訳を止めず、両方の下書きを終了前に確認するよう修正しました。重大・軽微の指摘はありません。実配置、ネイティブのメニュー／IME、アクセシビリティ、AutoRaiseはレビューの対象外であり、その後の実画面の結果を以下に記録します。

### 許可を受けた実画面検証（2026-10-30）

- 不具合2件を再現して修正しました。ネイティブ入力／貼り付けでAppKitのUndoグループ例外が発生し、再翻訳の確認表示で画面が画面外まで拡大していました。ネイティブの入力結合にはUndoManagerを渡さず、明示Undo/Redoだけを共有文書へ渡します。エディタのホスティングビューは利用者のウィンドウ枠を上書きしません。修正前の例外・枠拡大の失敗と、修正後のテスト・Debugビルド成功をログに記録しました。
- `nice -n 10 swift test --jobs 2 --filter PopupControllerTests`：**17テスト成功**。追加テストでネイティブ入力と状態連携、レスポンダのUndo/Redo、編集／確認後の枠維持、変換中文字列の置換・確定、840 × 600のAqua／Dark Aquaで両ペインの200行スクロールを確認しました。変換中文字列のAPI試験は実日本語IMEの確認ではなく、明暗の寸法検証は視覚的なコントラストの確認ではありません。
- アドホック署名の`.build/validation`アプリで標準の貼り付け・選択、Command–Z、Shift–Command–Z、編集メニューのUndoが動作しました。生成訳の展開では元の文章を保持し、コピーは編集訳を返しました。Control–Tab／Control–Shift–Tabで両入力欄を往復でき、AXラベル、無効な訳文編集／コピー、入れ替えの案内、確認ボタンを確認しました。大きい明色ウィンドウで英日表示と文字数を確認しました。
- 編集訳の再翻訳、編集続行、言語と文章の入れ替え、終了保護を操作しました。入れ替えは編集訳を原文へ移し、方向を変更、旧訳文を消去し、明示翻訳を待ちました。ポップアップのEsc／再表示、編集後のメイン画面への復帰、メイン画面の最小化／再表示、閉じる／再表示で文書を保持しました。再起動時のメイン画面枠復元も確認しました。修正後の確認表示で枠と下部操作が画面内に維持されました。
- 検証専用の遅延ループバックAPIで、途中のSSE応答を25秒間保持しました。ポップアップからエディタへの移動で要求と途中訳を保持しました。停止後は途中訳を保持し、コピー／編集を無効化して、遅れて届く完了を無視しました。初めにchoiceのindexを欠いた固定応答は正しく拒否され、固定応答を修正して検証を続けました。
- LM Studioの`http://127.0.0.1:1234/v1`、`hy-mt2-1.8b`（Hy-MT2 1.8B Q8_0、コンテキスト4096トークン）で、“The voltage across the resistor is 5 volts.” が「抵抗器にかかる電圧は5ボルトです。」になりました。日本語の編集訳を入れ替え、英語に翻訳できることも確認しました。具体的な疎通確認であり、翻訳品質のベンチマークではありません。
- 検証用用語集で`voltage → 電位差`を指定しました。実モデルは`電圧`と訳しましたが、アプリは指定訳語の不足を警告し、`電位差`を含む編集訳に直すと警告が消えました。要求時の用語集と参照件数も一致しました。非遵守の検出を示すもので、モデルの用語遵守を保証しません。
- 別のループバックAPIに検証専用トークンを要求させました。署名済みアプリでトークンなしの拒否、Keychain保存、入力欄を空にした接続、同じビルドの再起動後の接続、保存トークン削除後の拒否を確認しました。既存接続先の認証情報は変更していません。検証後は一時設定と用語集を復元／除去し、一時サーバーとモデルを停止しました。
- 最終のループバック有効の背景検証は **115テスト成功**。ログは追跡対象外の`.build/phase5-acceptance/`に保存し、検証ビルドを`.build/xcode`から分離しています。

### SmolLM2による機能検証（2026-10-30）

利用者が読み込んだ`smollm2-135m-instruct`を使いました。ファイルは`unsloth/SmolLM2-135M-Instruct-GGUF/SmolLM2-135M-Instruct-Q4_K_M.gguf`、105,454,144バイト、コンテキスト2048トークン、同時生成枠4です。要求は順番に送りました。APIサーバーは開始時に停止していたため、検証中だけ`127.0.0.1:1234`で起動し、終了後に停止しました。別モデルは読み込んでいません。SmolLM2は読み込み済み・待機状態で残し、KotoFloatの設定は開始前へ復元しました。

明示時だけ動く統合テスト2件で、本番のURLSessionクライアントと共有モデルを使い、設定・メモリ内認証情報・名前付きクリップボードを分離しました。SmolLM2で合計2.623秒で成功しました（機能テストの所要時間であり、推論のベンチマークではありません）。モデル一覧、空でない生成完了、要求方向、手入力の確定、生成訳と編集訳の区別、Undo/Redo、編集訳コピー、編集続行と確認付き再翻訳、文書とUndo履歴のリセット、送信しない入れ替え、クリア確認、実際の文字列受信後の中断を確認します。翻訳品質を判定せず、通常のテストでは無効です。その後の`python3 scripts/test_with_mock_server.py`も成功し、報告117件のうち今回のローカルモデル2件はスキップ、115件を実行しました。

ローカルモデルを読み込み、ループバックサーバーを起動した状態で再実行します。

```sh
KOTOFLOAT_LOCAL_MODEL=smollm2-135m-instruct nice -n 10 swift test --jobs 2 --skip PopupControllerTests --filter LocalModelIntegrationTests
```

検証用アプリでも接続確認、試し翻訳、原文編集、メイン画面の生成、ネイティブのCommand–Z／Shift–Command–Z、生成訳の展開、編集続行、確認付き再翻訳、手入力ポップアップの開閉後の編集保持が成功しました。コピーは統合テストの名前付きクリップボードで確認し、今回は利用者の一般クリップボードを置き換えていません。設定画面の停止ボタンを押す前に生成が完了したため、SmolLM2での実ボタンによる停止は確認済みとしません。実クライアントの中断は上記のテストで成功し、以前の遅延固定応答によるUI確認とは分けて扱います。本番コードの変更はなく、アプリの追加ビルドは行っていません。ローカル証跡は`.build/smollm2-acceptance/`です。

SmolLM2の応答には言語の混在、翻訳指示の繰り返し、5ボルトの例への不要な`100mA`の追加がありました。モデルの内容面の失敗として記録し、翻訳品質の成功とは扱いません。利用者の指示で保留した以下の項目は、その後Qwenで評価しました。チェックは評価の実施済みを表し、モデルの合格を意味しません。

- [x] 英語→日本語・日本語→英語の意味、自然さ、指定言語での出力。5ボルトが5ボルトのままで、電流値を追加しないこと。Qwenには用語・意味の誤りがありました。
- [x] 翻訳だけを返し、指示文・原文の繰り返しや無関係な説明を含めず、段落構造と数値・単位を保持すること。Qwenの今回の応答に余分な説明はありませんでしたが、両方向の段落区切りが失われました。
- [x] `voltage → 電位差`などの関連用語を文脈に沿って使い、残る用語警告と実際の結果を照合すること。日英の指定2件は遵守し、英日の指定2件は欠落しました。アプリは欠落2件を正しく返しました。

以下のIME、VoiceOver、AutoRaise、表示・ライフサイクル、遠隔通信はモデルとは別の項目です。Qwenへ替えるだけでは確認できません。遠隔サーバーは現在ないことを利用者に確認済みです。

### Qwenによる内容評価（2026-10-30）

利用者が起動済みの`qwen2.5-0.5b-instruct`、ファイル`Qwen/Qwen2.5-0.5B-Instruct-GGUF/qwen2.5-0.5b-instruct-q4_k_m.gguf`（491,400,032バイト）を使い、コンテキスト32,768トークン・同時生成枠4の既存設定を維持しました。本番クライアントのtemperatureは0.2です。要求は実際の`TranslationModel`、用語照合・参照JSON生成、URLSession、SSEデコーダを通し、順番に送りました。GUI、永続設定、個人用語集、別モデルは変更せず、利用者のサーバーと読み込み済みモデルをそのまま稼働状態で残しました。

**明示実行の統合テスト3件が成功**し、合計1.714秒でした。既存の編集・中断の条件に加え、明示時だけ動く6ケースの出力記録を含みます。6要求はすべて完了し、要求時の用語集は選択した項目と一致しました。これはアプリの経路の確認であり、意味の正確さの成功ではありません。原文・実出力・不足用語・モデル設定は[qwen-0.5b-acceptance.json](qwen-0.5b-acceptance.json)に保存しました。

| ケース | 内容の評価 |
| --- | --- |
| `en-ja-basic` | 不合格。「五伏流が、电阻の电压です。」と出力し、中国語の字形、不自然な日本語、電圧単位の誤表現が混在。 |
| `ja-en-basic` | 不合格。5 Vは維持したが、抵抗器を“reactor”と誤訳。 |
| `en-ja-paragraphs` | 不合格。抵抗器を交換する指示が欠落し、2段落を1文に結合。5 Vと0.2 Aは維持。 |
| `ja-en-paragraphs` | 不合格。抵抗器を“valve”と誤訳し、段落区切りが消失。5 Vと0.2 Aは維持。 |
| `en-ja-glossary` | 不合格。「5伏流抜きです。」と出力し、電位差・抵抗器の両方が欠落。共有モデルは不足用語2件を正しく返した。 |
| `ja-en-glossary` | この例は合格。“The potential difference across the resistor is 5 V.”と出力し、意味と指定用語2件を維持。不足用語なし。 |

6出力とも、指示文の繰り返しや無関係な追加説明はありませんでした。ただし、内容の全条件を満たしたのは1例です。少数の受け入れ例であり、モデル全体のベンチマークではありません。Qwen 0.5Bでアプリの機能経路は確認できますが、日本語翻訳や用語遵守の信頼性を示す結果ではありません。アプリ側の用語警告は動作しますが、意味の誤りや書式の欠落をすべて検出するものではありません。モデルの出力を補うための本番コード変更は行っていません。

モデルを読み込み、ループバックサーバーを起動した状態で、出力先を作って再実行します。

```sh
mkdir -p .build/qwen-acceptance
KOTOFLOAT_LOCAL_MODEL=qwen2.5-0.5b-instruct KOTOFLOAT_EVALUATION_REPORT="$PWD/.build/qwen-acceptance/content.json" nice -n 10 swift test --jobs 2 --skip PopupControllerTests --filter LocalModelIntegrationTests
```

`KOTOFLOAT_EVALUATION_REPORT`がなければ出力記録を行わず、`KOTOFLOAT_LOCAL_MODEL`がなければ実モデルテスト全体を無効にします。その後の背景固定API検証も成功し、報告118件のうち実モデル3件はスキップ、115件を実行しました。本番コードに変更がないため、アプリの追加ビルドは不要でした。

### 残る受け入れ条件

- [ ] 実日本語IMEの候補変換／中断、変換中のカーソルと選択。このMacではABCが選択され、入力ソース切替のショートカットが両方無効で、対応する操作機能で入力メニューを切り替えられませんでした。ネイティブの変換中文字列APIによる入力・確定は別途成功しています。
- [ ] VoiceOverの読み上げによる移動とキーボード操作全体、別アプリ間の実AutoRaiseホバー移動。AXラベルとネイティブのフォーカステストは成功しましたが、操作環境にホバーだけを行う機能とVoiceOver音声の取得機能がありません。実行中にAutoRaiseが起動していたことだけでは受け入れ済みとしません。
- [ ] 最小サイズと暗色での目視、長い用語警告リスト、長文の原文展開、生成中の閉じる／最小化の全組み合わせ。最小サイズで両外観のスクロールはネイティブテスト、大きい明色画面と上記の特定の遷移は実機で成功していますが、全組み合わせの成功は推測しません。
- [ ] 実際の遠隔サービスでのHTTPS／VPN通信、証明書と認証。接続先の提供・設定がなかったため未検証です。実モデルとKeychainの確認はループバックHTTPのみです。

アプリはローカル署名の開発プレビューです。配布前の受け入れ（[改訂した開発計画](../superpowers/plans/2026-10-29-initial-release-phases.md)では第7段階）、配布署名、公証は別作業です。第5段階のマージによって上記の未確認項目が完了したとは扱いません。

単語クリックによる代替訳、音声、文体指定、文書翻訳、OCR、履歴保存は第5段階で実装していません。DeepLは基本的な文章操作の参考であり、サービス接続や全機能の同等性を意味しません。
