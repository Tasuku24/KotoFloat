# Automatic translation after popup language selection

## English

Selecting a different target language in the popup starts translation immediately. The source-language menu and focused Command-1–5 favorites use the same action. Selecting the current language or an invalid automatic target sends nothing. The shortcut remains local to its own key window and ignores key repeats.

`TranslationModel.changePopupLanguages` updates preferences and delegates to the existing `translateSource` lifecycle only while the popup displays captured content. Manual entry, capture progress, and capture confirmation update the preferred languages without retranslating hidden previous text. Ordinary preference changes, Translator language selection, and language swaps retain their existing explicit-send behavior; no global preference observer is added.

The model cancels superseded requests and rejects their late output. Edited translations retain the existing replacement confirmation. Empty/whitespace-only and oversized input do not send. Retry remains available for failed requests; changing language no longer requires it.

Background tests cover source/target changes after completion, rapid changes during streaming, same-language selection, invalid input, edit confirmation, and capture/manual states. These use an isolated fake service and do not establish real-server translation quality or live keyboard acceptance.

## 日本語

ポップアップで別の翻訳先言語を選ぶと、すぐに翻訳を開始する。翻訳元言語のメニューと、フォーカス中の⌘1〜⌘5のお気に入りにも同じ操作を適用する。現在と同じ言語や、翻訳先として無効な自動判定を選んでも送信しない。ショートカットは自分のキーウィンドウ内だけで動作し、キーリピートは無視する。

`TranslationModel.changePopupLanguages`は設定を更新し、ポップアップが取得済みの内容を表示している場合だけ、既存の`translateSource`へ処理を渡す。手入力中、取得中、取得内容の確認待ちでは、希望する言語だけを変更し、画面に出ていない前の文章は再翻訳しない。通常の設定変更、Translatorでの言語選択、言語の入れ替えは既存の明示的な送信動作を維持し、全体の設定変更監視は追加しない。

モデルは古いリクエストを取り消し、遅れて届いた応答を反映しない。編集済みの訳文には既存の上書き確認を維持する。空白のみの原文やサイズ上限を超える原文は送信しない。失敗時の再試行は引き続き利用できるが、言語の切り替え時には不要になる。

バックグラウンドテストは、完了後の翻訳元・翻訳先変更、翻訳中の連続変更、同じ言語の選択、不正な入力、編集内容の確認、取得・手入力の各状態を確認する。独立したテスト用サービスを使用しており、実サーバーの翻訳品質や実際のキーボード操作の動作確認を意味するものではない。
