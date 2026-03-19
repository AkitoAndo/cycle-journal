# C-05: Backend API接続（Vertex AI）

| 項目 | 内容 |
|------|------|
| ステータス | :memo: Refinement |
| 優先度 | P0 |
| 依存 | A-02（認証ミドルウェア）, B-02（Firestore）, B-03（ベースプロンプト） |

## ユーザーストーリー

> ユーザーとして、コーチに話しかけたらAI（Claude）がCycleモデルに基づいて応答してほしい。

## 受け入れ条件

- [ ] iOS → POST `/coach` → Cloud Run → Vertex AI Claude → 応答返却
- [ ] セッションIDで会話の継続ができる
- [ ] メッセージがFirestoreに保存される
- [ ] ベースプロンプト（大樹スタイル）が適用されている
- [ ] 安全フィルターが動作している

## 検討事項

- ストリーミング応答は必要か（初期はなしでOK？）
- タイムアウト時のUX（Cloud Runは最大300秒まで設定可能）
- リトライ戦略

## 技術メモ

### iOS側
- `CoachStore.sendMessage()` の `useAPI` フラグを切り替え
- `CoachService.sendMessage()` → APIClient → POST `/coach`

### Backend側
- `src/handlers/coach.py` にVertex AI呼び出しを実装
- プロンプトは `src/prompts/base.py` から読み込み
- レスポンスに `metadata`（detected_emotion, cycle_element）を含める
