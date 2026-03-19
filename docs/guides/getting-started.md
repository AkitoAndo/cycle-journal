# Getting Started

## 前提条件

| ツール | 用途 |
|--------|------|
| Xcode 15+ | iOS開発 |
| Python 3.12 | Backend開発 |
| uv | Pythonパッケージ管理 |
| AWS CLI | AWSリソース操作 |
| AWS SAM CLI | Lambdaローカル実行 |
| Node.js | CDK用 |

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

# ローカル実行
sam local start-api

# テスト実行
uv run pytest

# Lint & 型チェック
uv run ruff check src/
uv run ruff format src/
uv run mypy src/
```

## CDKデプロイ

```bash
cd api/cdk

# 依存関係
npm install

# 初回のみ
cdk bootstrap aws://ACCOUNT_ID/ap-northeast-1

# dev環境デプロイ
cdk deploy --all --context env=dev

# 特定スタックのみ
cdk deploy CycleJournalApiStack --context env=dev
```

## 環境変数

ローカル開発は `.env` ファイル（Git管理外）:

```bash
# .env.example
AWS_REGION=ap-northeast-1
DATABASE_URL=postgresql://...
```

本番環境は AWS Secrets Manager で管理。
