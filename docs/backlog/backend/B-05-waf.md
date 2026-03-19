# B-05: Cloud Armor設定

| 項目 | 内容 |
|------|------|
| ステータス | 削除 |
| 優先度 | - |

## 削除理由

MVP段階では不要。Cloud Run自体に基本的なDDoS耐性があり、FastAPI認証ミドルウェアで未認証リクエストは弾ける。ユーザーが増えてから検討する。

See: [アーキテクチャ概要](/architecture/overview) の「Cloud Armorは入れない理由」
