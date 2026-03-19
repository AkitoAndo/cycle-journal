# Getting Started

## 前提条件

| ツール | 用途 |
|--------|------|
| Xcode 16+ | iOS開発 |
| Python 3.12 | Backend開発 |
| uv | Pythonパッケージ管理 |
| gcloud CLI | GCPリソース操作 |
| Docker | Cloud Runローカル実行・デプロイ |
| Terraform | IaC |

## GCPセットアップ

```bash
# ローカル環境の認証設定
./scripts/gcp-setup-local.sh
```

## iOS開発

```bash
# signing設定（初回のみ）
cp ios/Local.xcconfig.template ios/Local.xcconfig
# Local.xcconfig にDEVELOPMENT_TEAMとPRODUCT_BUNDLE_IDENTIFIERを設定

# プロジェクトを開く
open ios/Cycle.xcodeproj

# シミュレーターでビルド＆実行
# Xcode で Cmd+R

# テスト実行（全テスト）
cd ios
xcodebuild test \
  -project Cycle.xcodeproj \
  -scheme Cycle \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# E2Eテストのみ実行
xcodebuild test \
  -project Cycle.xcodeproj \
  -scheme Cycle \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CycleTests/HealthE2ETests \
  -only-testing:CycleTests/AuthE2ETests \
  -only-testing:CycleTests/CoachE2ETests
```

## Backend開発

```bash
cd api

# 依存関係インストール
uv sync --dev

# テスト実行
.venv/bin/python -m pytest tests/ -v

# ローカル実行（uvicorn直接）
uv run uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload

# Docker build & run
docker build -t cycle-api .
docker run -p 8080:8080 cycle-api

# Lint & 型チェック
uv run ruff check app/
uv run ruff format app/
uv run mypy app/
```

## Terraformデプロイ

```bash
cd infra

# 初期化
terraform init

# デプロイ
terraform plan
terraform apply
```

環境の切り替えは `terraform.tfvars` の `environment` 変数で管理。

## Docker → Cloud Runデプロイ

```bash
# amd64でビルド（Cloud Run用）
docker build --platform linux/amd64 \
  -t asia-northeast1-docker.pkg.dev/cycle-journal/cycle-api/api:latest \
  api/

# Artifact Registryにpush
docker push asia-northeast1-docker.pkg.dev/cycle-journal/cycle-api/api:latest

# Cloud Runにデプロイ
gcloud run deploy cycle-api-dev \
  --image=asia-northeast1-docker.pkg.dev/cycle-journal/cycle-api/api:latest \
  --region=asia-northeast1 \
  --project=cycle-journal

# 動作確認
curl https://cycle-api-dev-1031235624127.asia-northeast1.run.app/health
```

## 環境変数

ローカル開発は `.env` ファイル（Git管理外）:

```bash
# .env.example
ENVIRONMENT=dev
GCP_PROJECT_ID=cycle-journal
GCP_REGION=asia-northeast1
APPLE_BUNDLE_ID=com.cycle.journal
USE_LANGGRAPH=false  # true: LangGraphフロー（感情分析・Cycle要素判定・安全フィルター）
```

本番環境は Cloud Run の環境変数 + GCP Secret Manager で管理。
