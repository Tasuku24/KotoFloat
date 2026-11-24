# Translator back translation and review improvements

## English

Follow-up: [November 17 real-model correspondence repair](translation-alignment-2026-11-17.md).

### Behavior

- **Back translation:** Translator's toolbar has a Back-translate action. It streams the displayed translation, including manual edits, back into the original language and shows it below the result. The source and translation remain visible and unchanged. The panel provides a language menu, refresh, and close. With Automatic source language, macOS NaturalLanguage detects the original locally; uncertain or unsupported detection requires a language choice. The language menu also allows correction of detection. Requests use the existing configured server and translation transport. Neither the original text nor the forward glossary is included in the back-translation request, so they cannot steer it toward reproducing the original.
- **Corresponding highlights:** The client publishes validated correspondence before requesting alternatives. Both editors can therefore highlight their passages while candidates are still loading, and the counterpart scrolls into view. Inspecting a translated word also reveals a collapsed source pane. Matching remains semantic and validated; sentences are never paired by position when no match is available.
- **Alternatives:** The prompt asks for contextual words or short phrases and permits grammatical adjustment during the existing rewrite step. Candidates are bounded, deduplicated, and filtered against unchanged text before deciding whether a request succeeded. When none remain, one additional request explicitly considers phrase alternatives. An empty result is not cached as a permanent answer. Empty results, unavailable matches, and failures offer Try again. A successful candidate still rewrites only its matched passage through the existing Undo path.

