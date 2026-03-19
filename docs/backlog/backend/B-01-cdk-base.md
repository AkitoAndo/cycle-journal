# B-01: Terraform基本構成（Cloud Run）

| 項目 | 内容 |
|------|------|
| ステータス | :memo: Refinement |
| 優先度 | P0 |

## ユーザーストーリー

> 開発者として、APIをCloud Runにデプロイして、HTTPリクエストを受け付けられるようにしたい。

## 受け入れ条件

- [ ] Cloud Run サービスがデプロイされる
- [ ] health エンドポイントが応答する
- [ ] Terraformでインフラが管理される
- [ ] dev/prod環境の切り替えが可能

## 技術メモ

### Terraformモジュール
- `terraform/modules/api/` - Cloud Run + Cloud Armor
- `terraform/modules/network/` - VPC, サブネット

### なぜAWSから移行したか

旧構成（AWS CDK + Lambda + API Gateway + Aurora Serverless）ではdev環境だけで月額約$76かかっていた。GCPではCloud Runのスケールtoゼロ + Cloud SQLの最小インスタンスで月額約$15に削減できる。
