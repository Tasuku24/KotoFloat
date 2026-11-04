# Popup manual height

## English

The popup initially fits its content up to the existing height limit. A manual vertical resize overrides automatic fitting until the next popup invocation. Further translation updates and screen recovery preserve that height, subject to screen bounds. Overflow remains scrollable. A width-only resize does not disable automatic fitting.

Run the isolated native-window regression separately from background tests:

```sh
nice -n 10 swift test --jobs 2 --filter PopupControllerTests/manualHeightSurvivesReleaseStreamingAndScreenRecovery
```

The test uses transparent windows that ignore mouse events and never become key, in both standard and AutoRaise-compatible modes. It simulates resize delegate callbacks and checks retained height after release, streaming completion, and screen recovery; scrollable overflow; and restored automatic fitting after a new capture and width-only resize. It does not verify physical mouse dragging or external AutoRaise behavior.

## 日本語

ポップアップは初期状態では既存の高さ上限まで内容に合わせて伸縮する。手動で縦サイズを変更すると、次にポップアップを呼び出すまで自動調整よりもその高さを優先する。翻訳結果の追加や画面内への位置補正でも、画面の範囲内で高さを維持する。収まらない内容はスクロールできる。横幅だけの変更では自動調整を無効にしない。

上記のネイティブウィンドウ回帰テストは、通常のバックグラウンドテストとは分けて実行する。

テストは通常モードとAutoRaise互換モードで、マウス入力を受けずキー状態にならない透明なウィンドウを使用する。サイズ変更のデリゲート通知を模擬し、操作終了・翻訳完了・画面内補正後の高さ維持、内容のスクロール、新しい取得と横幅だけの変更後の自動調整を確認する。物理的なマウスドラッグや外部AutoRaiseの動作は検証しない。
