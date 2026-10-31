# Translation-first popup

## English

The user selected the latest first visual concept: a compact macOS popup with a single top row for the title, target language, copy, editor, and more menu. Implement it without Liquid Glass, blur, new dependencies, or decorative animation. Keep the native close button and existing nonactivating/focus behavior.

Show the streaming translation first. Hide the original completely until explicitly requested, and reset that choice for a new document. Preserve automatic translation after capture, Copy-fallback consent, edited-draft confirmation, incomplete-output copy protection, and the shared editor lifecycle.

Move favorites into the target-language picker while retaining focused Command-1–5 shortcuts. Put source-language selection, retranslation, original visibility, result details, glossary selection/management, manual entry, pinning, and settings in the more menu. Keep stop, failure recovery, changed-input warnings, glossary review warnings, and destructive confirmations visible when relevant. Language changes retain the existing next-request behavior, with an inline retranslation action when the result is stale.

Keep a stable, resizable frame during streaming; do not auto-scroll to the end. Cap the frame at 600 points or 70% of the current display's visible height, whichever is smaller, while retaining the 240-point interactive minimum when the screen permits. Restore and display-change recovery obey the same bound. Only the reading area scrolls; controls and pending confirmations remain outside it. Preserve saved sizes within these bounds.

Background verification excludes native-window tests and live desktop interaction. Visual appearance, actual scrolling/focus, VoiceOver, and AutoRaise remain explicit follow-up checks.

## 日本語

利用者が選んだ最新の1案は、タイトル・翻訳先・コピー・エディタ・その他メニューを上部の1行にまとめたmacOS向けの小さなポップアップである。Liquid Glass、ぼかし、新しい依存ライブラリ、装飾用アニメーションは使わない。標準の閉じるボタンと既存の非アクティブ表示・フォーカス動作を維持する。

逐次受信する訳文を最初に表示する。原文は明示的に要求されるまで完全に隠し、新しい文書では再び非表示にする。取得後の自動翻訳、Copyによる取得の同意、編集済み下書きの確認、未完了訳文のコピー制限、エディタとの共有状態を維持する。

お気に入りを翻訳先の言語選択内へ移し、フォーカス中のCommand-1〜5を維持する。翻訳元言語、再翻訳、原文表示、結果の詳細、用語集の選択・管理、手入力、最前面固定、設定はその他メニューにまとめる。停止、失敗時の復旧、入力変更・用語集の注意、破棄確認は必要時にその場で表示する。言語変更は既存どおり次回リクエストに適用し、結果と異なる場合はその場に再翻訳操作を表示する。

翻訳中はサイズ変更可能な枠を安定させ、末尾へ自動スクロールしない。枠の高さは600ポイントと現在の画面の作業領域の70%の小さい方を上限とし、画面に収まる場合は操作可能な最小高240ポイントを維持する。復元と画面変更時の復旧にも同じ上限を適用する。本文だけをスクロールし、操作部と保留中の確認はその外側に置く。上限内の保存サイズを維持する。

バックグラウンド検証ではネイティブウィンドウテストと実画面操作を除外する。見た目、実際のスクロール・フォーカス、VoiceOver、AutoRaiseは独立した確認として残す。
