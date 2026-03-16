# インフラストラクチャ

## 概要

AWS CDK（Python）によるインフラストラクチャ as Code で管理しています。サーバーレスアーキテクチャを採用し、運用コストとスケーラビリティを最適化しています。

## 環境

| 環境 | ステージ | 用途 |
|------|---------|------|
| Development | `dev` | 開発・テスト |
| Production | `prod` | 本番 |

**リージョン:** `ap-northeast-1`（東京）

## CDK スタック構成

### CycleJournalApiStack

単一スタックで API 全体を管理しています。

```
CycleJournalApiStack
├── Lambda Functions
│   ├── health     (128MB / 10s)
│   ├── auth       (256MB / 30s)
│   ├── coach      (512MB / 60s)
│   └── authorizer (256MB / 10s)
├── Lambda Layer
│   └── jwt-layer  (PyJWT + cryptography)
├── API Gateway
│   └── REST API   (100 req/s / burst 200)
└── IAM Roles & Policies
```

## Lambda 関数

| 関数 | 命名規則 | ハンドラー | メモリ | タイムアウト |
|------|---------|-----------|--------|------------|
| Health | `cyclejournal-{stage}-health` | `health.handler` | 128 MB | 10 秒 |
| Auth | `cyclejournal-{stage}-auth` | `auth.handler` | 256 MB | 30 秒 |
| Coach | `cyclejournal-{stage}-coach` | `coach.handler` | 512 MB | 60 秒 |
| Authorizer | `cyclejournal-{stage}-authorizer` | `authorizer.handler` | 256 MB | 10 秒 |

### 環境変数

| 変数名 | 対象関数 | 説明 |
|--------|---------|------|
| `STAGE` | 全関数 | 環境ステージ（dev/prod） |
| `APPLE_BUNDLE_ID` | Auth, Authorizer | Apple Bundle ID |
| `BEDROCK_MODEL_ID` | Coach | Bedrock モデル ID |

### IAM 権限

| 関数 | 権限 | リソース |
|------|------|---------|
| Coach | `bedrock:InvokeModel` | Claude 3 Haiku foundation model |
| Coach | `bedrock:InvokeModelWithResponseStream` | 同上 |

## Lambda レイヤー

### JWT レイヤー

| 項目 | 値 |
|------|-----|
| 名前 | `cyclejournal-{stage}-jwt-layer` |
| 内容 | PyJWT + cryptography |
| ランタイム | Python 3.12 |
| 使用関数 | Auth, Authorizer |
| ソース | `api/src/layers/jwt/` |

## API Gateway

| 項目 | 値 |
|------|-----|
| タイプ | REST API |
| 名前 | `cyclejournal-{stage}-api` |
| スロットリング | 100 req/s、バースト 200 req |
| CORS | 全オリジン許可 |
| 出力 | `ApiUrl`（CFn Output） |

## データベース（計画中）

Aurora Serverless v2（PostgreSQL 15）を計画しています。

| 項目 | dev | prod |
|------|-----|------|
| エンジン | PostgreSQL 15 | PostgreSQL 15 |
| ACU（最小） | 0.5 | 0.5 |
| ACU（最大） | 4 | 16 |
| 暗号化 | KMS | KMS |
| ステータス | CDK 定義済み・未デプロイ | 未デプロイ |

## デプロイ

### コマンド

```bash
cd api/cdk
cdk deploy --context stage=dev    # 開発環境
cdk deploy --context stage=prod   # 本番環境
```

### デプロイフロー

```
コード変更 → Git Push → (GitHub Actions) → CDK Synth → CDK Deploy → Lambda 更新
```

## 監視・ログ

| サービス | 用途 |
|---------|------|
| CloudWatch Logs | Lambda 実行ログ |
| CloudWatch Alarms | エラー率・レイテンシ監視（計画中） |
| AWS WAF | Web アプリケーション保護（計画中） |

## コスト構造

サーバーレスアーキテクチャにより、使用量に応じた従量課金です。

| サービス | 課金単位 |
|---------|---------|
| Lambda | リクエスト数 + 実行時間 |
| API Gateway | リクエスト数 |
| Bedrock | 入出力トークン数 |
| Aurora（計画中） | ACU 時間 |
