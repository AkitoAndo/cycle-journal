# B-05: Cloud Armor設定

| 項目 | 内容 |
|------|------|
| ステータス | :memo: Refinement |
| 優先度 | P2 |
| 依存 | B-01（Terraform基本構成） |

## ユーザーストーリー

> 開発者として、APIを一般的なWeb攻撃やDDoSから保護したい。

## 受け入れ条件

- [ ] Cloud ArmorポリシーがCloud Runに適用
- [ ] OWASP Top 10ルール有効
- [ ] IPベースのレートリミット（1000 req/5min/IP）

## 技術メモ

### Terraformモジュール
- `terraform/modules/api/` - Cloud Armor policy
