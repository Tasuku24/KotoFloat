# Real-model sentence correspondence repair — November 17, 2026

## English

### Diagnosis

The saved `hy-mt2-7b` server repeatedly paired “これはとても便利なツールです。” with “It saves time.” instead of “This is a useful tool.” Requesting exact quotations, reordering candidates, and constraining JSON choices did not reliably fix selection. A constrained-choice probe passed only 12 of 16 synthetic cases, including false matches for unrelated text and missing negation/numbers. Plain English translation of the selected Japanese sentence was correct. These observations concern this configured model and samples, not all translation models.

### Implementation

`OpenAITranslationClient` now asks the configured server only to translate non-English values into English, preserving app-owned JSON keys. Original English sentences stay local. `TranslationSentenceAlignment` uses a separate native English `NLEmbedding` instance per scoring task and compares those projections locally. Sentence IDs and AppKit ranges come exclusively from the original document. No new model downloads, endpoint changes, or structured-output API capability are required.

Numbers (including English number words), negation, and recognized personal/place/organization names must agree. The nearest candidate must be within distance 0.75 and separated from competing non-containing spans by at least 0.15. Candidates within 0.05 of the nearest distance prefer the shortest span. Up to eight contiguous counterpart sentences are considered around the four strongest individual candidates, allowing merged translations without comparing every possible document span. This is a conservative heuristic, not proof of semantic equivalence. Duplicate or ambiguous passages remain unavailable rather than being paired by position. An unavailable native English embedding produces a localized error.

The projection response must contain exactly the requested keys and nonempty values, with a total 128 KiB limit. Invalid, canceled, or obsolete results cannot change the document. Local scoring runs outside the main actor and checks cancellation. The existing review model still owns transient state; the shared translation model still owns document edits, Undo, and history. Valid correspondence is published before requesting alternatives, and a candidate failure retains the highlights.

### Verification

- `python3 scripts/test_with_mock_server.py`: 229 background tests passed, including the production transport fixtures, cancellation, invalid keys, stale replies, alternatives, rewrite/Undo, and back translation.
- Local alignment regression: 20 synthetic rows plus Japanese counterpart-key validation and reverse/UTF-16 anchoring passed. This includes compound number words with and without hyphens, signed numbers, missing counterparts, competing paraphrases, merged sentences, and duplicate ambiguity.
- Production client with saved `hy-mt2-7b`: all 22 alignment cases passed, covering both language directions, candidate order, opposite actions, negation, numbers, merged sentences, unrelated text, names, units, subjects, time, source-side inspection, duplicate ambiguity, and commands treated as data.
- Four separate actual-model tests passed: automatically detected source review, alternatives plus passage rewrite, selected-sentence rewrite scope (three repetitions), and reordered sentences.
- Four offscreen native editor tests passed: paired highlights, stable clicked viewport, split layout, and back translation at minimum window size. They did not show windows or change desktop focus.
- Debug build and strict signature validation passed in the separate `.build/validation/translator-improvements-20261116` candidate directory. The installed validation app was updated with the previous bundle retained under `.build/validation/app-backups/20261117-050814-before-alignment-fix`.

Real-model reproduction uses synthetic text only:

```sh
KOTOFLOAT_USE_SAVED_SERVER=1 KOTOFLOAT_ALIGNMENT_REPORT="$PWD/.build/translator-investigation-20261117/production-corpus.json" nice -n 10 swift test --jobs 2 --filter actualModelAlignsSentencesLocally
```

Diagnostic reports are local ignored build artifacts. No credentials are included. The model's English projection and alternative/rewrite quality remain limitations; 22 passing cases do not establish general translation accuracy. Live pointer, accessibility, and visual checks are recorded separately from background verification.

### Live acceptance and rewrite follow-up

After unlocking the Mac, the native review action highlighted only “This is a useful tool.” and its Japanese translation, and displayed five alternatives. Applying a candidate exposed another model failure: the rewrite echoed the next sentence and duplicated it in the assembled document. Undo restored the test text. An actual-client regression reproduced the duplicate on all three attempts.

Rewrite requests now contain only the matched passages, clicked occurrence, preferred wording, and glossary. They omit the complete source/target documents. Validation rejects copied unmatched target sentences. The narrowed JSON response also exposed malformed model output using a Japanese closing quotation mark. Since a rewrite contains just one passage, it now uses the existing plain-text transport rather than requiring a JSON wrapper. The chosen-word, size, paragraph, stale-document, and outside-passage checks remain. Three repeated actual-model rewrites then passed, along with the four broader real-model tests and all 229 background tests. The additional build was deployed after strict signature verification, retaining the previous bundle under `.build/validation/app-backups/20261117-154305-before-rewrite-scope-fix`. In the updated live app, selecting the “役立つツールです。” candidate changed only the first sentence; “時間を節約してくれます。” remained once. Undo restored the original. Back translation then displayed “This is a very useful tool. It helps me save time.” while leaving both original panes intact. Accessibility inspection remained responsive. Review was exercised through the standard Option-Command-Return action; a direct coordinate click returned the automation error `noWindowsAvailable`, so physical pointer behavior is not claimed as verified. This repair does not claim to validate every semantic change or paraphrased duplication.

