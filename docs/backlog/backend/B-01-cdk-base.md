# B-01: Terraform基本構成（Cloud Run）

| 項目 | 内容 |
|------|------|
| ステータス | :white_check_mark: Done |
| 優先度 | P0 |

## ユーザーストーリー

> 開発者として、APIをCloud Runにデプロイして、HTTPリクエストを受け付けられるようにしたい。

## 受け入れ条件

- [x] Cloud Run サービスがデプロイされる
- [x] health エンドポイントが応答する
- [x] Terraformでインフラが管理される
- [x] dev/prod環境の切り替えが可能

## 実装結果

### Terraformリソース（16リソース）

```
infra/
├── main.tf              # Provider, API有効化 (5 APIs), GCSバックエンド
├── variables.tf         # project_id, region, environment
├── terraform.tfvars     # 具体値
├── outputs.tf           # Cloud Run URL, AR repo, SA email
├── iam.tf               # サービスアカウント + Firestore/SecretManager/VertexAI権限
├── artifact_registry.tf # Dockerイメージリポジトリ
├── cloud_run.tf         # Cloud Runサービス（スケールtoゼロ, 512Mi, 公開アクセス）
├── firestore.tf         # Firestoreデータベース + 複合インデックス2つ
└── secret_manager.tf    # Apple認証設定用シークレット
```

### デプロイ済みURL

- dev: `https://cycle-api-dev-1031235624127.asia-northeast1.run.app`
- `GET /health` → `{"status": "healthy", "stage": "dev"}`

### なぜAWSから移行したか

旧構成（AWS CDK + Lambda + API Gateway + Aurora Serverless）ではdev環境だけで月額約$76かかっていた。GCPではCloud Runのスケールtoゼロ + Firestoreの無料枠で月額約$3に削減できた。
