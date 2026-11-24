# Translator sentence review and alternatives

## English

For back translation and progressive highlighting/candidate fixes, see [Translator improvements](translator-improvements-2026-11-16.md). For the real-model correspondence repair, see [November 17 alignment verification](translation-alignment-2026-11-17.md).

Completed Translator documents support clicking a passage to highlight the corresponding source/translation spans. Clicking a translated word also opens a native alternatives popover. A chosen alternative asks the configured translation server to rewrite the matched passage naturally, then applies that complete passage through the existing translation-edit path. The surrounding document remains byte-for-byte unchanged, and one Undo restores the previous result.

### Ownership and requests

- `TranslationReviewDocument` uses macOS NaturalLanguage sentence and word tokenization, with UTF-16 ranges for AppKit. The configured model translates only non-English sentences into English using app-owned JSON keys. Existing English text remains local. `TranslationSentenceAlignment` compares these projections with macOS English sentence embeddings, checks numbers, negation, and recognized names, and rejects close competing matches. It can match a contiguous group of up to eight sentences. The model never chooses sentence IDs. Bounded, contiguous, anchored IDs are validated before highlighting or editing; reordered sentences are never paired by position.
- `TranslationReviewModel` owns transient selection, at most 32 cached responses, and auxiliary request cancellation. The shared `TranslationModel` remains the document/Undo owner. Document ID, revision, direction, connection revision, and glossary revision reject obsolete replies. Source edits, output edits, retranslation, and Undo invalidate review state. Dismissing the popover cancels pending auxiliary work without changing the result.
- `OpenAITranslationClient` reuses authenticated requests, redirect rejection, timeouts, SSE completion validation, and error mapping. Ordinary translation remains a plain streamed result. Explicit inspection first requests correspondence; a target-word click then requests alternatives using only the matched passages and word context. A failed candidate request retains valid correspondence. Choosing a candidate requests a rewrite. Networked auxiliary requests send JSON data to the same configured model/server; correspondence and alternatives return JSON, while a rewrite returns one plain-text passage; correspondence is computed locally. English-only inspection skips the projection request. They do not run on app launch or on every keystroke. Source and target passages plus context and the request glossary are data, never instructions.
- Review is available after a completed translation when its source, language, connection, and glossary still match. Requests bound source and target text to 128 KiB each, combined message content to 384 KiB, English-projection responses to 128 KiB, candidate/rewrite responses to 32 KiB, and a replacement passage to 16 KiB. A rewrite sends only the matched passages, selected occurrence, chosen wording, and glossary. It does not send the full source/target documents. An invalid response, missing chosen wording, copied unmatched sentence, changed paragraph structure, or stale document leaves the existing translation intact.

### UI

Sentence highlights use temporary text-layout attributes, leaving text storage, native selection, copying, and Undo untouched. Only the counterpart scrolls into view when its highlighted range changes; the clicked pane keeps its viewport stable, including when a long passage is matched. The word popover is attached to the clicked text and sizes to its contents. The pane header reserves a fixed progress slot, so loading feedback does not insert a row above the text.

The standard context menu, the Edit menu's Option-Command-Return action, and a VoiceOver custom action can inspect the caret location. Dragging, modified clicks, marked-text composition, and multi-click events keep native handling. Candidate buttons have native accessibility labels and help. Escape/Close dismisses the popover. Source clicks request correspondence without a word-candidate popover. An uncertain correspondence produces an unavailable-match notice. If the macOS English embedding is unavailable, a localized error explains that sentence comparison is unavailable; the app does not guess by position.

### Verification

Routine background tests cover multilingual/UTF-16 segmentation, reordered and merged sentence IDs, invalid mappings, bounded/deduplicated candidates, request isolation, complete and malformed SSE responses, chosen-word/line-break validation, cache reuse, exact outside-passage preservation, copied edits, Undo/Redo, and stale replies after newer clicks, edits, language/server changes, document replacement, or dismissal.

Run the non-visible editor integration separately:

```sh
nice -n 10 swift test --jobs 2 --filter 'PopupControllerTests/(reviewActionHighlightsBothNativeEditorsWithoutChangingTextOrSelection|reviewKeepsClickedViewportStableWhenMatchedPassageIsLong)'
```

These tests invoke the real native editor review action and verify temporary highlighting in both text views, unchanged text/selection/history, highlight removal after a source edit, and viewport stability while highlighting a long merged passage. They neither display a window nor change desktop focus.

The opt-in real-model sample sends only synthetic text:

```sh
KOTOFLOAT_USE_SAVED_SERVER=1 KOTOFLOAT_REVIEW_REPORT="$PWD/.build/translation-review/model-review-output.json" nice -n 10 swift test --jobs 2 --filter 'LocalModelIntegrationTests/(actualModelProvidesContextualAlternativesAndRewritesThePassage|actualModelAlignsReorderedSentences)'
```

On November 17, the saved `hy-mt2-7b` model passed 22 synthetic alignment cases through the production client and three separate review/rewrite samples. See the dated report for commands and evidence. These samples do not establish general semantic accuracy. Actual pointer interaction, popover placement, keyboard navigation, VoiceOver, IME, and light/dark appearance require separate live acceptance checks. English projection quality and candidate/rewrite quality remain model-dependent.

## 日本語

逆翻訳と、ハイライトの逐次通知・候補取得の改善については[Translatorの改善](translator-improvements-2026-11-16.md)、実モデルの対応付け修正については[11月17日の検証](translation-alignment-2026-11-17.md)を参照。