The word-click candidate interaction follows [DeepL's documented alternatives interaction](https://support.deepl.com/hc/en-us/articles/4407359201938-Select-alternatives). This is a reference for interaction, not a DeepL service integration. All user text continues to use the configured server.

### Ownership and invalidation

`BackTranslationModel` owns transient output and cancellation; `TranslationModel` continues to own source, translation, Undo, and history. Document edits, Undo, retranslation, and document replacement invalidate back translation. Replies also check document ID, revision, connection/language revision, and glossary revision. Dismissed or obsolete replies cannot reappear. Back-translation output is bounded to 128 KiB and empty or failed replies are shown as errors without modifying the document.

Review's progress callback carries only validated passage correspondence. Existing request IDs and snapshots reject late progress as well as late final replies. Candidate failure retains the confirmed highlights. A word click uses one correspondence request and one candidate request, with at most one additional candidate attempt; retries are explicit. No requests are added on application launch.

### Verification on November 16, 2026

- Added regression tests failed before the fixes for delayed highlight publication, permanently cached empty candidates, and unchanged-only suggestions. Back-translation tests cover edited input, Automatic language detection, explicit language choice, streaming, empty/network/oversized responses, unchanged document/Undo, and late responses after edits, language/server changes, replacement, or dismissal.
- `nice -n 10 swift test --jobs 2 --skip PopupControllerTests`: **220 tests passed**.
- `python3 scripts/test_with_mock_server.py`: **220 tests passed**, including the loopback production-client transport suite.
- Four separately run offscreen native checks passed: paired highlights while alternatives wait, stable clicked viewport for a long match, editor split/header/minimum-size layout, and opening back translation with the source collapsed at the minimum window size. The latter caught a hidden source pane and a zero-height translation editor before the fixes; back translation now reveals the source and uses a height proportional to the available pane, capped at 210 points. The test windows were never shown or made key. Hosted-content images were inspected locally.
- Debug build and strict signature verification passed at `.build/validation/translator-improvements-20261116/Build/Products/Debug/KotoFloat.app`, separate from the running app.

These results establish lifecycle, validation, transport, and the tested native rendering behavior. They do not establish the configured model's semantic quality or guarantee an alternative for every word. Live app update, pointer/popover behavior, and real-model samples are separate acceptance steps.

The first authorized live update exposed a crash while accessibility inspected the new panel: the crash report showed recursive SwiftUI/AppKit accessibility-label resolution. The back-translation panel was revised to reuse the existing native `LanguagePicker` and read-only `TranslationTextEditor`, with no Undo manager for its comparison text. The hidden native regression also checks the result's accessible label/value and read-only state. External accessibility inspection is verified separately in the live app.

## 日本語

後続の修正：[11月17日の実モデル対応付け修正](translation-alignment-2026-11-17.md)。

### 動作

- **逆翻訳：** Translatorのツールバーに「逆翻訳」を追加した。手動編集を含む表示中の訳文を元の言語へ逐次翻訳し、訳文の下に表示する。原文・訳文は表示したまま変更しない。逆翻訳欄には言語メニュー、更新、閉じる操作を用意する。原文の言語が「自動」の場合は、macOSのNaturalLanguageで原文を端末内で判定する。不確かな判定や未対応言語では、利用者が言語を選ぶ。判定結果もメニューから修正できる。既存の設定済みサーバーと翻訳通信を使う。逆翻訳が原文を再現する方向へ誘導されないよう、逆翻訳の要求には原文と順方向の用語集を含めない。
- **対応箇所のハイライト：** 候補の要求前に、検証済みの対応箇所を通知する。候補の取得中でも両側をハイライトし、反対側の対応箇所を表示範囲へスクロールできる。訳文の単語を確認する場合は、折りたたまれた原文も表示する。意味の対応と範囲の検証は維持し、対応が不明な文を位置だけで結び付けない。
- **別訳候補：** 文脈に合う単語や短いフレーズを要求し、既存の書き直し処理で文法を調整できることを指示する。候補の上限・重複・元と同じ表現を検査してから、候補が得られたかを判断する。有効な候補が残らなければ、フレーズの言い換えも含めて一度だけ追加要求する。空の候補を恒久的な回答としてキャッシュしない。候補なし、対応不明、取得失敗の場合は「再取得」を表示する。有効な候補を選ぶと、既存のUndoに対応した経路で対応箇所だけを書き直す。

単語をクリックして候補を選ぶ操作は、[DeepLの公式説明](https://support.deepl.com/hc/en-us/articles/4407359201938-Select-alternatives)を参照した。操作の参考であり、DeepLサービスとの連携ではない。利用者の文章は引き続き設定済みサーバーだけに送信する。

### 状態管理と無効化

一時的な出力と取り消しは`BackTranslationModel`が管理し、原文・訳文・Undo・履歴は引き続き`TranslationModel`が管理する。編集、Undo、再翻訳、文書の置き換えで逆翻訳を無効にする。応答の受信時にも文書ID、リビジョン、接続・言語設定と用語集のリビジョンを確認し、閉じた後や古い文章に対する結果が再表示されないようにする。逆翻訳の出力上限は128 KiBとし、空の結果や失敗はエラー表示にして文書を変更しない。

見直し処理の途中通知には、検証済みの対応箇所だけを渡す。最終応答と同様に要求IDとスナップショットで古い通知を排除する。候補の取得に失敗しても確認済みハイライトは維持する。単語クリックでは対応確認1回と候補要求1回を行い、候補の追加要求は最大1回とする。再取得は明示的な操作で行い、アプリ起動時の要求は追加しない。

### 2026年11月16日の検証

- ハイライト通知の遅延、空の候補の固定化、元と同じ表現だけを返す場合の回帰テストを追加し、修正前の失敗を確認した。逆翻訳のテストでは、編集した訳文、自動言語判定、明示的な言語選択、逐次出力、空の応答・通信失敗・上限超過、文書とUndoの維持、編集・言語や接続の変更・文書の置き換え・閉じた後の古い応答を確認した。
- 通常のバックグラウンドテスト：**220件成功**。
- 固定応答サーバーによるテスト：実際のクライアント通信を含む**220件成功**。
- 別途実行した非表示のネイティブ検証4件が成功した。候補待ち中の両側ハイライト、長い対応範囲でのクリック側の表示位置維持、分割画面・見出し・最小サイズ、原文を折りたたんだ最小サイズの画面での逆翻訳表示を確認した。最後の検証は、修正前に原文が非表示のままになることと訳文の高さがゼロになることを検出した。逆翻訳を開くと原文も表示し、逆翻訳欄の高さは利用可能な領域に合わせて最大210ポイントまで調整するよう修正した。検証ウィンドウは表示せず、キー状態にもしていない。本文の描画画像も端末内で確認した。
- 実行中のアプリとは別の場所でDebugビルドと厳密な署名検証が成功した。

これらは状態管理、入力・応答の検証、通信、検証対象のネイティブ描画を確認するものであり、設定済みモデルの意味の精度や、すべての単語に別訳が存在することを保証しない。実アプリの更新、ポインターと候補画面の動作、実モデルの短文確認は別の受け入れ手順とする。

許可を得て最初に実アプリを更新した際、新しい逆翻訳欄のアクセシビリティ情報を取得するとクラッシュすることが分かった。クラッシュ記録ではSwiftUI／AppKitのアクセシビリティラベル処理が再帰していた。逆翻訳欄は、既存の標準`LanguagePicker`と読み取り専用の`TranslationTextEditor`を再利用する構成に変更し、比較用テキストにはUndoマネージャーを渡さない。非表示のネイティブ回帰テストでは、結果のアクセシビリティ名・値と読み取り専用状態も確認する。外部からのアクセシビリティ情報取得は実アプリで別途確認する。
