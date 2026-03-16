# API リファレンス

## 基本情報

| 項目 | 値 |
|------|-----|
| ベース URL（dev） | `https://8sgr31xa31.execute-api.ap-northeast-1.amazonaws.com/dev` |
| プロトコル | HTTPS |
| 認証方式 | Bearer Token（Sign in with Apple JWT） |
| リージョン | ap-northeast-1（東京） |
| レート制限 | 100 req/s、バースト 200 req |

## レスポンス形式

### 成功レスポンス

```json
{
  "data": {
    // レスポンスペイロード
  }
}
```

### エラーレスポンス

```json
{
  "error": {
    "code": "ErrorCode",
    "message": "エラーの説明",
    "details": [
      { "field": "フィールド名", "message": "詳細" }
    ]
  }
}
```

### HTTP ステータスコード

| コード | 意味 | 用途 |
|--------|------|------|
| 200 | OK | GET, PUT, PATCH 成功 |
| 201 | Created | POST 成功（リソース作成） |
| 204 | No Content | DELETE 成功 |
| 400 | Bad Request | リクエスト形式エラー |
| 401 | Unauthorized | 認証失敗 |
| 403 | Forbidden | 認証済みだが権限なし |
| 404 | Not Found | リソース未発見 |
| 500 | Internal Server Error | サーバーエラー |

---

## エンドポイント

### GET /health

ヘルスチェック。認証不要。

**レスポンス 200:**

```json
{
  "status": "healthy",
  "stage": "dev",
  "timestamp": "2024-01-01T00:00:00.000000"
}
```

---

### POST /auth/verify

Apple ID トークンを検証し、ユーザー情報を返す。

**リクエストボディ:**

```json
{
  "identity_token": "eyJhbGciOiJSUzI1NiIs..."
}
```

**レスポンス 200:**

```json
{
  "data": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "apple_user_id": "001234.abcdef1234567890.1234",
    "email": "user@privaterelay.appleid.com",
    "is_new_user": false,
    "verified": true
  }
}
```

**エラーレスポンス:**

| コード | 条件 |
|--------|------|
| 400 | identity_token が未指定 |
| 401 | トークン検証失敗（期限切れ、署名不正等） |
| 500 | Apple 公開鍵の取得失敗 |

**検証プロセス:**
1. JWT ヘッダーから `kid` を抽出
2. Apple の公開鍵エンドポイント (`https://appleid.apple.com/auth/keys`) から RSA 公開鍵を取得（1時間キャッシュ）
3. RS256 アルゴリズムで署名を検証
4. `aud`（Bundle ID）と `iss`（Apple）を検証
5. JWT クレームからユーザー情報を抽出

---

### POST /coach

AI コーチにメッセージを送信し、応答を受け取る。

**ヘッダー:**

```
Authorization: Bearer {identityToken}
```

**リクエストボディ:**

```json
{
  "message": "今日は仕事でちょっと疲れました",
  "diary_content": "今日の日記の内容（任意）"
}
```

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| message | string | ✅ | ユーザーのメッセージ |
| diary_content | string | ❌ | 日記コンテキスト（対話の補足情報） |

**レスポンス 200:**

```json
{
  "data": {
    "message": "お疲れさまでした。今日は何が一番エネルギーを使いましたか？",
    "session_id": "550e8400-e29b-41d4-a716-446655440001",
    "metadata": {
      "stage": "dev",
      "model": "claude-3-haiku",
      "cycle_element": "leaf",
      "detected_emotion": "fatigue",
      "response_type": "empathetic_inquiry"
    }
  }
}
```

| メタデータ | 説明 |
|-----------|------|
| cycle_element | Cycle モデル要素（soil/water/root/trunk/branch/leaf/fruit/sky） |
| detected_emotion | 検出された感情 |
| response_type | 応答タイプ |

**LLM 設定:**

| パラメータ | 値 |
|-----------|-----|
| モデル | Claude 3 Haiku (`anthropic.claude-3-haiku-20240307-v1:0`) |
| Temperature | 0.7 |
| Max tokens | 500 |

---

## 計画中のエンドポイント

以下のエンドポイントは設計済みですが、まだ実装されていません。

### セッション管理

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/sessions` | セッション一覧取得 |
| POST | `/sessions` | 新規セッション作成 |
| GET | `/sessions/{session_id}` | セッション詳細取得 |

### タスク管理

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/tasks` | タスク一覧取得 |
| POST | `/tasks` | タスク作成 |
| PUT | `/tasks/{task_id}` | タスク更新 |
| DELETE | `/tasks/{task_id}` | タスク削除 |
| POST | `/tasks/{task_id}/reflection` | ふりかえり登録 |

### ユーザー

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/users/me` | 自分のユーザー情報取得 |

---

## CORS 設定

| 項目 | 値 |
|------|-----|
| Allowed Origins | `*`（全オリジン） |
| Allowed Methods | GET, POST, PUT, DELETE, OPTIONS |
| Allowed Headers | Content-Type, Authorization |
