# アーキテクチャ概要

## 全体構成

```
┌─────────────┐     ┌─────────────────┐
│   iOS App   │────▶│   Cloud Run     │
│ (SwiftUI)   │     │  (Python API)   │
│  iOS 15+    │     │  + Cloud Armor  │
└─────────────┘     └──────┬──────────┘
       │                   │
       │           ┌───────┴───────┐
       │           │  Auth         │
       │           │  Middleware   │
       │           │ (Sign in w/  │
       │           │    Apple)    │
       │           └───────────────┘
       │                   │
       │     ┌─────────────┼──────────────────┐
       │     ▼             ▼                  ▼
       │  ┌──────────┐  ┌──────────────┐  ┌──────────────┐
       │  │ Vertex AI│  │  Cloud SQL   │  │   Secret     │
       │  │ (Claude) │  │ PostgreSQL   │  │   Manager    │
       │  └──────────┘  └──────────────┘  └──────────────┘
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
| Cloud Run (Python 3.12) | コンテナベース、スケールtoゼロ |
| Cloud SQL | PostgreSQL 15、自動バックアップ |
| Terraform | IaC |
| Claude (Vertex AI) | コスト効率重視のLLM |
| LangChain + LangGraph | LLMオーケストレーション |

### セキュリティ

| 技術 | 備考 |
|------|------|
| Sign in with Apple | iOSネイティブ認証 |
| Cloud Run ミドルウェア | Apple JWT検証 |
| Cloud Armor | DDoS防御 + レートリミット |
| Cloud KMS | DB暗号化 |
| Secret Manager | DB接続情報、Apple認証設定 |

## なぜこの構成か

**Cloud Runを選んだ理由**: コンテナベースでスケールtoゼロが可能。個人プロジェクトでトラフィックが読めないため、使わない時間帯はコストゼロ。Lambdaと異なりリクエストタイムアウトが長く（最大60分）、LLMの応答待ちに余裕がある。

**Cloud SQLを選んだ理由**: マネージドPostgreSQLで運用負荷が低い。dev環境は最小インスタンスでコストを抑えられる。

**Vertex AI (Claude) を選んだ理由**: コーチングの応答品質と応答速度・コストのバランス。GCPエコシステム内に閉じられる。

**LangGraphを選んだ理由**: コーチングフローが単純なプロンプト→応答ではなく、感情分析→状態判定→質問生成→安全フィルターと複数ノードを経由する必要があるため。

## インフラ詳細

### VPCネットワーク構成

```
VPC
├── Cloud Run（Serverless VPC Connector経由）
├── Cloud SQL（プライベートIP）
└── Cloud NAT（外部API呼び出し用）
```

### Terraformモジュール構成

```
terraform/
├── main.tf
├── variables.tf
├── modules/
│   ├── network/      # VPC, サブネット, Cloud NAT
│   ├── database/     # Cloud SQL, Secret Manager
│   ├── api/          # Cloud Run, Cloud Armor
│   └── monitoring/   # Cloud Logging, Cloud Monitoring
```

### Cloud Runサービス

| サービス名 | 用途 | メモリ | タイムアウト |
|-----------|------|--------|-------------|
| `cycle-api` | API (認証 + コーチング + ヘルスチェック) | 512MB | 300秒 |

### 環境別設定

| 項目 | dev | prod |
|------|-----|------|
| Cloud SQL | db-f1-micro | db-custom-1-3840 |
| ログ保持 | 30日 | 90日 |
| Cloud Armor | 有効 | 有効 |
| バックアップ | 7日 | 7日 |

### コスト概算（月額）

| サービス | dev | prod |
|----------|-----|------|
| Cloud Run | ~$0 (無料枠) | ~$20 |
| Cloud SQL | ~$10 | ~$50 |
| Secret Manager | ~$0 | ~$0 |
| Cloud Logging | ~$0 | ~$10 |
| Cloud Armor | ~$5 | ~$5 |
| **合計** | **~$15** | **~$85** |
