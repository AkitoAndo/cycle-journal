# B-02: Cloud SQL (PostgreSQL)

| 項目 | 内容 |
|------|------|
| ステータス | :memo: Refinement |
| 優先度 | P0 |
| 依存 | B-01（Terraform基本構成） |

## ユーザーストーリー

> 開発者として、セッション・メッセージ・ユーザーデータを永続化するDBが必要。

## 受け入れ条件

- [ ] Cloud SQL (PostgreSQL 15) がデプロイされる
- [ ] プライベートIPで配置
- [ ] Cloud RunからVPC Connector経由でアクセス可能
- [ ] Secret ManagerにDB接続情報が保存
- [ ] SQLAlchemyモデル + Alembicマイグレーションが動作

## 検討事項

- テーブル設計（users, sessions, messages, tasks, reflections）
- マイグレーション管理のワークフロー
- dev環境のインスタンスサイズ（db-f1-micro でコスト最小化）

## 技術メモ

### Terraformモジュール
- `terraform/modules/network/` - VPC + Serverless VPC Connector
- `terraform/modules/database/` - Cloud SQL + Secret Manager

### テーブル候補
- `users` (user_id, apple_user_id, email, display_name, settings, created_at)
- `sessions` (session_id, user_id, title, cycle_element, created_at)
- `messages` (message_id, session_id, role, content, metadata, created_at)
- `tasks` (task_id, user_id, title, description, status, session_id, cycle_element, created_at)
- `reflections` (reflection_id, task_id, what_i_did, what_i_noticed, what_i_want_to_try, created_at)
