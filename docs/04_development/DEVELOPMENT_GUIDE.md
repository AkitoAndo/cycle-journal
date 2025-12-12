# 開発ガイド

## 概要

CycleJournalプロジェクトの開発規約・ガイドライン。

---

## コード規約

### Python (API)

#### Linter/Formatter

**Ruff** を使用（設定は `pyproject.toml`）

```toml
[tool.ruff]
line-length = 88
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP"]
```

#### 型チェック

**mypy** を使用

```toml
[tool.mypy]
python_version = "3.12"
strict = true
```

#### 実行コマンド

```bash
# Lint
uv run ruff check src/

# Format
uv run ruff format src/

# 型チェック
uv run mypy src/
```

### Swift (Mobile)

- SwiftLint は現時点で未導入
- Xcode標準のフォーマットに従う

---

## Git運用

### ブランチ戦略

| ブランチ | 用途 | マージ先 |
|----------|------|----------|
| `main` | 本番リリース | - |
| `develop` | 開発統合 | main |
| `feature/*` | 機能開発 | develop |
| `docs/*` | ドキュメント | develop |

### ブランチ命名規則

```
feature/add-coach-endpoint
feature/123-user-auth
docs/update-api-spec
```

### コミットメッセージ

**Conventional Commits** 形式

```
<type>: <description>

[optional body]

[optional footer]
```

#### Type一覧

| Type | 用途 |
|------|------|
| `feat` | 新機能 |
| `fix` | バグ修正 |
| `docs` | ドキュメント |
| `style` | フォーマット（動作に影響なし） |
| `refactor` | リファクタリング |
| `test` | テスト追加・修正 |
| `chore` | ビルド・設定変更 |

#### 例

```
feat: add coach chat endpoint

- POST /coach/chat を追加
- LangGraphでコーチングフローを実装

Refs #123
```

---

## 開発環境セットアップ

### 前提条件

- Python 3.12
- uv
- AWS CLI
- AWS SAM CLI
- Node.js (CDK用)
- Xcode 15+ (iOS開発)

### API開発

```bash
# リポジトリクローン
git clone <repo>
cd CycleJournal/api

# 依存関係インストール
uv sync

# ローカル実行
sam local start-api

# テスト実行
uv run pytest

# Lint
uv run ruff check src/
uv run mypy src/
```

### CDKデプロイ

```bash
cd api/cdk

# 依存関係
npm install

# デプロイ (dev)
cdk deploy --context env=dev

# デプロイ (prod)
cdk deploy --context env=prod
```

### iOS開発

```bash
# Xcodeでプロジェクトを開く
open mobile/CycleJournal.xcodeproj

# テスト実行
xcodebuild test \
  -project mobile/CycleJournal.xcodeproj \
  -scheme CycleJournal \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## CI/CD

### GitHub Actions ワークフロー

| ワークフロー | トリガー | 内容 |
|--------------|----------|------|
| `api-test.yml` | push, PR | Lint, 型チェック, テスト |
| `ios-test.yml` | push, PR | ビルド, テスト |
| `deploy-dev.yml` | develop push | dev環境デプロイ |
| `deploy-prod.yml` | main push | prod環境デプロイ |

### CI必須チェック

- [ ] Ruff lint pass
- [ ] mypy pass
- [ ] pytest pass (カバレッジ80%以上)
- [ ] iOS build success
- [ ] iOS test pass

---

## 環境変数・シークレット

### ローカル開発

`.env` ファイル（Git管理外）

```bash
# .env.example
AWS_REGION=ap-northeast-1
DATABASE_URL=postgresql://...
```

### 本番環境

**AWS Secrets Manager** で管理

| シークレット名 | 内容 |
|----------------|------|
| `cyclejournal/dev/db` | dev DB接続情報 |
| `cyclejournal/prod/db` | prod DB接続情報 |

---

## ドキュメント管理

| ドキュメント | 場所 |
|--------------|------|
| 技術スタック | `docs/04_development/TECH_STACK.md` |
| API設計 | `docs/04_development/API_DESIGN.md` |
| テスト方針 | `docs/04_development/TESTING.md` |
| 開発ガイド | `docs/04_development/DEVELOPMENT_GUIDE.md` |
| API仕様書 | `api/docs/openapi.yaml` + Redocly |
