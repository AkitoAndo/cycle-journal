# UpdateSummary 2026-03-19

## ドキュメント全面再設計

### 背景
- 旧ドキュメントは40+ファイル（プロンプト設計16、機能仕様11、開発ガイド群）が散在
- 計画書と実装の乖離、粒度のバラつき、読者の不明確さが課題
- VitePressで運用していたがメンテコストに見合っていなかった

### 変更内容

#### 1. ドキュメント構造の再設計（40+ → 10ファイル）

| 新ファイル | 内容 | 旧ファイルからの統合元 |
|-----------|------|---------------------|
| `docs/README.md` | プロジェクト概要 | 新規 |
| `docs/roadmap.md` | AS-IS / TO-BE | DEVELOPMENT_STATUS.md |
| `docs/architecture/overview.md` | 技術選定 + インフラ + なぜこの構成か | TECH_STACK.md, INFRASTRUCTURE.md |
| `docs/architecture/data-model.md` | 全データモデル | 新規（コードから抽出） |
| `docs/architecture/api-contract.md` | API設計方針 | API_DESIGN.md |
| `docs/product/coach-design.md` | コーチの人格・トーン・ルール・禁止表現 | A-01, A-06, C-01〜C-03 |
| `docs/product/cycle-model.md` | Cycleモデル + 行動変容モデル + 感情ラベル | B-01, B-04, A-01(Cycle要素部分) |
| `docs/product/prompt-catalog.md` | プロンプトテンプレート一覧 | A-02〜A-05, B-03 |
| `docs/guides/getting-started.md` | 環境構築ガイド | DEVELOPMENT_GUIDE.md |
| `docs/guides/conventions.md` | コード規約・Git運用・テスト方針 | DEVELOPMENT_GUIDE.md, TESTING.md |

設計方針: 「何」と「なぜ」を同じファイルに同居させる。ADRは別ファイルにせず、関連ドキュメント内にセクションとして記載。

#### 2. プロダクトバックログ（PBL）ページ新設

`docs/backlog/` に32アイテムの個別ページを作成:

- **実装済み（14アイテム）**: 機能概要 + 実装場所 + スクリーンショット
- **未実装（18アイテム）**: ユーザーストーリー + 受け入れ条件 + 依存関係 + 検討事項

カテゴリ: Journal(6), Coach(7), Tasks(5), Auth(3), Settings(3), Backend(5), UX(2)

#### 3. XCUITest + 自動スクリーンショット

- `testScreenshots_*` テストメソッドで14画面を自動撮影
- `ScreenshotHelper.swift` で `docs/public/screenshots/` に直接PNG保存
- テスト実行（Cmd+U）でスクショが自動更新される仕組み
- JournalHeader / TaskHeader に `accessibilityIdentifier` を追加

撮影対象:
- Journal: list, new, edit, search, tags, trash, calendar
- Tasks: list, new, reorder, archive, trash
- Coach: home
- Settings: main

#### 4. GitHub Pages + VitePress 自動デプロイ

- `.github/workflows/deploy-docs.yml`: main push → VitePress build → Pages deploy
- VitePress config を新構造に合わせて更新（ナビ・サイドバー）
- `.gitignore` 追加（VitePress cache/dist、Xcode DerivedData、.env）
- VitePress の `base: '/cycle-journal/'` 設定

#### 5. 旧ドキュメントのアーカイブ

`docs/archive/` に旧ファイルを保全:
- `2025-initial-prompt-design/` - A-01〜C-04（16ファイル）
- `2025-initial-function-specs/` - F1〜F11 + 機能一覧（12ファイル）
- `2025-initial-development/` - 開発ガイド群（6ファイル）
- `2025-initial-api-docs/` - API概要・認証・エンドポイント一覧（3ファイル）
- `2025-initial-mobile/` - ユーザーストーリー・開発状況（3ファイル）

### 今後の残タスク

- GitHub Settings > Pages で Source を **GitHub Actions** に変更（手動、1回のみ）
