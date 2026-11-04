# KotoFloat icon

## English

The adopted design is variant B with the Graphite 05 palette. `KotoFloat-Graphite.vectorcraft` is the editable source, created in VectorCraft from the approved image exploration. The app icon retains the charcoal background, ivory K, bevels, and shadows. Its ten macOS asset-catalog entries cover 16–1024 pixels.

The menu bar uses only the two K outlines, with a transparent background and no shading. `MenuBarIcon.pdf` is an 18-point vector image with a 16-point-high glyph; the app displays it at 16 × 16 points for a more compact mark, retaining the standard menu-bar click area. AppKit treats it as a template so macOS supplies the appropriate light/dark foreground color. The exporter takes the rounded outlines directly from the source's bevel paths, preserving the detached upper arm.

To regenerate the committed exports without opening the desktop app, run the following with your installed `vectorcraft-cli` path:

```sh
nice -n 10 python3 scripts/export_icons.py --vectorcraft-cli /path/to/vectorcraft-cli
```

The application asset catalog belongs to the Xcode app target. The PDF belongs to the KotoFloatKit resource bundle, alongside its localized strings. Exporting does not modify the source document or launch KotoFloat.

Verify the actual built app contains both `Contents/Resources/AppIcon.icns` and `Contents/Resources/KotoFloat_KotoFloatKit.bundle/Contents/Resources/MenuBarIcon.pdf`. A PDF present only in the sibling package bundle beside the app is insufficient. After switching branches that add resources, stale incremental build products may omit a newly added file from the embedded bundle. Use a clean build if this occurs, then run `codesign --verify --deep --strict` on the app before restarting it; manually changing a signed app's embedded resources invalidates its seal.

## 日本語

採用デザインはB案・Graphite 05の配色です。`KotoFloat-Graphite.vectorcraft` は、承認済みの画像案をもとにVectorCraftで作成した編集用データです。アプリアイコンにはチャコールの背景、アイボリーのK、面取り、影を含めます。macOS用アセットカタログの10項目で16〜1024ピクセルに対応します。

メニューバーにはKの2つの輪郭だけを使い、背景は透明、陰影は付けません。`MenuBarIcon.pdf` は18ポイントのベクター画像で、Kの高さは16ポイントです。アプリでは16 × 16ポイントに縮小表示し、クリック領域はメニューバーの標準サイズを維持します。AppKitのテンプレート画像として扱い、macOSがライト／ダーク表示に適した前景色を設定します。出力スクリプトは編集用データの面取りパスから丸み付きの輪郭を直接取得し、右上の腕の隙間を維持します。

デスクトップアプリを開かずに保存済みの出力を再生成する場合は、上記コマンドのパスをインストール済みの `vectorcraft-cli` の場所に置き換えて実行してください。

アプリ用アセットカタログはXcodeのアプリターゲットに、PDFは翻訳文字列と同じKotoFloatKitのリソースバンドルに含まれます。出力処理は編集用データを変更せず、KotoFloatも起動しません。

ビルドしたアプリ本体に、上記のアプリアイコンとメニューバーPDFの両パスが存在することを確認してください。アプリと並んだパッケージバンドルにPDFがあるだけでは不十分です。リソースを追加するブランチへ切り替えた後、古い差分ビルドの生成物により新しいファイルがアプリ内へ入らない場合があります。その場合はクリーンビルドし、再起動前に上記コマンドで署名を確認します。署名済みアプリの内部リソースを手動で変更すると署名の検証に失敗します。
