# A-02: 認証ミドルウェア（JWT検証）

| 項目 | 内容 |
|------|------|
| ステータス | :memo: Refinement |
| 優先度 | P0 |
| 依存 | B-01（Terraform基本構成） |

## ユーザーストーリー

> 開発者として、APIリクエストのApple IDトークンを検証して、認証されたユーザーだけがAPIを利用できるようにしたい。

## 受け入れ条件

- [ ] Apple公開鍵（JWKS）を取得してJWT署名を検証
- [ ] トークンのissuer, audience, expiryを検証
- [ ] 検証成功時にuser_idをリクエストコンテキストに渡す
- [ ] 検証失敗時に401を返す

## 検討事項

- Apple公開鍵のキャッシュ戦略（毎回取得 vs インメモリキャッシュ）
- トークンリフレッシュの仕組み（Apple ID Tokenは短命）
- ユーザー初回ログイン時のDB登録フロー

## 技術メモ

### 実装ファイル
- `api/src/middleware/auth.py`

### Apple JWKS Endpoint
- `https://appleid.apple.com/auth/keys`

### 検証項目
- `iss` = `https://appleid.apple.com`
- `aud` = アプリのClient ID
- `exp` > 現在時刻
