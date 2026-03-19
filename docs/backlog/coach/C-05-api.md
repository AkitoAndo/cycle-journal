# C-05: Backend API接続（Vertex AI）

| 項目 | 内容 |
|------|------|
| ステータス | :white_check_mark: Done |
| 優先度 | P0 |
| 依存 | A-02（認証ミドルウェア）, B-02（Firestore）, B-03（ベースプロンプト） |

## ユーザーストーリー

> ユーザーとして、コーチに話しかけたらAI（Claude）がCycleモデルに基づいて応答してほしい。

## 受け入れ条件

- [x] iOS → POST `/coach` → Cloud Run → Vertex AI Claude → 応答返却
- [x] セッションIDで会話の継続ができる
- [x] メッセージがFirestoreに保存される
- [x] ベースプロンプト（大樹スタイル）が適用されている
- [ ] 安全フィルターが動作している（B-04で対応予定）

## 実装内容

### Backend側
- `api/app/routers/coach.py` — POST `/coach` エンドポイント（認証必須）
- `api/app/services/coach_service.py` — Vertex AI Claude呼び出し（`anthropic[vertex]` SDK, ADC自動認証）
- セッション自動作成・メッセージ履歴取得・Firestore永続化
- SYSTEM_PROMPT（大樹メタファー + 7ルール）適用、temperature 0.7

### iOS側
- `CoachService.sendMessage()` — `requiresAuth: true` で実API接続
- `APIClient.swift` — base URLをCloud Runに更新済

### 検討事項（残タスク）
- ストリーミング応答（初期はなしでOK）
- 安全フィルター（B-04で対応）
