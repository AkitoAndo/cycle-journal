# 03. Apple PKI ルート証明書配置

## 目的

App Store Server Notifications V2 / Server API のレスポンスは JWS（JSON Web Signature）で署名されている。サーバー側で署名検証するために Apple のルート CA 証明書が必要。

`app-store-server-library` の `SignedDataVerifier` は引数で証明書バイト列を要求する。本プロジェクトでは `api/app/certs/*.cer` を起動時に読み込む実装（PR #43）。

## 前提条件

- リポジトリのクローン
- Docker イメージビルドができる環境（または `gcloud builds submit` が動く環境）

## 手順

### 1. Apple PKI Repository から証明書を取得

公式ページ: https://www.apple.com/certificateauthority/

ダウンロードする証明書:

| ファイル名 | 用途 | URL |
|---|---|---|
| `AppleRootCA-G3.cer` | StoreKit 2 / ASSN V2 / Server API 検証用（ES256） | https://www.apple.com/certificateauthority/AppleRootCA-G3.cer |
| `AppleIncRootCertificate.cer` | 旧 SHA-1 ルート（後方互換、必須ではないが推奨） | https://www.apple.com/appleca/AppleIncRootCertificate.cer |

> 注: G3 は `/appleca/` パスが 404 になるため `/certificateauthority/` を使う（2026-06 時点で確認済）。Inc ルートは `/appleca/` のままで取得可。

```bash
mkdir -p api/app/certs
cd api/app/certs

curl -fsSL -o AppleRootCA-G3.cer https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
curl -fsSL -o AppleIncRootCertificate.cer https://www.apple.com/appleca/AppleIncRootCertificate.cer
```

### 2. 証明書の検証

ダウンロードした証明書が正しいか SHA-256 で確認:

```bash
shasum -a 256 AppleRootCA-G3.cer
# 期待値: 63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179
# (公式は時々入れ替えるので最新を https://www.apple.com/certificateauthority/ で確認)

openssl x509 -inform DER -in AppleRootCA-G3.cer -noout -subject -issuer -dates
# Subject: CN=Apple Root CA - G3, OU=Apple Certification Authority, O=Apple Inc., C=US
# Issuer:  CN=Apple Root CA - G3, OU=Apple Certification Authority, O=Apple Inc., C=US
# notBefore=Apr 30 18:19:06 2014 GMT
# notAfter =Apr 30 18:19:06 2039 GMT
```

### 3. `.gitignore` 設定の確認

証明書は公開情報なのでコミットして問題ない（Apple Inc. 配布物、再頒布許可あり）。ただし「秘密鍵を誤って同ディレクトリに置いてしまった」事故を防ぐため、`*.p8` だけ ignore する設定にする:

```bash
# api/app/certs/.gitignore (新規作成)
*.p8
*.pem
*.key
```

```bash
cat > api/app/certs/.gitignore <<'EOF'
# IAP / Sign in with Apple 秘密鍵はここに置かない (Secret Manager で管理)
*.p8
*.pem
*.key
EOF

# 証明書ファイル自体はコミット対象
git add api/app/certs/AppleRootCA-G3.cer
git add api/app/certs/AppleIncRootCertificate.cer
git add api/app/certs/.gitignore
```

### 4. Docker イメージに含まれることを確認

`api/Dockerfile` を確認:

```dockerfile
# 既存 Dockerfile が COPY app/ /app/app/ のように broad copy しているなら、
# certs ディレクトリも自動的に含まれる。
# 明示的に確認するなら:
COPY app/certs/*.cer /app/app/certs/
```

ビルド & 確認:

```bash
docker build -t cyclejournal-api:test ./api
docker run --rm cyclejournal-api:test ls /app/app/certs/
# AppleIncRootCertificate.cer
# AppleRootCA-G3.cer
```

## 検証

### Python で読み込みテスト

```bash
cd api
.venv/bin/python -c "
from app.services.iap_verifier import load_root_certificates
roots = load_root_certificates()
print(f'Loaded {len(roots)} certs')
for r in roots:
    print(f'  size={len(r)} bytes')
"
# Loaded 2 certs
#   size=NNN bytes
#   size=NNN bytes
```

`0 certs` だった場合は配置場所か Dockerfile を見直す。

### SignedDataVerifier の構築

```python
from app.config import settings
from app.services.iap_verifier import build_verifier

v = build_verifier(settings)
print(type(v).__name__)  # SignedDataVerifier
```

例外なくインスタンス化できれば OK。

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `ValueError: Invalid certificate` | DER フォーマットでない | `.cer` を `openssl x509 -inform DER -in ...` で読めるか確認、PEM の場合は `-inform PEM` か再ダウンロード |
| `load_root_certificates()` が `[]` | パスが違う | `api/app/certs/` の絶対パスを `_CERTS_DIR` ログで確認 |
| Docker 内で見つからない | COPY パターンが broad copy していない | Dockerfile に明示的に `COPY app/certs/*.cer` を追加 |

## 公式ドキュメント

- [Apple PKI Repository](https://www.apple.com/certificateauthority/)
- [App Store Server Library: signed_data_verifier](https://github.com/apple/app-store-server-library-python)

## 次のステップ

→ [04. App Store Server Notifications V2 URL 登録](04-assn-v2-webhook.md)
