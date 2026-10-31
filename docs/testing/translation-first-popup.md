# Translation-first popup verification

## English

Date: 2026-11-01. Branch: `feature/translation-first-popup`.

The popup now presents the translation first, with a solid top toolbar and native close button. Original text and result details are opt-in and reset for each new document. Existing source-language, glossary, retranslation, pinning, manual-entry, and settings actions remain reachable through the more menu; editor actions retain the shared model and existing draft confirmations. No Liquid Glass, blur, dependencies, or decorative animation were added.

### Background proof

- `nice -n 10 swift test --jobs 2 --skip PopupControllerTests`: 134 tests in 22 suites passed.
- `nice -n 10 xcodebuild -project KotoFloat.xcodeproj -scheme KotoFloat -configuration Debug -derivedDataPath .build/validation -jobs 2 build`: succeeded.
- Both localization files parse; their 244 keys match. `git diff --check` passed.
- Added regression coverage for a 600-point cap, a 70% display cap across restoration/pointer/selection placement, tiny displays, preserved pointer spacing after limiting height, and favorite ordering without duplicates or excluded/search-mismatched entries.
- Added model-backed presentation tests for source-language, target-language, and glossary changes during an active stream. The stale-input notice takes precedence over progress text without starting another request.
- Review corrected recovery controls scrolling out of view: the compact status/recovery row and pending confirmation now remain outside the reading scroller. Full explanations remain available through result details.

The frame remains stable during streaming and retains the saved size within the new bounds. A 240-point interactive minimum takes precedence over the 70% cap on short displays when it fits; screens shorter than that use their available height. No automatic scroll-to-end is installed. These are code/geometry checks, not proof of live visual or scrolling behavior.

### Remaining explicit desktop acceptance

- Native close button alignment, dragging, target-picker width, and toolbar access at 360-point width in both window modes and light/dark appearance.
- Long translation scrolling, stable reading position during streaming, pinned stop/retry/settings and confirmation actions, and resizing across displays.
- Original/details reset on a new capture, Copy-fallback consent, edited-draft replacement, manual entry, and shared editor interaction in the running app.
- Real Japanese IME, full keyboard traversal, VoiceOver announcements, and AutoRaise interaction.

The initial background verification did not launch or restart KotoFloat. The user's `.build/xcode` app and saved preferences were not replaced. No new real-server/model-quality or performance benchmark is claimed.

### Authorized restart and icon integration

After the user requested a restart and reported missing icons, the approved Graphite app icon and outline K menu mark were integrated from `964b1b8` as `afde63c`. The background suite still passed all 134 tests. A fresh Debug build embedded the PDF correctly; stale incremental products at the existing output path had omitted it from the app despite producing the sibling package bundle. A clean Release build resolved the stale copy and signature. The final app contains `AppIcon.icns` and a byte-identical `MenuBarIcon.pdf` inside its embedded package bundle, passes strict signature verification, and loads the PDF as an 18-point template image. The same Release app path was restarted after graceful termination, preserving preferences. The process was verified running. On-screen menu-bar glyph appearance was not independently captured; this does not close the popup's broader desktop acceptance list.

## 日本語

日付: 2026-11-01。ブランチ: `feature/translation-first-popup`。

通常の背景の上部操作列と標準の閉じるボタンを使い、ポップアップは訳文を最初に表示する。原文と結果詳細は明示的に開き、新しい文書では非表示に戻す。翻訳元・用語集・再翻訳・最前面固定・手入力・設定はその他メニューに残し、エディタは共有モデルと既存の下書き確認を維持する。Liquid Glass・ぼかし・依存ライブラリ・装飾アニメーションは追加していない。

### バックグラウンドでの確認

- 英語節に記載した通常テストで、22スイート・134テストが成功した。
- 指定の別出力先へのDebugビルドが成功した。
- 両言語ファイルの構文と244キーの一致、差分の空白チェックを確認した。
- 高さ600ポイント・画面70%の制限、復元／カーソル／選択付近への配置、小画面、高さ縮小後のカーソル間隔、お気に入りの順序・重複・除外・検索を回帰テストした。
- 翻訳中の翻訳元・翻訳先・用語集変更について、実際のモデルを使う表示判定テストを追加した。追加要求を送らず、進捗より条件変更の注意を優先する。
- レビューで、復旧操作が本文と一緒に画面外へ流れる点を修正した。簡潔な状態・復旧操作と保留中の確認は本文のスクロール領域の外に置き、詳しい説明は結果詳細から開く。

翻訳中は枠を伸縮させず、上限内の保存サイズを維持する。小画面で収まる場合は操作可能な最小高240ポイントを70%制限より優先し、それより小さい画面では利用可能な高さに収める。末尾への自動スクロールは追加していない。これらはコードと配置計算の確認であり、実画面の見た目やスクロールを確認したものではない。

### 独立した実画面の残確認

- 両ウィンドウ方式・明暗表示で、閉じるボタンの位置、ドラッグ、言語選択の幅、最小幅360ポイントでの操作。
- 長文のスクロール、翻訳中の読んでいる位置、固定された停止・再試行・設定・確認操作、画面間移動とサイズ変更。
- 実アプリでの新規取得後の原文・詳細の初期化、コピー取得の同意、編集中の置換確認、手入力、エディタとの連携。
- 日本語IME、全操作のキーボード移動、VoiceOverの読み上げ、AutoRaiseとの連携。

初回のバックグラウンド検証ではKotoFloatの起動・再起動は行っていない。利用者の `.build/xcode` のアプリと保存設定は置き換えていない。新たな実サーバー・翻訳品質・性能計測の確認済みとはしない。

### 許可された再起動とアイコン統合

利用者の再起動依頼とアイコン未反映の報告を受け、採用済みのGraphiteアプリアイコンと輪郭Kを `964b1b8` から `afde63c` として統合した。バックグラウンドテストは引き続き134件が成功した。新しい出力先でのDebugビルドではPDFを正しく同梱できたが、既存出力先の古い差分生成物では、隣接するパッケージバンドルにPDFがあってもアプリ内部には入っていなかった。Releaseのクリーンビルドで古いコピーと署名を更新した。最終アプリ内の `AppIcon.icns` と、元データに一致する内包バンドルの `MenuBarIcon.pdf`、厳密な署名検証、18ポイントのテンプレート画像としての読み込みを確認した。正常終了後、設定を維持して同じReleaseアプリのパスから再起動し、動作中のプロセスを確認した。メニューバー上の実際の字形は独立した画像として取得できておらず、ポップアップ全体の実画面の残確認を完了したものではない。
