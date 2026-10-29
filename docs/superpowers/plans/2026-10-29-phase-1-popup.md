# Phase 1: App foundation and popup / 第1段階：アプリの土台とポップアップ

## English

### Scope and decisions

Implement Phase 1 only, using fixed sample text. No selected-text capture, network requests, glossary storage, or translation editor yet. Target macOS 15+, Swift 6, SwiftUI content inside an AppKit nonactivating NSPanel. Keep the requested checkout at `/Users/s26037/Developer/KotoFloat` on `feature/phase-1-popup`.

Use a root Swift package for VS Code completion, builds, and tests, plus a small Xcode app project that links the same package. Use KeyboardShortcuts for a user-configurable global shortcut. The menu bar provides sample, settings, and quit actions. The initial shortcut is Control–Option–Command–T; recording another shortcut and clearing it are supported.

The popup starts at 480 × 400 points, can be resized and moved by its title bar, and remembers its frame. Restore the previous position by default; offer near-pointer placement as the fallback for future selection positioning. Clamp windows to a connected display's usable frame, including displays with negative coordinates. Reposition only when explicitly shown in near-pointer mode, reset by the user, or recovered after a display configuration change. Content changes must not resize or move it.

Showing the popup must not activate the app or make it key. Clicking it may give it keyboard focus. It remains visible when key status or app activation changes. Escape closes only the key popup, as does the close button. A shortcut always shows the same popup; it never toggles it closed. Always-on-top defaults to enabled and can be disabled independently. Long sample content scrolls. English and Japanese app resources follow the system language.

### Task 1: Package and placement persistence

- [x] Add the package and tests for restoring a frame, a disconnected display, negative display coordinates, oversized windows, near-pointer placement, and invalid persisted data.
- [x] Observe the tests fail, implement geometry and preferences, and run `swift test` successfully.

### Task 2: Native popup and app shell

- [x] Add focused AppKit tests for showing without key focus, retaining visibility after focus loss, key-only Escape, explicit close/reopen, and frame persistence.
- [x] Implement the panel/controller, SwiftUI sample and settings views, menu bar, and customizable shortcut.
- [x] Add the Xcode app wrapper, shared scheme, VS Code tasks, and bilingual build/run documentation.
- [x] Build with SwiftPM and Xcode; exercise the actual panel in the native tests.

### Task 3: Review and acceptance evidence

- [ ] Review the whole change with a fresh reviewer, fix important issues, and rerun affected checks.
- [x] Record automated evidence separately from manual AutoRaise/display checks. Never mark a manual check passed based on code inspection or a synthetic event.
- [x] Launch the local app for review, update both languages of the phase roadmap and README, and commit the Phase 1 implementation.

### Review focus

Check that no global Escape listener or focus-loss dismissal exists, the shortcut reuses one panel, a settings change updates an already-visible panel, invalid frames recover safely, and a disconnected monitor cannot strand the close button. Check resource bundling in the actual app, not only SwiftPM. A native test is not proof of the user's physical AutoRaise workflow.

## 日本語

### 範囲と決定事項

固定のサンプル文章で第1段階のみ実装する。選択文章の取得、通信、用語集の保存、翻訳エディタはまだ含めない。macOS 15以降、Swift 6、AppKitの非アクティブ化NSPanel内にSwiftUIを配置する。指定の `/Users/s26037/Developer/KotoFloat` を維持し、`feature/phase-1-popup` ブランチで作業する。

VS Codeの補完・ビルド・テスト用にルートのSwiftパッケージを作り、同じパッケージを使う小さなXcodeアプリプロジェクトを追加する。変更可能なグローバルショートカットにはKeyboardShortcutsを使用する。メニューバーにサンプル表示・設定・終了を用意する。初期ショートカットはControl–Option–Command–Tとし、変更・解除も可能にする。

ポップアップの初期サイズは480 × 400ポイントとし、タイトルバーで移動でき、サイズ変更と位置の保存に対応する。既定では前回位置を復元し、将来の選択位置表示の代替としてカーソル付近への配置も選べるようにする。負の座標を含む複数画面の使用可能な範囲に収める。カーソル付近モードでの明示的な再表示、利用者によるリセット、画面構成変更後の復旧時だけ再配置し、文章が変化しても移動・リサイズしない。

表示時はアプリをアクティブにせず、キーボードフォーカスも奪わない。クリック時にはフォーカスを受け取れる。フォーカスやアプリのアクティブ状態が変わっても表示を維持する。Escはポップアップがキーウィンドウのときだけ閉じ、閉じるボタンでも閉じる。ショートカットは一つのポップアップを再表示し、閉じる切り替えにはしない。最前面固定は初期状態で有効とし、閉じる条件とは独立して切り替える。長文はスクロールする。アプリの英語・日本語リソースはシステム言語に従う。

### タスク1：パッケージ・配置・保存

- [x] 位置復元、切断済み画面、負の画面座標、大きすぎるウィンドウ、カーソル付近の配置、不正な保存データのテストを追加する。
- [x] 失敗を確認してから配置計算と設定保存を実装し、`swift test` の成功を確認する。

### タスク2：ポップアップとアプリの土台

- [x] フォーカスを奪わない表示、フォーカス喪失後の表示維持、キーウィンドウ時のみのEsc、閉じる・再表示、位置保存をAppKitテストで確認する。
- [x] パネルと制御処理、SwiftUIのサンプル・設定画面、メニューバー、変更可能なショートカットを実装する。
- [x] Xcodeアプリ、共有スキーム、VS Codeタスク、英日両言語のビルド・実行手順を追加する。
- [x] SwiftPMとXcodeでビルドし、ネイティブテストで実際のパネルを動作させる。

### タスク3：レビューと検証記録

- [ ] 別のレビュアーで変更全体を確認し、重要な問題を修正して関連チェックを再実行する。
- [x] 自動検証と手動のAutoRaise・画面確認を分けて記録する。コード確認や合成イベントだけで手動確認を合格扱いにしない。
- [x] ローカルアプリを起動して確認できる状態にし、段階計画とREADMEの両言語を更新して第1段階の実装をコミットする。

### レビューの重点

Escのグローバル監視やフォーカス喪失による終了がなく、一つのパネルを再利用すること、設定変更が表示中のパネルにも反映されること、不正な位置から復旧でき、モニター切断で閉じるボタンが画面外に残らないことを確認する。SwiftPMだけでなくアプリ内のリソース配置も確認する。ネイティブテストを実際のAutoRaise操作の証明としない。
