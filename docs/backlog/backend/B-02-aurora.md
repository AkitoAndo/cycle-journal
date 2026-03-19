# B-02: Aurora Serverless + VPC

| 項目 | 内容 |
|------|------|
| ステータス | :memo: Refinement |
| 優先度 | P0 |
| 依存 | B-01（CDK基本構成） |

## ユーザーストーリー

> 開発者として、セッション・メッセージ・ユーザーデータを永続化するDBが必要。

## 受け入れ条件

- [ ] Aurora Serverless v2 (PostgreSQL 15) がデプロイされる
- [ ] VPC + Private Subnetに配置
- [ ] LambdaからVPC経由でアクセス可能
- [ ] Secrets ManagerにDB接続情報が保存
- [ ] SQLAlchemyモデル + Alembicマイグレーションが動作

## 検討事項

- テーブル設計（users, sessions, messages, tasks, reflections）
- マイグレーション管理のワークフロー
- dev環境のACU設定（コスト最小化）

## 技術メモ

### CDKスタック
- `api/cdk/stacks/network_stack.py` - VPC
- `api/cdk/stacks/db_stack.py` - Aurora + Secrets

### テーブル候補
- `users` (user_id, apple_user_id, email, display_name, settings, created_at)
- `sessions` (session_id, user_id, title, cycle_element, created_at)
- `messages` (message_id, session_id, role, content, metadata, created_at)
- `tasks` (task_id, user_id, title, description, status, session_id, cycle_element, created_at)
- `reflections` (reflection_id, task_id, what_i_did, what_i_noticed, what_i_want_to_try, created_at)