完成したTranslatorの文章をクリックすると、対応する原文・訳文の範囲をハイライトする。訳文の単語をクリックすると標準の別訳候補ポップオーバーも表示する。候補を選ぶと設定済み翻訳サーバーに対応部分の自然な書き直しを要求し、完成した文章だけを既存の訳文編集経路で反映する。対象範囲外の文章は完全に維持し、1回のUndoで元に戻せる。

### 状態と通信の管理

- `TranslationReviewDocument`はmacOSのNaturalLanguageで文・単語を分割し、AppKit用にUTF-16の範囲を保持する。設定済みモデルには、アプリが付けたJSONキーを維持し、英語以外の文だけを英訳させる。既存の英語本文は端末内で保持する。`TranslationSentenceAlignment`がmacOSの英語文埋め込みで比較し、数字・否定・認識できた固有名詞を検査する。競合する候補が近い場合は対応不明にし、最大8文の連続範囲にも対応する。モデルには文IDの選択を任せない。連続性・上限・クリック位置を含むことを検証してから表示・編集する。文の順序が入れ替わっていても、同じ位置だから対応すると推測しない。
- `TranslationReviewModel`は一時的な選択状態、最大32件の応答キャッシュ、補助要求の取り消しを管理する。文書とUndoは共有の`TranslationModel`が管理する。文書ID、リビジョン、言語方向、接続設定・用語集のリビジョンで古い応答を排除する。原文・訳文の編集、再翻訳、Undoで見直し状態を無効にする。ポップオーバーを閉じると進行中の補助処理を取り消し、本文を変えない。
- `OpenAITranslationClient`の認証、転送拒否、タイムアウト、SSE完了検査、エラー変換を再利用する。通常の翻訳は従来どおり訳文を逐次受信する。明示的な操作時にまず対応確認を行い、訳文の単語クリック時は一致した範囲と単語の文脈だけで候補を取得する。候補の取得に失敗しても、確認済みの対応は維持する。候補を選ぶと書き直しを要求する。通信する補助要求はJSONデータを同じ設定済みモデルとサーバーへ送信する。対応用の英訳と候補はJSON、書き直しは対象部分だけのプレーンテキストで受信し、対応判定は端末内で行う。両側が英語の場合は英訳要求を省く。アプリ起動や文字入力のたびには要求しない。原文・訳文・文脈・送信時の用語集はすべてデータとして扱い、内部の指示には従わない。
- 翻訳完了後、原文・言語・接続設定・用語集が結果と一致している場合に利用できる。原文・訳文はそれぞれ128 KiB、メッセージ全体は384 KiB、対応判定用の英訳応答は128 KiB、候補・書き直し応答は32 KiB、置換する文章は16 KiBを上限とする。書き直し要求は対応する原文・訳文、選択位置、指定表現、用語集だけを送信し、原文・訳文の全文は含めない。不正な応答、指定した表現の欠落、対象外の文のコピー、段落構造の変更、古くなった文書に対しては、既存の訳文を維持する。

### 操作画面

ハイライトは文字レイアウトの一時属性を使い、本文データ・標準の選択範囲・コピー・Undoを変えない。対応する範囲が変わった場合は、反対側の文章だけが見えるようにスクロールする。長い範囲が対応していても、クリック側の表示位置は維持する。単語の候補画面はクリックした文章に付け、内容に合わせた大きさにする。見出し内に進捗表示用の固定領域を確保し、本文の上にローディング行を追加しない。

標準のコンテキストメニュー、編集メニューのOption-Command-Return、VoiceOverのカスタム操作からもカーソル位置を確認できる。ドラッグ、修飾キー付きクリック、変換中の文字入力、複数回クリックのイベントは標準の処理を維持する。候補には標準のアクセシビリティ名と説明を付ける。Escapeまたは閉じるボタンで候補画面を閉じられる。原文のクリックは対応確認だけを行い、単語候補画面は開かない。対応が不確かな場合は対応不明の通知を出す。macOSの英語文埋め込みを利用できない場合は、文の比較を利用できない旨のエラーを表示する。文の位置だけで推測しない。

### 検証

通常のテストでは、多言語・UTF-16の区切り、並べ替え・結合された文ID、不正な対応、候補の上限・重複排除、要求の分離、正常・不正なSSE応答、指定表現・改行の検査、キャッシュ、対象外の文章の維持、編集結果のコピー、Undo／Redo、新しいクリック・編集・言語や接続の変更・文書の置き換え・候補画面を閉じた後の古い応答の排除を確認する。

非表示のエディタ連携テストは上記コマンドで別途実行する。実際の標準エディタの操作を呼び出し、両方の文字ビューへの一時ハイライト、本文・選択範囲・履歴の維持、原文編集後のハイライト解除、長い結合範囲をハイライトしたときの表示位置の維持を確認する。ウィンドウの表示やデスクトップのフォーカス変更は行わない。

11月17日には保存済みの`hy-mt2-7b`と本番クライアントで対応付け22ケース、別途見直し・書き直し3件を確認した。コマンドと証跡は日付付きの検証記録を参照。これらで全般的な意味の正確さを確認したとは扱わない。実際のポインター操作、候補画面の位置、キーボード操作、VoiceOver、IME、ライト／ダーク表示は別途実機で確認する。英訳と候補・書き直しの品質はモデルに依存する。
