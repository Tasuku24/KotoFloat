# Popup Content Sizing Fix

## English

**Goal:** Fix the reported title/window-button overlap and make short translations compact, growing with content up to the existing scroll threshold.

**Architecture:** Measure the real native window-button clearance in the toolbar. Report the unbounded reading content and fixed controls' heights through a SwiftUI preference to PopupController; coalesce resize work on the main queue. PopupGeometry owns finite, bounded, top-anchored fitting. Preserve the user's saved width/position, not an obsolete tall saved height when opening a new capture.

**Constraints:** No Liquid Glass, new dependencies, automatic requests, global input hooks, or routine desktop tests. Default height 200 points; minimum height 160 points. Maximum remains 600 points or 70% of usable display height, with the interactive minimum retained when it fits. Original text and all consent/draft protections remain unchanged.

### Task 1: Geometry and compact opening

- [x] Add failing tests for compact defaults, incremental growth, ceiling/scroll threshold, shrinking on a new document, top anchoring, small displays, and invalid measurements.
- [x] Implement pure fitting in PopupGeometry and consume it in PopupController with coalesced content-height updates.

### Task 2: Real layout measurements and verification

- [x] Replace the fixed toolbar gutter with measured native button clearance and a safe fallback.
- [x] Measure header, reading content, status, and pending confirmation in both live and sample popup views.
- [x] Run background tests and the separate Debug build, then review the diff and document results.
- [x] Announce any necessary restart/live sample check separately; do not claim live appearance or focus from background tests.

## 日本語

**目的:** 報告されたタイトルとウィンドウボタンの重なりを修正し、短い訳文は小さく、文章量に応じて上限まで伸び、その後は本文をスクロールさせる。

**構成:** 上部操作列では標準ボタンの実際の位置を測定する。本文の自然な高さと固定操作部の高さをSwiftUIのPreferenceでPopupControllerへ渡し、メインキューでまとめてサイズ変更する。有限値の検証・上限・上端基準の配置はPopupGeometryが担当する。保存済みの幅・位置を維持し、新規取得時は以前の大きな高さを引き継がない。

**制約:** Liquid Glass、新規依存、自動リクエスト、グローバル入力監視、通常検証での実画面テストは追加しない。初期高200ポイント、最小高160ポイント。上限は引き続き600ポイントまたは画面作業領域70%とし、操作可能な最小高が収まる場合はそれを維持する。原文表示と送信・下書きの保護は変えない。

### タスク1: 配置と小さな初期表示

- [x] 初期表示、段階的な伸長、上限、新規文書での縮小、上端維持、小画面、不正な測定値の回帰テストを先に追加する。
- [x] PopupGeometryとPopupControllerで本文量に応じた枠の計算・まとめた更新を実装する。

### タスク2: 実際の配置測定と検証

- [x] 固定の左余白を標準ボタンの測定値と安全な初期値に置き換える。
- [x] 通常とサンプルの上部・本文・状態・確認領域を測定する。
- [x] バックグラウンドテストとDebugビルドを順番に実行し、レビューと検証記録を行う。
- [x] 再起動やサンプルの実画面確認は事前に伝え、バックグラウンド検証だけで見た目やフォーカスを確認済みとしない。
