# アーキテクチャ概要

## 全体構成

```
┌─────────────┐     ┌─────────────────┐
│   iOS App   │────▶│   Cloud Run     │
│ (SwiftUI)   │     │  (Python API)   │
│  iOS 15+    │     │  + Auth MW      │
└─────────────┘     └──────┬──────────┘
       │                   │
       │     ┌─────────────┼──────────────┐
       │     ▼             ▼              ▼
       │  ┌──────────┐  ┌───────────┐  ┌──────────────┐
       │  │ Vertex AI│  │ Firestore │  │   Secret     │
       │  │ (Claude) │  │           │  │   Manager    │
       │  └──────────┘  └───────────┘  └──────────────┘
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
| Firestore | NoSQL ドキュメントDB、スケールtoゼロ |
| Terraform | IaC |
| Claude (Vertex AI) | コスト効率重視のLLM |
| LangChain + LangGraph | LLMオーケストレーション |

### セキュリティ

| 技術 | 備考 |
|------|------|
| Sign in with Apple | iOSネイティブ認証 |
| Cloud Run ミドルウェア | Apple JWT検証 |
| Secret Manager | Apple認証設定などのシークレット |

## なぜこの構成か

**Cloud Runを選んだ理由**: コンテナベースでスケールtoゼロが可能。個人プロジェクトでトラフィックが読めないため、使わない時間帯はコストゼロ。リクエストタイムアウトが長く（最大60分）、LLMの応答待ちに余裕がある。

**Firestoreを選んだ理由**: users/sessions/messages の入れ子構造がドキュメントDBに自然に対応する。無料枠が大きく個人利用ならコストゼロ。Cloud Runから直接アクセスでき、VPC Connectorが不要で構成がシンプル。

**Cloud SQL（PostgreSQL）ではなくFirestoreにした理由**: Cloud SQLは最小インスタンスでも月$10の常時起動コストが発生する。Firestoreはスケールtoゼロでき、Cloud Runとの組み合わせで完全にゼロコスト運用が可能。複雑なJOINや集計クエリは現時点で不要。

**Vertex AI (Claude) を選んだ理由**: コーチングの応答品質と応答速度・コストのバランス。GCPエコシステム内に閉じられる。

**LangGraphを選んだ理由**: コーチングフローが単純なプロンプト→応答ではなく、感情分析→状態判定→質問生成→安全フィルターと複数ノードを経由する必要があるため。

**Cloud Armorは入れない理由**: MVP段階では不要。Cloud Run自体に基本的なDDoS耐性があり、認証ミドルウェアで未認証リクエストは弾ける。ユーザーが増えてから検討する。

## インフラ詳細

### Terraformモジュール構成

```
terraform/
├── main.tf
├── variables.tf
├── modules/
│   ├── api/          # Cloud Run
│   ├── database/     # Firestore, Secret Manager
│   └── monitoring/   # Cloud Logging, Cloud Monitoring
```

### Cloud Runサービス

| サービス名 | 用途 | メモリ | タイムアウト |
|-----------|------|--------|-------------|
| `cycle-api` | API (認証 + コーチング + ヘルスチェック) | 512MB | 300秒 |

### Firestoreコレクション構造

```
users/{userId}
├── sessions/{sessionId}
│   └── messages/{messageId}
├── tasks/{taskId}
│   └── reflections/{reflectionId}
└── (profile data)
```

### 環境別設定

| 項目 | dev | prod |
|------|-----|------|
| Cloud Run | min 0, max 1 | min 0, max 10 |
| Firestore | (default) DB | (default) DB |
| ログ保持 | 30日 | 90日 |

### コスト概算（月額）

| サービス | dev | prod (100ユーザー想定) |
|----------|-----|------|
| Cloud Run | ~$0 (無料枠) | ~$5 |
| Firestore | ~$0 (無料枠) | ~$2 |
| Vertex AI (Claude) | ~$3 | ~$50 |
| Secret Manager | ~$0 | ~$0 |
| Cloud Logging | ~$0 | ~$0 |
| **合計** | **~$3/月** | **~$57/月** |