References: [Tencent model card and JSON translation examples](https://huggingface.co/tencent/Hy-MT2-7B), [Apple text similarity](https://developer.apple.com/documentation/naturallanguage/finding-similarities-between-pieces-of-text), [Apple NLEmbedding](https://developer.apple.com/documentation/naturallanguage/nlembedding).

## 日本語

### 原因の調査

保存済みの`hy-mt2-7b`サーバーは、「これはとても便利なツールです。」に対し、「This is a useful tool.」ではなく「It saves time.」を繰り返し選んだ。原文の引用、候補順の変更、JSONで選択肢を制約する方法でも安定しなかった。選択肢を制約した試験は16ケース中12ケースの成功にとどまり、無関係な文や否定・数字が一致しない文も誤って対応させた。一方、選択した日本語の単純な英訳は正しかった。これは設定済みのモデルと試験例についての観察であり、すべての翻訳モデルについての結論ではない。

### 実装

`OpenAITranslationClient`は、設定済みサーバーに英語以外の値だけを英訳させ、アプリが付けたJSONキーを保持させる。元から英語の文は端末内で保持する。`TranslationSentenceAlignment`は処理ごとに独立した標準の英語`NLEmbedding`を使い、英語に揃えた文章を端末内で比較する。文IDとAppKitの範囲は元の文書だけから決定する。新しいモデルのダウンロード、接続先の変更、構造化出力APIの対応は不要。

数字（英単語表記を含む）、否定、認識できた人名・地名・組織名が一致する必要がある。最も近い候補の距離は0.75以下で、包含関係にない競合範囲とは0.15以上の差を必要とする。最短距離から0.05以内の候補では短い範囲を優先する。上位4つの単文の周辺で、最大8文の連続範囲を調べる。これにより、文書全体の範囲を総当たりせずに結合された訳文にも対応する。これは慎重な判定規則であり、意味の同一性の証明ではない。重複や曖昧な文章は位置だけで結び付けず、対応不明とする。標準の英語文埋め込みを利用できない場合は日本語・英語のエラー表示を用意する。

英訳応答には要求したキーが過不足なく存在し、値が空でなく、合計128 KiB以内であることを求める。不正・取り消し・古い応答は文書を変更できない。端末内の比較はメインアクターの外で行い、取り消しを確認する。一時状態は既存の見直しモデルが管理し、文書編集・Undo・履歴は共有の翻訳モデルが引き続き管理する。候補取得前に有効な対応箇所を通知し、候補の取得に失敗してもハイライトを維持する。

### 検証

- 固定応答サーバーを使うバックグラウンドテスト229件が成功。本番の通信経路、取り消し、不正キー、古い応答、候補、書き直し・Undo、逆翻訳を含む。
- 端末内比較の回帰テストは20例に加え、日本語側のキー検証と逆方向・UTF-16の範囲検証が成功。ハイフンの有無を含む英語の数詞、符号付き数字、対応先の欠落、似た言い換えの競合、結合文、重複の曖昧さを含む。
- 保存済み`hy-mt2-7b`と本番クライアントによる対応付け22ケースがすべて成功。日英両方向、候補順、反対の動作、否定、数字、結合文、無関係な文、人名、単位、主語、時刻、原文側からの確認、重複、命令文をデータとして扱う場合を含む。
- 自動判定の原文、候補取得と文章の書き直し、選択文だけの書き直し（3回反復）、並べ替えられた文の、実モデルテスト4件も成功。
- 非表示の標準エディタ検証4件が成功。両側ハイライト、クリック側の表示位置維持、分割画面、最小サイズでの逆翻訳を確認。ウィンドウの表示やフォーカス変更は行っていない。
- 実行中アプリと別の候補ディレクトリでDebugビルドと厳密な署名検証が成功。検証用アプリを更新し、更新前のアプリは上記`app-backups`に保持した。

実モデルの再現コマンドは英語版のとおりで、テスト用の短文だけを送信する。診断記録はGit管理外のローカルビルド生成物に保存し、認証情報を含めない。英訳、別訳候補、書き直しの品質はモデルに依存し、22ケースの成功で翻訳全般の正確さを確認したとは扱わない。実際のポインター操作、アクセシビリティ、見た目はバックグラウンド検証と区別して記録する。

参照先は英語版に記載したTencentのモデルカードとJSON翻訳例、Appleの文章類似度・NLEmbeddingの公式資料。

### 実画面の確認と書き直しの追加修正

Macのロック解除後、標準の見直し操作で「This is a useful tool.」と対応する日本語だけがハイライトされ、別訳5候補が表示された。候補を適用すると、モデルが次の文まで返し、文書に重複する問題が見つかった。テスト文はUndoで復元した。実クライアントの回帰テストでも3回すべて再現した。

書き直し要求は、対応する原文・訳文、選択位置、指定表現、用語集だけに絞り、原文・訳文の全文を送らない。対象外の訳文をコピーした応答も検証で拒否する。要求を絞った後は、モデルがJSONの閉じ引用符を日本語の括弧に変える問題も確認した。書き直し結果は文章1つなので、JSONの包みを要求せず既存のプレーンテキスト通信を使う形に簡略化した。指定表現、サイズ、段落、古い文書、対象範囲外の維持に関する検査は維持する。実モデルでの3回反復、より広い実モデルテスト4件、バックグラウンド229件が成功した。追加修正版も厳密な署名検証後に反映し、直前のアプリは`app-backups/20261117-154305-before-rewrite-scope-fix`に保持した。更新後の実画面で「役立つツールです。」を選ぶと最初の文だけが変わり、「時間を節約してくれます。」は1回だけ残った。Undoで元に戻り、逆翻訳では「This is a very useful tool. It helps me save time.」を表示した。原文・訳文は維持され、アクセシビリティ情報の取得も継続できた。見直し操作は標準のOption-Command-Returnで確認した。座標クリックは操作ツールの`noWindowsAvailable`エラーとなったため、実際のポインター操作は確認済みと扱わない。すべての意味の変化や、言い換えられた重複まで検証できるとは扱わない。
