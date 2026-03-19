# CycleJournal API 概要

## 概要

CycleJournal APIは、AIコーチング機能を提供するRESTful APIです。Cycleモデル（土・水・根・幹・枝・葉・実・空）に基づいた内省支援を行います。

---

## 基本情報

| 項目 | 値 |
|------|-----|
| ベースURL（dev） | `https://8sgr31xa31.execute-api.ap-northeast-1.amazonaws.com/dev` |
| プロトコル | HTTPS |
| 認証方式 | Sign in with Apple (JWT) |
| リージョン | ap-northeast-1（東京） |

---

## エンドポイント一覧

### システム

| メソッド | パス | 説明 | 認証 |
|---------|------|------|------|
| GET | `/health` | ヘルスチェック | 不要 |

### コーチング

| メソッド | パス | 説明 | 認証 |
|---------|------|------|------|
| POST | `/coach` | コーチとの会話 | 必要 |
| GET | `/sessions` | セッション一覧取得 | 必要 |
| GET | `/sessions/{session_id}` | セッション詳細取得 | 必要 |
| POST | `/sessions` | 新規セッション作成 | 必要 |

### タスク

| メソッド | パス | 説明 | 認証 |
|---------|------|------|------|
| GET | `/tasks` | タスク一覧取得 | 必要 |
| POST | `/tasks` | タスク作成 | 必要 |
| PUT | `/tasks/{task_id}` | タスク更新 | 必要 |
| DELETE | `/tasks/{task_id}` | タスク削除 | 必要 |
| POST | `/tasks/{task_id}/reflection` | タスクふりかえり登録 | 必要 |

### ユーザー

| メソッド | パス | 説明 | 認証 |
|---------|------|------|------|
| POST | `/auth/verify` | Apple IDトークン検証 | 不要 |
| GET | `/users/me` | 自分のユーザー情報取得 | 必要 |

---

## データ保存方針

| データ種別 | 保存先 | 備考 |
|-----------|--------|------|
| 日記 | ローカル（UserDefaults） | デバイスのみに保存 |
| タグ | ローカル（UserDefaults） | デバイスのみに保存 |
| コーチ会話 | クラウド（API） | サーバーに同期 |
| タスク | クラウド（API） | サーバーに同期 |
| ユーザー設定 | クラウド（API） | サーバーに同期 |

---

## 認証

### Sign in with Apple

1. iOSアプリでSign in with Appleを実行し、`identityToken`を取得
2. APIリクエストのAuthorizationヘッダーにトークンを設定

```
Authorization: Bearer {identityToken}
```

3. Lambda Authorizerがトークンを検証
4. 検証成功時、Lambda関数が実行される

詳細は [01_認証.md](./01_認証.md) を参照。

---

## リクエスト/レスポンス形式

### Content-Type

```
Content-Type: application/json
```

### 成功時レスポンス

```json
{
  "data": {
    // レスポンスデータ
  }
}
```

### エラー時レスポンス

```json
{
  "error": {
    "code": "ErrorCode",
    "message": "エラーの説明",
    "details": [
      {
        "field": "フィールド名",
        "message": "詳細メッセージ"
      }
    ]
  }
}
```

---

## HTTPステータスコード

| コード | 説明 | 用途 |
|--------|------|------|
| 200 | OK | GET, PUT, PATCH成功時 |
| 201 | Created | POST成功時（リソース作成） |
| 204 | No Content | DELETE成功時 |
| 400 | Bad Request | リクエスト形式エラー |
| 401 | Unauthorized | 認証エラー |
| 403 | Forbidden | 認可エラー |
| 404 | Not Found | リソースが存在しない |
| 422 | Unprocessable Entity | バリデーションエラー |
| 429 | Too Many Requests | レート制限超過 |
| 500 | Internal Server Error | サーバーエラー |

---

## 日時形式

全ての日時はISO 8601形式（UTC）で表現されます。

```
2024-01-01T00:00:00Z
```

---

## CORS

| 項目 | 設定 |
|------|------|
| Allowed Origins | `*`（dev環境）、本番ドメイン（prod環境） |
| Allowed Methods | GET, POST, PUT, DELETE, OPTIONS |
| Allowed Headers | Content-Type, Authorization |

---

## レート制限

| 項目 | 制限 |
|------|------|
| リクエスト数 | 10,000 req/sec（アカウント単位） |
| バースト | 5,000 req |

---

## 関連ドキュメント

- [01_認証.md](./01_認証.md) - 認証の詳細
- [02_エンドポイント一覧.md](./02_エンドポイント一覧.md) - 各エンドポイントの詳細仕様
- [openapi.yaml](./openapi.yaml) - OpenAPI 3.0仕様書
