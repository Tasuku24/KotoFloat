# Background operation

## English

Command-Q invokes Continue in Background in both the application and menu-bar menus. It hides application UI while retaining in-memory drafts and active translation requests. Translator releases its native window but retains its hosted editor; other windows are ordered out. Pending selection capture is cancelled to prevent a delayed callback from reopening the popup. The existing process, menu-bar item, and registered translation shortcut stay alive; no helper process, login item, or automatic relaunch is added.

Quit KotoFloat remains available in both menus with Option-Command-Q. It uses the standard application termination path and existing unfinished-draft confirmation. System termination requests are not redirected to background operation. Reopen Translator from the menu bar or invoke the translation shortcut to use the app again.

Normal application launch and an application reopen request (for example, opening it again from Finder or Spotlight) show Translator. First launch also opens Translator; its configuration guidance leads to Settings when needed. Reopening reuses the existing editor and document and restores a minimized editor. The registered translation shortcut continues to open the selection-translation popup.

The initial Space fix retained the closed native window, set `moveToActiveSpace` before activating the app, and removed it when the window became key. The user reproduced a forced return to the old Space with that build. This flag-based approach did not reliably override the old native window's Space association and application activation ordering.

The revised implementation releases the native Translator window on user close or Command-Q, while retaining the same hosted editor and shared translation model. Reopening creates a fresh native window, restores its saved frame, and orders it onscreen before requesting application activation. Hidden or minimized native windows are also replaced when explicitly reopened. An already visible editor keeps its native window. There are no temporary Space flags, activation timers, private Space APIs, or changes to system settings.

Command-W is registered as the native `performClose:` action in the File menu. Both popup window types also handle this exact key equivalent locally when key, because a nonactivating popup may retain the source application's menu bar. Extra modifiers do not invoke this shortcut. Existing close cancellation and draft retention semantics remain in use.

Live acceptance: hide Translator on desktop A with Command-Q (also check closing its window), switch to desktop B, then open KotoFloat from Finder or Spotlight. Translator should appear on B with its existing text. Repeat with a minimized editor. Switching actual Spaces, full-screen Spaces, and multiple displays are not established by background tests.

Background tests verify both menu mappings and that an actual termination request with no unfinished draft is allowed. The following isolated native-window check uses transparent, offscreen windows that ignore input and never become key:

```sh
nice -n 10 swift test --jobs 2 --filter PopupControllerTests/backgroundActionHidesWindowsWithoutClosingAndAllowsReopening
```

For other retained windows, it verifies that background operation hides them without close notifications, retains their draft text, and allows the same windows to be displayed again. Real Command-Q handling, the global translation shortcut after hiding, full quit with unfinished work, and logout/shutdown remain live acceptance checks. Routine background tests exclude the native-window suite.

`PopupControllerTests/translatorReopenReplacesSpaceBoundWindowAndRetainsEditorState` separately verifies native-window replacement and hosted-view, source draft, revision, and Undo retention after close and background operation. It neither orders windows onscreen nor activates the application, and does not use the user's frame autosave preferences. The menu and shortcut tests verify native close routing and modifier handling. These checks do not prove physical Space switching or real keyboard dispatch.

## 日本語

アプリメニューとメニューバーメニューのCommand-Qは「バックグラウンドで実行」を呼び出す。画面を非表示にし、メモリ内の下書きと実行中の翻訳要求を保持する。Translatorは標準ウィンドウを解放して編集ビューを保持し、その他のウィンドウは非表示にする。取得完了の通知が後からポップアップを再表示しないよう、進行中の選択文字取得は取り消す。既存のプロセス、メニューバーアイコン、翻訳ショートカットは動作を継続する。補助プロセス、ログイン項目、自動再起動は追加しない。

両メニューの「KotoFloatを終了」はOption-Command-Qで実行できる。標準の終了処理と、既存の未完了下書きの確認を使う。システムからの終了要求をバックグラウンド動作へ変更しない。再利用時はメニューバーからTranslatorを開くか、翻訳ショートカットを呼び出す。

通常のアプリ起動と、FinderやSpotlightなどからの再呼び出しではTranslatorを表示する。初回起動もTranslatorを開き、設定が必要な場合は画面内の案内から設定へ進める。再呼び出しは既存のエディタと文書を再利用し、最小化中なら復元する。登録済みの翻訳ショートカットは引き続き選択文字の翻訳ポップアップを開く。

最初のスペース修正は、閉じた標準ウィンドウを保持し、アプリのアクティブ化の前に`moveToActiveSpace`を設定して、キー状態になった時点で解除していた。利用者はそのビルドで元のスペースへ強制移動する挙動を再現した。このフラグによる方法では、古い標準ウィンドウのスペースへの所属とアプリのアクティブ化の順序を確実に上書きできなかった。

修正版は、閉じる操作またはCommand-QでTranslatorの標準ウィンドウを解放し、同じ編集ビューと共有翻訳モデルを保持する。再表示時には新しい標準ウィンドウを作り、保存済みの枠を復元して、アプリのアクティブ化を要求する前に画面に表示する。非表示または最小化中の標準ウィンドウを明示的に再表示する場合も作り直す。すでに表示されているエディタの標準ウィンドウは維持する。一時的なスペース設定、アクティブ化の待機タイマー、非公開のスペースAPI、システム設定の変更は使用しない。

Command-Wはファイルメニューの標準`performClose:`操作に割り当てる。非アクティブ型ポップアップでは元アプリのメニューバーが維持されるため、両種類のポップアップもキー状態のときに限って同じショートカットを処理する。追加の修飾キーがある場合はこの操作を呼ばない。既存の閉じる際の翻訳取消と下書き保持の処理を使用する。

実機での確認手順：デスクトップAでCommand-Qを押してTranslatorを隠す（ウィンドウを閉じた場合も確認する）。デスクトップBへ移動してFinderやSpotlightからKotoFloatを呼び出し、既存の本文を保持してBに表示されることを確認する。最小化中のエディタでも繰り返す。実際のスペース移動、フルスクリーンのスペース、複数画面での動作は、バックグラウンドテストでは確認できない。

バックグラウンドテストでは、両メニューの割り当てと、未完了の下書きがない場合に実際の終了要求が許可されることを確認する。上記の独立したネイティブウィンドウ検証は、入力を受けずキー状態にならない、画面外の透明なウィンドウを使う。

その他の保持するウィンドウについて、非表示にしても閉じる通知が発生せず、入力した下書きを保持し、同じウィンドウを再表示できることを確認する。実際のCommand-Q、非表示後のグローバル翻訳ショートカット、未完了の編集がある場合の完全終了、ログアウトやシステム終了は、実アプリでの受け入れ確認として残る。通常のバックグラウンドテストではネイティブウィンドウのスイートを除外する。

別の`PopupControllerTests/translatorReopenReplacesSpaceBoundWindowAndRetainsEditorState`では、閉じる操作とバックグラウンドへの移行後に標準ウィンドウが置き換わり、編集ビュー、原文の下書き、リビジョン、Undoを保持することを確認する。画面への表示やアプリのアクティブ化は行わず、利用者のウィンドウ枠の保存先も使用しない。メニューとショートカットのテストでは、標準の閉じる操作への割り当てと修飾キーの扱いを確認する。これらは実際のスペース切り替えや実キー入力の確認を意味しない。
