# アーキテクチャ概要

## システム構成図

```
┌─────────────────────────────────────────────────────────┐
│                     iOS App (SwiftUI)                    │
│  ┌──────────┬──────────┬──────────┬──────────┐          │
│  │  Diary   │  Coach   │  Tasks   │ Settings │          │
│  │  Store   │  Store   │  Store   │          │          │
│  └────┬─────┴────┬─────┴────┬─────┴──────────┘          │
│       │ Local    │          │                            │
│  ┌────▼─────┐   │     ┌────▼─────┐                      │
│  │UserDefaults│  │     │ APIClient│                      │
│  │(日記保存) │  │     │ (HTTP)   │                      │
│  └──────────┘  │     └────┬─────┘                      │
│                │          │                              │
│           ┌────▼──────────▼────┐                        │
│           │     Keychain       │                        │
│           │  (認証トークン)     │                        │
│           └────────────────────┘                        │
└────────────────────┬────────────────────────────────────┘
                     │ HTTPS
                     ▼
┌─────────────────────────────────────────────────────────┐
│                 AWS Cloud (ap-northeast-1)               │
│                                                          │
│  ┌──────────────────────────────────────────────┐       │
│  │            API Gateway (REST)                 │       │
│  │  Rate: 100 req/s  Burst: 200 req             │       │
│  └──────────┬──────────┬──────────┬─────────────┘       │
│             │          │          │                       │
│     ┌───────▼──┐ ┌────▼────┐ ┌───▼──────┐              │
│     │ /health  │ │/auth/   │ │ /coach   │              │
│     │ (Lambda) │ │verify   │ │ (Lambda) │              │
│     │ 128MB    │ │(Lambda) │ │ 512MB    │              │
│     │ 10s      │ │256MB    │ │ 60s      │              │
│     └──────────┘ │30s      │ └────┬─────┘              │
│                  └────┬────┘      │                      │
│                       │           │                      │
│           ┌───────────▼───┐  ┌────▼────────────┐       │
│           │  JWT Layer    │  │  AWS Bedrock     │       │
│           │  (PyJWT +     │  │  Claude 3 Haiku  │       │
│           │  cryptography)│  │                  │       │
│           └───────────────┘  └──────────────────┘       │
│                                                          │
│  ┌──────────────────────────────────────────────┐       │
│  │           Planned (未実装)                    │       │
│  │  Aurora Serverless v2 (PostgreSQL 15)         │       │
│  │  0.5-4 ACU (dev) / 0.5-16 ACU (prod)         │       │
│  │  KMS 暗号化                                   │       │
│  └──────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────┘
```

## 技術スタック

### モバイル（iOS）

| カテゴリ | 技術 |
|---------|------|
| 言語 | Swift |
| UI フレームワーク | SwiftUI |
| アーキテクチャ | MVVM（ObservableObject） |
| 状態管理 | @StateObject / @EnvironmentObject / @Published |
| ネットワーク | URLSession（APIClient） |
| 認証 | AuthenticationServices（Sign in with Apple） |
| ローカル保存 | UserDefaults（日記）、Keychain（認証情報） |
| ビルドシステム | Xcode |

### バックエンド（API）

| カテゴリ | 技術 |
|---------|------|
| 言語 | Python 3.12 |
| ランタイム | AWS Lambda（サーバーレス） |
| パッケージ管理 | uv |
| AI/LLM | AWS Bedrock（Claude 3 Haiku） |
| 認証 | PyJWT + Apple 公開鍵検証 |
| API ゲートウェイ | Amazon API Gateway（REST） |
| IaC | AWS CDK（Python） |

### インフラ・DevOps

| カテゴリ | 技術 |
|---------|------|
| クラウド | AWS（ap-northeast-1 / 東京リージョン） |
| コンピュート | AWS Lambda |
| API 管理 | Amazon API Gateway |
| AI/ML | Amazon Bedrock |
| DB（予定） | Aurora Serverless v2（PostgreSQL 15） |
| シークレット管理 | AWS Secrets Manager |
| 監視 | CloudWatch Logs + Alarms |
| IaC | AWS CDK |
| CI/CD | GitHub Actions |

### 開発ツール

| ツール | 用途 |
|--------|------|
| Ruff | Python リンター・フォーマッター |
| mypy | Python 型チェック |
| pytest | Python テストフレームワーク |
| VitePress | ドキュメントサイト |

## データフロー

### 日記（ローカルのみ）

```
ユーザー入力 → DiaryStore → UserDefaults（デバイス内保存）
```

### コーチ対話

```
ユーザー入力 → CoachStore → APIClient → API Gateway → Lambda (coach)
                                                         ↓
                                                    AWS Bedrock
                                                    Claude 3 Haiku
                                                         ↓
CoachStore ← APIClient ← API Gateway ← Lambda ← AI 応答
```

### 認証

```
Sign in with Apple → identityToken (JWT)
        ↓
   Keychain に保存
        ↓
   POST /auth/verify → Lambda → Apple 公開鍵で検証
        ↓
   ユーザー情報返却
```

## リポジトリ構成

```
cycle-journal/
├── api/                    # バックエンド
│   ├── src/
│   │   ├── handlers/       # Lambda ハンドラー
│   │   │   ├── health.py
│   │   │   ├── auth.py
│   │   │   ├── coach.py
│   │   │   └── authorizer.py
│   │   └── layers/         # Lambda レイヤー
│   │       └── jwt/        # PyJWT + cryptography
│   ├── cdk/                # CDK インフラコード
│   │   ├── app.py
│   │   └── stacks/
│   │       └── api_stack.py
│   ├── tests/              # テスト
│   └── pyproject.toml
├── mobile/                 # iOS アプリ
│   └── CycleJournal/
│       ├── Views/          # SwiftUI ビュー
│       ├── Models/         # データモデル
│       ├── Services/       # API クライアント
│       └── Stores/         # 状態管理
├── docs/                   # ドキュメント (VitePress)
└── scripts/                # ユーティリティスクリプト
```
