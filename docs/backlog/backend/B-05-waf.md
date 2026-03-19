# B-05: WAF設定

| 項目 | 内容 |
|------|------|
| ステータス | :memo: Refinement |
| 優先度 | P2 |
| 依存 | B-01（CDK基本構成） |

## ユーザーストーリー

> 開発者として、APIを一般的なWeb攻撃やDDoSから保護したい。

## 受け入れ条件

- [ ] AWS WAFがAPI Gatewayに適用
- [ ] AWSManagedRulesCommonRuleSet 有効
- [ ] AWSManagedRulesKnownBadInputsRuleSet 有効
- [ ] IPベースのレートリミット（1000 req/5min/IP）

## 技術メモ

### CDKスタック
- `api/cdk/stacks/monitoring_stack.py`
