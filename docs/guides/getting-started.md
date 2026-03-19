# Getting Started

## 前提条件

| ツール | 用途 |
|--------|------|
| Xcode 15+ | iOS開発 |
| Python 3.12 | Backend開発 |
| uv | Pythonパッケージ管理 |
| gcloud CLI | GCPリソース操作 |
| Docker | Cloud Runローカル実行 |
| Terraform | IaC |

## iOS開発

```bash
# プロジェクトを開く
open ios/Cycle.xcodeproj

# シミュレーターでビルド＆実行
# Xcode で Cmd+R

# テスト実行
xcodebuild test \
  -project ios/Cycle.xcodeproj \
  -scheme Cycle \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

現状はローカルのみで動作。API接続なしでJournal/Tasks/Coach(モック)が使える。

## Backend開発

```bash
cd api

# 依存関係インストール
uv sync

# ローカル実行（Docker）
docker build -t cycle-api .
docker run -p 8080:8080 cycle-api

# テスト実行
uv run pytest

# Lint & 型チェック
uv run ruff check src/
uv run ruff format src/
uv run mypy src/
```

## Terraformデプロイ

```bash
cd terraform

# 初期化
terraform init

# dev環境デプロイ
terraform workspace select dev
terraform plan
terraform apply

# prod環境デプロイ
terraform workspace select prod
terraform plan
terraform apply
```

## 環境変数

ローカル開発は `.env` ファイル（Git管理外）:

```bash
# .env.example
GCP_PROJECT_ID=cycle-journal-dev
GCP_REGION=asia-northeast1
DATABASE_URL=postgresql://...
```

本番環境は GCP Secret Manager で管理。
