# Translation-first Popup Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement the approved design in this chat. Steps use checkbox syntax for tracking.

## English

**Goal:** Put the translation first in a lightweight popup with a compact top toolbar and bounded reading area.

**Architecture:** Reuse the existing capture/translation model and native window lifecycle. Keep geometry limits in PopupGeometry, favorite ordering in LanguagePicker, and popup-only presentation in focused SwiftUI views; retain the existing detailed editor views.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Testing; macOS 15+.

**Spec:** `docs/superpowers/specs/2026-11-01-translation-first-popup-design.md`

## Global Constraints

- No Liquid Glass, blur, new dependencies, or routine desktop interaction.
- Use the current checkout on `feature/translation-first-popup`; preserve existing work and shared-model protections.
- Repository prose is English first, Japanese second; commits are English.
- Tests: `nice -n 10 swift test --jobs 2 --skip PopupControllerTests`.
- Build: `nice -n 10 xcodebuild -project KotoFloat.xcodeproj -scheme KotoFloat -configuration Debug -derivedDataPath .build/validation -jobs 2 build`.

## Review Focus

- Oversized saved frames, small displays, missing displays, and moving between displays.
- Favorites ordering, exclusions, filtered searches, IME, and focused shortcuts after removing the favorites strip.
- New captures while an edited shared document exists; no hidden consent or stale output presented as current.
- Very long/partial/error translations: fixed controls, readable text, stable scroll position, guarded copy.
- Native close/titlebar layout at minimum width and both focus modes; no live-window proof from background checks.

### Task 1: Bounded geometry and favorites inside the picker

**Files:** PopupGeometry.swift, PopupController.swift, LanguagePicker.swift, PopupGeometryTests.swift, LanguagePickerTests.swift.

**Interfaces:** Extend existing frame restoration/placement to cap height; expose the same screen-derived height limit to the native controller. Add optional favorite languages to the native picker without changing other callers.

- [x] Add failing regression tests for height caps across placements/display sizes and favorite ordering/search/exclusions.
- [x] Run the background suite; confirm only the new expectations fail.
- [x] Implement geometry bounds and picker ordering, then run the background suite.
- [x] Commit the verified slice.

### Task 2: Translation-first presentation and complete action access

**Files:** CaptureContentView.swift, PopupContentView.swift, PopupWindow.swift, new popup-focused view files, TranslationContentView.swift, localized strings, README.md, testing notes.

**Interfaces:** Consume Task 1's bounded geometry and optional picker favorites. Reuse TranslationModel, capture states, confirmation view, glossary selection, and focused shortcut control without changing request ownership.

- [x] Replace the captured-state controls/source preview with a compact top row and result-first scroll view; reset source/details for new documents.
- [x] Keep all existing actions reachable through the more menu or existing dedicated windows, with state-specific warnings/recovery outside hidden details.
- [x] Align the sample popup with the result-first layout; use solid system backgrounds and retain the native close button.
- [x] Run the background suite and Debug build sequentially; check localization parity and diff whitespace.
- [x] Record proof and remaining live acceptance checks, review the whole branch, and commit the verified result.

## 日本語

**目的:** 軽量な上部操作列と高さを制限した本文領域により、訳文を最優先する。

**構成:** 取得・翻訳モデルとネイティブウィンドウのライフサイクルを再利用する。サイズ制限はPopupGeometry、お気に入り順序はLanguagePicker、ポップアップ固有の表示はSwiftUIの専用ビューが担当し、既存の詳細エディタ表示を維持する。

**技術:** Swift 6、SwiftUI、AppKit、Swift Testing、macOS 15以降。

**設計:** `docs/superpowers/specs/2026-11-01-translation-first-popup-design.md`

### 共通制約と確認点

- Liquid Glass・ぼかし・新規依存・通常検証での画面操作は行わない。
- 現在のチェックアウトで指定ブランチを使い、共有状態と既存の保護を維持する。
- 説明文は英語の後に日本語、コミットは英語にする。
- テスト・ビルドは英語節に記載したコマンドを順番に実行する。
- 保存枠・小画面・画面切断・画面移動、お気に入り検索・除外・IME・ショートカット、編集中の新規取得、長文・未完了・失敗、最小幅・両フォーカス方式の閉じる操作を重点確認する。

### タスク1: サイズ制限と言語選択内のお気に入り

- [x] サイズ制限とお気に入りの順序・検索・除外について、先に失敗する回帰テストを書く。
- [x] バックグラウンドテストで、新しい期待のみが失敗することを確認する。
- [x] 既存の枠復元・配置・コントローラと言語選択を拡張して、同テストを通す。
- [x] 検証済みの変更をコミットする。

### タスク2: 訳文優先の表示と既存操作への経路

- [x] 上部の操作列と訳文優先のスクロール表示を実装し、新しい文書で原文・詳細を閉じる。
- [x] 既存機能をメニューまたは専用画面に残し、必要な注意・復旧操作を隠さない。
- [x] サンプルも同じ表示方針に揃え、通常の背景と標準の閉じるボタンを使う。
- [x] バックグラウンドテスト、Debugビルド、翻訳キーの一致、空白チェックを実行する。
- [x] 検証結果と実画面の残確認を記録し、全体レビュー後にコミットする。
