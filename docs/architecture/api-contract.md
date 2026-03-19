# API設計

API仕様の正式な定義は `docs/api/openapi.yaml` を参照。ここでは設計方針とルールを記載する。

## 設計方針

| 項目 | 方針 |
|------|------|
| スタイル | REST |
| バージョニング | なし（後方互換性を維持、破壊的変更時は新エンドポイント追加） |
| 認証 | Sign in with Apple JWT → Cloud Run ミドルウェアで検証 |
| 仕様書 | OpenAPI 3.0 (`openapi.yaml`が単一の真実) |

### なぜRESTか

GraphQLは個人プロジェクトのスコープではオーバー。Cloud RunでシンプルにHTTPを受けてOpenAPIで仕様を定義しやすい。

## 命名規則

- リソース名: 複数形・小文字（`/sessions`, `/tasks`）
- フィールド名: `snake_case`
- 日時: ISO 8601 UTC（`2024-01-01T00:00:00Z`）

## レスポンス形式

```json
// 成功時
{ "data": { ... } }

// エラー時
{
  "error": {
    "code": "ValidationError",
    "message": "The request body is invalid.",
    "details": [{ "field": "content", "message": "content is required" }]
  }
}
```

## HTTPステータスコード

| コード | 用途 |
|--------|------|
| 200 | 成功 (GET, PUT, PATCH) |
| 201 | 作成成功 (POST) |
| 204 | 成功・レスポンスなし (DELETE) |
| 400 | リクエスト不正 |
| 401 | 認証エラー |
| 403 | 認可エラー |
| 404 | リソースなし |
| 422 | バリデーションエラー |
| 429 | レート制限超過 |
| 500 | サーバーエラー |

## 認証フロー

```
1. iOS: Sign in with Apple で identityToken 取得
2. iOS → API: Authorization: Bearer {identityToken}
3. Cloud Run ミドルウェア: Apple公開鍵でJWT検証
4. 検証OK → ハンドラ実行
```

## エンドポイント一覧

| Method | Path | 説明 |
|--------|------|------|
| GET | `/health` | ヘルスチェック |
| POST | `/auth/verify` | Apple IDトークン検証 |
| POST | `/coach` | コーチとの会話 |
| GET | `/sessions` | セッション一覧 |
| POST | `/sessions` | セッション作成 |
| GET | `/sessions/{id}` | セッション詳細 |
| GET | `/tasks` | タスク一覧 |
| POST | `/tasks` | タスク作成 |
| PUT | `/tasks/{id}` | タスク更新 |
| DELETE | `/tasks/{id}` | タスク削除 |
| POST | `/tasks/{id}/reflection` | ふりかえり登録 |
| GET | `/users/me` | 自分のユーザー情報 |

## ログ

Cloud Logging に構造化JSONで出力:

```json
{
  "timestamp": "2024-01-01T00:00:00Z",
  "severity": "INFO",
  "request_id": "xxx",
  "user_id": "xxx",
  "message": "..."
}
```
