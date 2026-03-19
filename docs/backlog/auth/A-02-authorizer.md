# A-02: 認証ミドルウェア（JWT検証）

| 項目 | 内容 |
|------|------|
| ステータス | :white_check_mark: Done |
| 優先度 | P0 |
| 依存 | B-01（Terraform基本構成） |

## ユーザーストーリー

> 開発者として、APIリクエストのApple IDトークンを検証して、認証されたユーザーだけがAPIを利用できるようにしたい。

## 受け入れ条件

- [x] Apple公開鍵（JWKS）を取得してJWT署名を検証
- [x] トークンのissuer, audience, expiryを検証
- [x] 検証成功時にuser_idをリクエストコンテキストに渡す
- [x] 検証失敗時に401を返す

## 実装内容

### 実装ファイル
- `api/app/services/apple_auth.py` — Apple JWKS取得・インメモリキャッシュ・JWT検証
- `api/app/middleware/auth_middleware.py` — Bearerトークン抽出・検証ミドルウェア
- `api/app/dependencies.py` — `get_current_user` 依存（リクエストコンテキストからuser_id取得）

### Apple JWKS Endpoint
- `https://appleid.apple.com/auth/keys`

### 検証項目
- `iss` = `https://appleid.apple.com`
- `aud` = アプリのBundle ID（`com.cycle.journal`）
- `exp` > 現在時刻
- 署名: Apple公開鍵でRS256検証

### キャッシュ戦略
- Apple JWKS をインメモリキャッシュ（`apple_auth.py` 内で管理）
- キャッシュミス時のみ Apple サーバーにリクエスト

### 除外パス
- `/health` — 認証不要
- `/docs`, `/openapi.json` — dev環境のみ有効
