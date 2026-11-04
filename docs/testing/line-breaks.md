# Preserve translation line breaks

## English

The reported live Translator showed list items already concatenated in its source editor. This establishes a loss before translation for that example; it is not only a result-rendering issue. The request encoder, SSE decoder, model accumulation, text editors, and result-copy path otherwise retain newline characters.

After accessibility provides a nonempty selection, try the application's native Copy to retain its paragraph separators. Reuse the existing clipboard snapshot/restoration and interruption checks. If copied text equals the accessibility selection except for whitespace, classify it as a verified copy and translate automatically. If non-whitespace content differs, use the existing copy confirmation rather than silently sending a different selection. If copying is unavailable or times out, retain the known accessibility text; source switches, input interruption, and concurrent clipboard changes still fail closed. Empty selections continue to use the separately authorized clipboard fallback.

The translation instruction now explicitly preserves line breaks, blank lines, indentation, headings, and separate list items. Keep the entire document in one request for context; do not guess where to insert breaks into a flattened translation or split it into many requests. A model can still disregard instructions, so fixture tests alone do not prove model compliance.

Regression coverage includes a flattened accessibility selection restored from native-copy text, automatic translation of equivalent copies, confirmation for mismatched copies, copy failure/interruption, untouched multiline request bodies, newline-only streaming chunks, CRLF split across chunks, and exact multiline result copying to a named test pasteboard. The opt-in `LocalModelIntegrationTests/actualTranslationPreservesParagraphsAndListLines` sends synthetic text to the saved server and writes its output only when `KOTOFLOAT_LINE_BREAK_REPORT` is explicitly supplied.

The saved-server check passed on 2026-11-03: one Japanese-to-English sample retained all six lines, including two blank lines and two bullet items. It took approximately 163 seconds. This confirms that sample, not every model or input. Live recapture of the original rich-text selection remains a separate check.

## 日本語

報告時のTranslator実画面では、原文欄の時点で箇条書きが連結されていた。この例では翻訳前に区切りが失われており、訳文の表示だけの問題ではない。リクエストの変換、SSEの解析、モデルの受信内容の連結、テキスト表示、訳文コピーの経路は改行文字を保持している。

アクセシビリティで空でない選択文字を取得した後、アプリ標準のコピーで段落の区切りを保持する。既存のクリップボードの保存・復元と操作中断の検査を再利用する。コピーした文章が空白以外でアクセシビリティの選択文字と一致する場合、検証済みのコピーとして自動翻訳する。空白以外が異なる場合は、異なる文章を黙って送信せず、既存のコピー確認を使う。コピーが利用できない場合や時間切れでは取得済みの選択文字を維持し、取得元の切り替え・操作中断・同時コピーの検出時はエラーとする。未選択の場合は、別途承認されたクリップボードからの取得を引き続き使用する。

翻訳指示に、改行、空行、字下げ、見出し、箇条書きの区切りを維持することを明記する。文脈を保持するため文書全体を1回のリクエストで送り、連結された訳文に改行位置を推測して足したり、多数のリクエストに分割したりしない。モデルが指示に従わない可能性は残るため、固定応答のテストだけではモデルの遵守を確認したことにはならない。

回帰検証には、アクセシビリティで連結された選択文字を標準コピーの文章から復元すること、一致する文章の自動翻訳、不一致時の確認、コピー失敗・中断、複数行の送信内容の維持、改行のみの受信、分割されたCRLF、専用のテスト用クリップボードへの改行付き訳文の完全なコピーを含む。任意の`LocalModelIntegrationTests/actualTranslationPreservesParagraphsAndListLines`は保存済みのサーバーへテスト文章を送り、`KOTOFLOAT_LINE_BREAK_REPORT`を明示した場合だけ出力を保存する。

2026年11月3日の保存済みサーバーの確認は成功した。日本語から英語への1件で、空行2行と箇条書き2項目を含む全6行が維持された。所要時間は約163秒。この結果は確認した文章についてのもので、すべてのモデルや入力を保証しない。元の書式付き文章を実画面で再取得する確認は別途必要である。
