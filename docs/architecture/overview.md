# アーキテクチャ概要

## 全体構成

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────┐
│   iOS App   │────▶│  API Gateway    │────▶│   Lambda    │
│ (SwiftUI)   │     │  (REST API)     │     │  (Python)   │
│  iOS 15+    │     │    + WAF        │     │   256MB     │
└─────────────┘     └─────────────────┘     └──────┬──────┘
       │                    │                      │
       │            ┌───────┴───────┐              │
       │            │    Lambda     │              │
       │            │  Authorizer   │              ▼
       │            │ (Sign in w/   │     ┌───────────────┐
       │            │    Apple)     │     │   LangGraph   │
       │            └───────────────┘     │  (LangChain)  │
       │                                  └───────┬───────┘
       │                                          │
       │                ┌─────────────────────────┼──────────────────┐
       │                ▼                         ▼                  ▼
       │        ┌───────────────┐         ┌───────────────┐  ┌───────────────┐
       │        │    Bedrock    │         │    Aurora     │  │   Secrets     │
       │        │ Claude Haiku  │         │  Serverless   │  │   Manager     │
       │        └───────────────┘         │  PostgreSQL   │  └───────────────┘
       │                                  └───────────────┘
       │
       └──▶ Sign in with Apple (認証)
```

## 技術選定

### iOS

| 技術 | 備考 |
|------|------|
| Swift / SwiftUI | 宣言的UI |
| iOS 15+ | 広めのサポート |
| URLSession | Apple標準ネットワーク |
| Keychain | 認証トークン保存 |

### Backend

| 技術 | 備考 |
|------|------|
| AWS Lambda (Python 3.12) | arm64 (Graviton2) |
| API Gateway (REST) | Regional endpoint |
| Aurora Serverless v2 | PostgreSQL 15互換、ACU 0.5-4(dev)/0.5-16(prod) |
| AWS CDK (Python) | IaC |
| Claude 3 Haiku (Bedrock) | コスト効率重視のLLM |
| LangChain + LangGraph | LLMオーケストレーション |

### セキュリティ

| 技術 | 備考 |
|------|------|
| Sign in with Apple | iOSネイティブ認証 |
| Lambda Authorizer | Apple JWT検証 |
| AWS WAF | 一般攻撃防御 + レートリミット(1000req/5min/IP) |
| KMS | Aurora暗号化 |
| Secrets Manager | DB接続情報、Apple認証設定 |

## なぜこの構成か

**サーバーレス（Lambda + Aurora Serverless）を選んだ理由**: 個人プロジェクトでトラフィックが読めない。Aurora Serverless v2はACU 0.5まで下げられるため、使わない時間帯のコストを抑えつつ、スケールアウトもできる。dev環境の月額コスト概算は約$76。

**Claude 3 Haikuを選んだ理由**: コーチングの応答品質と応答速度・コストのバランス。Bedrock経由でAWSエコシステム内に閉じられる。

**LangGraphを選んだ理由**: コーチングフローが単純なプロンプト→応答ではなく、感情分析→状態判定→質問生成→安全フィルターと複数ノードを経由する必要があるため。

## インフラ詳細

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

### CDKスタック構成

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

### Lambda関数

| 関数名 | 用途 | メモリ | タイムアウト |
|--------|------|--------|-------------|
| `authorizer` | JWT検証 | 256MB | 10秒 |
| `coach` | AIコーチング | 256MB | 30秒 |
| `health` | ヘルスチェック | 128MB | 5秒 |

### 環境別設定

| 項目 | dev | prod |
|------|-----|------|
| Aurora ACU | 0.5-4 | 0.5-16 |
| ログ保持 | 30日 | 90日 |
| WAF | 有効 | 有効 |
| バックアップ | 7日 | 7日 |

### コスト概算（月額）

| サービス | dev | prod |
|----------|-----|------|
| Lambda | ~$5 | ~$20 |
| API Gateway | ~$5 | ~$50 |
| Aurora Serverless | ~$50 | ~$200 |
| Secrets Manager | ~$1 | ~$1 |
| CloudWatch | ~$5 | ~$20 |
| WAF | ~$10 | ~$10 |
| **合計** | **~$76** | **~$301** |
