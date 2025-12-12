# API設計方針

## 概要

CycleJournal APIの設計方針・規約を定義。

## API仕様書

| 項目 | 選定 |
|------|------|
| フォーマット | OpenAPI 3.0 (Swagger) |
| ホスティング | Redocly |
| 管理場所 | `api/docs/openapi.yaml` |

## エンドポイント設計

### バージョニング

- **方針**: バージョニングなし
- 後方互換性を維持して運用
- 破壊的変更が必要な場合は新エンドポイント追加

### 命名規則

```
# リソース名: 複数形・小文字
GET /sessions
POST /sessions

# フィールド名: snake_case
{
  "user_id": "xxx",
  "created_at": "2024-01-01T00:00:00Z"
}
```

### 日時形式

- **形式**: ISO 8601 (UTC)
- **例**: `2024-01-01T00:00:00Z`

## レスポンス形式

### 成功時

```json
{
  "data": {
    "id": "xxx",
    "message": "..."
  }
}
```

### エラー時 (AWS準拠)

```json
{
  "error": {
    "code": "ValidationError",
    "message": "The request body is invalid.",
    "details": [
      {
        "field": "content",
        "message": "content is required"
      }
    ]
  }
}
```

## HTTPステータスコード

厳密にHTTP仕様に準拠。

| コード | 用途 |
|--------|------|
| 200 | 成功 (GET, PUT, PATCH) |
| 201 | 作成成功 (POST) |
| 204 | 成功・レスポンスなし (DELETE) |
| 400 | リクエスト不正 |
| 401 | 認証エラー |
| 403 | 認可エラー |
| 404 | リソースなし |
| 409 | 競合 |
| 422 | バリデーションエラー |
| 429 | レート制限超過 |
| 500 | サーバーエラー |
| 503 | サービス利用不可 |

## 認証

| 項目 | 選定 |
|------|------|
| 方式 | Sign in with Apple |
| トークン検証 | Lambda Authorizer |
| トークン形式 | JWT (Apple ID Token) |

### 認証フロー

```
1. iOS: Sign in with Apple で identityToken 取得
2. iOS → API: Authorization: Bearer {identityToken}
3. Lambda Authorizer: Apple公開鍵でJWT検証
4. 検証OK → Lambda実行
```

## レート制限

| 項目 | 設定 |
|------|------|
| 方式 | API Gateway標準 |
| 制限 | 10,000 req/sec (アカウント単位) |
| バースト | 5,000 req |

## CORS

| 項目 | 設定 |
|------|------|
| 有効 | Yes |
| Origin | 本番ドメイン + localhost |
| Methods | GET, POST, PUT, DELETE, OPTIONS |
| Headers | Content-Type, Authorization |

## ページネーション

- **方針**: 必要になったら要相談
- 候補: Cursorベース or Offset/Limit

## ログ出力

| 項目 | 選定 |
|------|------|
| 出力先 | CloudWatch Logs |
| 形式 | 構造化JSON |

### ログフォーマット

```json
{
  "timestamp": "2024-01-01T00:00:00Z",
  "level": "INFO",
  "request_id": "xxx",
  "user_id": "xxx",
  "message": "..."
}
```

## シークレット管理

| 項目 | 選定 |
|------|------|
| ツール | AWS Secrets Manager |
| 管理対象 | DB接続情報、外部API鍵 |
