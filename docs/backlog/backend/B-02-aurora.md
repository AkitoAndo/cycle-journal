# B-02: Firestore セットアップ

| 項目 | 内容 |
|------|------|
| ステータス | :white_check_mark: Done |
| 優先度 | P0 |
| 依存 | B-01（Terraform基本構成） |

## ユーザーストーリー

> 開発者として、セッション・メッセージ・ユーザーデータを永続化するDBが必要。

## 受け入れ条件

- [x] Firestoreが有効化される
- [x] Cloud Runから直接アクセス可能
- [x] Secret Managerに必要なシークレットが保存
- [x] コレクション構造（users/sessions/messages/tasks/reflections）が定義
- [x] 複合インデックス2つ作成済（sessions: user_id+created_at, tasks: user_id+status+created_at）

## 検討事項

- Firestoreセキュリティルール（Cloud Runからのみアクセス許可）
- インデックス設計（クエリパターンに応じて）
- dev/prod環境のDB分離方法

## 技術メモ

### Terraform
- `infra/firestore.tf` - Firestoreデータベース + インデックス
- `infra/secret_manager.tf` - Secret Manager

### コレクション構造
```
users/{userId}
├── sessions/{sessionId}
│   └── messages/{messageId}
├── tasks/{taskId}
│   └── reflections/{reflectionId}
└── (profile data)
```
