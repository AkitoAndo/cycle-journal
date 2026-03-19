# 開発規約

## Git運用

### ブランチ戦略

```
main        ← 本番リリース
  ├── feature/*  ← 機能開発
  ├── infra/*    ← インフラ変更
  └── docs/*     ← ドキュメント
```

### コミットメッセージ

Conventional Commits 形式:

```
<type>: <description>

[optional body]

[optional footer]
```

| Type | 用途 |
|------|------|
| `feat` | 新機能 |
| `fix` | バグ修正 |
| `docs` | ドキュメント |
| `style` | フォーマット（動作に影響なし） |
| `refactor` | リファクタリング |
| `test` | テスト追加・修正 |
| `infra` | インフラ変更 |
| `chore` | ビルド・設定変更 |

### ブランチ命名例

```
feature/add-coach-endpoint
feature/123-user-auth
infra/gcp-cloudrun-fastapi
docs/update-api-spec
```

## コード規約

### Python (Backend)

Ruff でlint/format、mypy で型チェック:

```toml
[tool.ruff]
line-length = 88
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP"]

[tool.mypy]
python_version = "3.12"
strict = true
```

### Swift (iOS)

- SwiftLint は未導入。Xcode標準のフォーマットに従う
- SwiftUI + MVVM（Feature単位で Model/ViewModel/Views/Store を分離）

## CI/CD

| ワークフロー | トリガー | 内容 |
|--------------|----------|------|
| `api-test.yml` | push, PR | Lint, 型チェック, テスト |
| `ios-test.yml` | push, PR | ビルド, テスト |
| `deploy-dev.yml` | main push | Docker build → Artifact Registry → Cloud Run (dev) |
| `deploy-prod.yml` | main push (手動承認) | Cloud Run (prod) |

### 手動デプロイ

CI/CD未構築の場合:

```bash
docker build --platform linux/amd64 \
  -t asia-northeast1-docker.pkg.dev/cycle-journal/cycle-api/api:latest api/
docker push asia-northeast1-docker.pkg.dev/cycle-journal/cycle-api/api:latest
gcloud run deploy cycle-api-dev \
  --image=asia-northeast1-docker.pkg.dev/cycle-journal/cycle-api/api:latest \
  --region=asia-northeast1 --project=cycle-journal
```

## テスト方針

テストピラミッド: ユニット70% / 結合20% / E2E10%。カバレッジ目標80%。

### Python

- pytest（標準モック）
- LLMテスト: ユニットはモックレスポンス、E2Eは実Vertex AI API

### Swift

- XCTest + URLProtocol（APIモック）
- XCUITest（UIテスト）
