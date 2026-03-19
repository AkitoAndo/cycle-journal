# インフラストラクチャ設計

## 概要

CycleJournalのAWSインフラ設計。AWS CDK (Python) で管理。

---

## アーキテクチャ概要

```
                                    ┌─────────────────────────────────────┐
                                    │            AWS Cloud                │
                                    │                                     │
┌──────────┐    HTTPS    ┌──────────┴──────────┐                         │
│ iOS App  │────────────▶│    API Gateway      │                         │
└──────────┘             │    (REST API)       │                         │
                         │    + AWS WAF        │                         │
                         └──────────┬──────────┘                         │
                                    │                                     │
                    ┌───────────────┼───────────────┐                    │
                    ▼               ▼               ▼                    │
            ┌───────────┐   ┌───────────┐   ┌───────────┐               │
            │  Lambda   │   │  Lambda   │   │  Lambda   │               │
            │Authorizer │   │  Coach    │   │  Health   │               │
            └─────┬─────┘   └─────┬─────┘   └───────────┘               │
                  │               │                                      │
                  │               ├────────────────────┐                 │
                  │               ▼                    ▼                 │
                  │       ┌───────────────┐    ┌───────────────┐        │
                  │       │   Bedrock     │    │    Aurora     │        │
                  │       │ Claude Haiku  │    │  Serverless   │        │
                  │       └───────────────┘    │  PostgreSQL   │        │
                  │                            └───────────────┘        │
                  │                                    │                 │
                  │       ┌───────────────┐            │                 │
                  └──────▶│   Secrets     │◀───────────┘                 │
                          │   Manager     │                              │
                          └───────────────┘                              │
                                    │                                     │
                          ┌───────────────┐                              │
                          │ CloudWatch    │                              │
                          │ Logs/Alarms   │                              │
                          └───────────────┘                              │
                                    │                                     │
                                    └─────────────────────────────────────┘
```

---

## AWSリソース一覧

### API Gateway

| 項目 | 設定 |
|------|------|
| タイプ | REST API |
| エンドポイント | Regional |
| 認証 | Lambda Authorizer |
| WAF | 有効 |
| ステージ | dev, prod |

### Lambda

| 関数名 | 用途 | メモリ | タイムアウト |
|--------|------|--------|-------------|
| `authorizer` | JWT検証 | 256MB | 10秒 |
| `coach` | AIコーチング | 256MB | 30秒 |
| `health` | ヘルスチェック | 128MB | 5秒 |

#### 共通設定

| 項目 | 設定 |
|------|------|
| ランタイム | Python 3.12 |
| アーキテクチャ | arm64 (Graviton2) |
| VPC | Aurora接続用VPC |

### Aurora Serverless v2

| 項目 | 設定 |
|------|------|
| エンジン | PostgreSQL 15 |
| 最小ACU | 0.5 |
| 最大ACU | 4 (dev), 16 (prod) |
| 暗号化 | KMS |
| バックアップ | 自動 (7日間) |

### Secrets Manager

| シークレット | 内容 |
|--------------|------|
| `cyclejournal/{env}/db` | DB接続情報 |
| `cyclejournal/{env}/apple` | Apple認証設定 |

### AWS WAF

| ルール | 説明 |
|--------|------|
| AWSManagedRulesCommonRuleSet | 一般的な攻撃防御 |
| AWSManagedRulesKnownBadInputsRuleSet | 悪意ある入力防御 |
| レートリミット | 1000 req/5min/IP |

### CloudWatch

| リソース | 設定 |
|----------|------|
| ロググループ | `/aws/lambda/cyclejournal-{env}-*` |
| 保持期間 | 30日 (dev), 90日 (prod) |
| アラーム | エラー率 > 1%, レイテンシ > 5s |

---

## ネットワーク設計

### VPC構成

```
VPC (10.0.0.0/16)
├── Public Subnet (10.0.1.0/24, 10.0.2.0/24)
│   └── NAT Gateway
├── Private Subnet (10.0.10.0/24, 10.0.11.0/24)
│   └── Lambda, Aurora
└── Isolated Subnet (10.0.20.0/24, 10.0.21.0/24)
    └── (将来用)
```

### セキュリティグループ

| SG名 | インバウンド | アウトバウンド |
|------|-------------|---------------|
| `lambda-sg` | なし | All |
| `aurora-sg` | 5432 from lambda-sg | なし |

---

## CDKスタック構成

```
cdk/
├── app.py                    # エントリーポイント
├── stacks/
│   ├── network_stack.py      # VPC, サブネット
│   ├── db_stack.py           # Aurora, Secrets
│   ├── auth_stack.py         # Lambda Authorizer
│   ├── api_stack.py          # API Gateway, Lambda
│   └── monitoring_stack.py   # CloudWatch, WAF
└── cdk.json
```

### スタック依存関係

```
NetworkStack
    ↓
DbStack ← SecretsManager
    ↓
AuthStack
    ↓
ApiStack ← WAF
    ↓
MonitoringStack
```

---

## 環境別設定

| 項目 | dev | prod |
|------|-----|------|
| Aurora ACU | 0.5-4 | 0.5-16 |
| ログ保持 | 30日 | 90日 |
| WAF | 有効 | 有効 |
| アラート通知 | なし | 要設定 |
| バックアップ | 7日 | 7日 |

---

## デプロイ手順

### 初回セットアップ

```bash
cd api/cdk

# CDK Bootstrap (初回のみ)
cdk bootstrap aws://ACCOUNT_ID/ap-northeast-1

# 全スタックデプロイ
cdk deploy --all --context env=dev
```

### 通常デプロイ

```bash
# dev環境
cdk deploy CycleJournalApiStack --context env=dev

# prod環境
cdk deploy CycleJournalApiStack --context env=prod
```

### ロールバック

```bash
# 前バージョンにロールバック
cdk deploy --context env=prod --previous-version
```

---

## コスト概算 (月額)

| サービス | dev | prod |
|----------|-----|------|
| Lambda | ~$5 | ~$20 |
| API Gateway | ~$5 | ~$50 |
| Aurora Serverless | ~$50 | ~$200 |
| Secrets Manager | ~$1 | ~$1 |
| CloudWatch | ~$5 | ~$20 |
| WAF | ~$10 | ~$10 |
| **合計** | **~$76** | **~$301** |

※実際の使用量により変動
