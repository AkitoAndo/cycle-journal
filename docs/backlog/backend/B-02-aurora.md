# B-02: Firestore セットアップ

| 項目 | 内容 |
|------|------|
| ステータス | :memo: Refinement |
| 優先度 | P0 |
| 依存 | B-01（Terraform基本構成） |

## ユーザーストーリー

> 開発者として、セッション・メッセージ・ユーザーデータを永続化するDBが必要。

## 受け入れ条件

- [ ] Firestoreが有効化される
- [ ] Cloud Runから直接アクセス可能
- [ ] Secret Managerに必要なシークレットが保存
- [ ] コレクション構造（users/sessions/messages/tasks/reflections）が定義

## 検討事項

- Firestoreセキュリティルール（Cloud Runからのみアクセス許可）
- インデックス設計（クエリパターンに応じて）
- dev/prod環境のDB分離方法

## 技術メモ

### Terraformモジュール
- `terraform/modules/database/` - Firestore + Secret Manager

### コレクション構造
```
users/{userId}
├── sessions/{sessionId}
│   └── messages/{messageId}
├── tasks/{taskId}
│   └── reflections/{reflectionId}
└── (profile data)
```
