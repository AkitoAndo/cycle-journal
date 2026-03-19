# 技術スタック

## 概要

CycleJournalプロジェクトの技術スタック定義。

---

## インフラストラクチャ (AWS)

| カテゴリ | 技術 | 備考 |
|---------|------|------|
| コンピュート | AWS Lambda | Python 3.12 |
| API | Amazon API Gateway | REST API |
| IaC | AWS CDK (Python) | インフラのコード管理 |
| DB | Aurora Serverless v2 | PostgreSQL互換 |
| シークレット | AWS Secrets Manager | DB接続情報等 |
| セキュリティ | AWS WAF | API Gateway適用 |
| 暗号化 | AWS KMS | Aurora暗号化 |
| ログ | CloudWatch Logs | 構造化JSON |
| 監視 | CloudWatch Alarms | メトリクス監視 |

### Lambda設定

| 項目 | 値 |
|------|-----|
| メモリ | 256MB |
| タイムアウト | 30秒 |
| ランタイム | Python 3.12 |

---

## バックエンド (Python)

| カテゴリ | 技術 | 備考 |
|---------|------|------|
| 言語 | Python 3.12 | Lambda最新対応版 |
| パッケージ管理 | uv | 高速な依存関係管理 |
| ORM | SQLAlchemy | 実績豊富 |
| マイグレーション | Alembic | SQLAlchemy連携 |
| Linter/Formatter | Ruff | オールインワン |
| 型チェック | mypy | 静的型検査 |
| テスト | pytest | motoでAWSモック |
| ローカル開発 | SAM Local | Lambda実行環境 |

---

## AI/ML

| カテゴリ | 技術 | 備考 |
|---------|------|------|
| LLM | Claude 3 Haiku | Amazon Bedrock経由 |
| フレームワーク | LangChain | LLMオーケストレーション |
| エージェント | LangGraph | 複雑なフロー制御 |
| プロンプト管理 | コード内 | src/prompts/ |

---

## 認証

| カテゴリ | 技術 | 備考 |
|---------|------|------|
| IdP | Sign in with Apple | iOSネイティブ連携 |
| トークン検証 | Lambda Authorizer | Apple JWT検証 |

---

## Mobile (iOS)

| カテゴリ | 技術 | 備考 |
|---------|------|------|
| 言語 | Swift | SwiftUI |
| 最低バージョン | iOS 15+ | 広めのサポート |
| ネットワーク | URLSession | Apple標準 |
| アーキテクチャ | - | 特に規定なし |
| ユニットテスト | XCTest | Apple標準 |
| UIテスト | XCUITest | Apple標準 |
| APIモック | URLProtocol | Swift標準 |
| カバレッジ目標 | 80%以上 | |

---

## 開発環境・CI/CD

| カテゴリ | 技術 | 備考 |
|---------|------|------|
| CI/CD | GitHub Actions | テスト・デプロイ |
| ローカルLambda | SAM Local | ローカル実行 |
| デプロイ | cdk deploy | 直接デプロイ |

### 環境

| 環境 | 用途 |
|------|------|
| dev | 開発・テスト |
| prod | 本番 |

---

## Git運用

### ブランチ戦略

```
main        ← 本番リリース
  └── develop   ← 開発統合
        ├── feature/*  ← 機能開発
        └── docs/*     ← ドキュメント
```

### コミット規約

**Conventional Commits** を採用

```
feat: 新機能追加
fix: バグ修正
docs: ドキュメント
style: フォーマット
refactor: リファクタリング
test: テスト
chore: その他
```

---

## アーキテクチャ図

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
       │                ┌─────────────────────────┼─────────────────────┐
       │                ▼                         ▼                     ▼
       │        ┌───────────────┐         ┌───────────────┐     ┌───────────────┐
       │        │    Bedrock    │         │    Aurora     │     │   Secrets     │
       │        │ Claude Haiku  │         │  Serverless   │     │   Manager     │
       │        └───────────────┘         │  PostgreSQL   │     └───────────────┘
       │                                  │  + KMS暗号化  │
       │                                  └───────────────┘
       │
       └──▶ Sign in with Apple (認証)
```

---

## ディレクトリ構成（予定）

```
CycleJournal/
├── api/                        # バックエンドAPI
│   ├── cdk/                    # CDKインフラ定義
│   │   ├── app.py
│   │   ├── stacks/
│   │   │   ├── api_stack.py
│   │   │   ├── db_stack.py
│   │   │   └── auth_stack.py
│   │   └── cdk.json
│   ├── src/
│   │   ├── handlers/           # Lambda関数
│   │   │   ├── coach.py
│   │   │   └── auth.py
│   │   ├── graph/              # LangGraphフロー
│   │   │   ├── nodes/
│   │   │   └── coach_graph.py
│   │   ├── prompts/            # プロンプトテンプレート
│   │   ├── models/             # SQLAlchemyモデル
│   │   └── db/                 # DB接続・マイグレーション
│   │       └── migrations/     # Alembic
│   ├── tests/
│   │   ├── unit/
│   │   └── integration/
│   ├── pyproject.toml
│   └── uv.lock
├── mobile/                     # iOSアプリ
│   ├── CycleJournal/
│   ├── CycleJournalTests/
│   └── CycleJournalUITests/
├── docs/                       # ドキュメント
│   └── 04_development/
└── .github/
    └── workflows/              # GitHub Actions
```
