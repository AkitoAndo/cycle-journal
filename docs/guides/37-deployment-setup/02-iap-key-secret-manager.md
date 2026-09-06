# 02. IAP Key (.p8) と Secret Manager

## 目的

App Store Server API を呼び出すための ES256 署名用 `.p8` 秘密鍵を発行し、Google Cloud Secret Manager 経由で Cloud Run に注入する。

`.p8` は Sign in with Apple 用の鍵とは **別物**。In-App Purchase 専用キー（Users and Access → Integrations → In-App Purchase）が必要。

## 前提条件

- [01](01-app-store-connect-iap.md) 完了
- App Store Connect の **Admin** ロール
- GCP プロジェクト `cycle-journal` への `roles/secretmanager.admin` 権限
- `gcloud` CLI 認証済（`gcloud auth login` + `gcloud config set project cycle-journal`）

## 手順

### 1. In-App Purchase Key の発行

1. [App Store Connect](https://appstoreconnect.apple.com/) → **Users and Access** → **Integrations** タブ
2. 左サイドバーの **In-App Purchase** を選択
3. **Generate In-App Purchase Key** ボタン
4. **Name**: `Treow IAP Server Key`
5. **Generate**
6. **`AuthKey_XXXXXXXXXX.p8`** をダウンロード（**一度しかダウンロードできない**ので必ず安全に保管）
7. 表示される以下の値を控える:
   - **Key ID** (例: `9ABCDEFGHI`) — 10 文字
   - **Issuer ID** (アカウント全体で固定、UUID 形式) — `0123abcd-4567-89ef-...`
   - **Bundle ID**: `com.akitoando.CycleJournal`

### 2. Secret Manager に格納

```bash
# Issuer ID
echo -n "0123abcd-4567-89ef-XXXX-XXXXXXXXXXXX" | \
  gcloud secrets create apple-iap-issuer-id --data-file=-

# Key ID
echo -n "9ABCDEFGHI" | \
  gcloud secrets create apple-iap-key-id --data-file=-

# Private Key (.p8 ファイル全体を改行込みで)
gcloud secrets create apple-iap-private-key \
  --data-file=./AuthKey_9ABCDEFGHI.p8

# (Production のみ) App Apple ID
echo -n "1234567890" | \
  gcloud secrets create apple-iap-app-apple-id --data-file=-
```

> `.p8` ファイルは Secret Manager に格納したら **ローカルからも安全に削除**（`rm -P ./AuthKey_*.p8`）。再発行不可なので、組織のパスワードマネージャか別途バックアップは保持しておくことを推奨。

### 3. Cloud Run に環境変数として注入

`infra/` ディレクトリの Terraform 構成（または Cloud Run YAML）で以下を追加:

```hcl
# infra/cloudrun.tf (例)
resource "google_cloud_run_v2_service" "api" {
  # ...
  template {
    containers {
      # ...
      env {
        name = "APPLE_IAP_ISSUER_ID"
        value_source {
          secret_key_ref {
            secret  = "apple-iap-issuer-id"
            version = "latest"
          }
        }
      }
      env {
        name = "APPLE_IAP_KEY_ID"
        value_source {
          secret_key_ref { secret = "apple-iap-key-id", version = "latest" }
        }
      }
      env {
        name = "APPLE_IAP_PRIVATE_KEY"
        value_source {
          secret_key_ref { secret = "apple-iap-private-key", version = "latest" }
        }
      }
      env {
        name  = "APPLE_IAP_ENV"
        value = "Sandbox"  # Production デプロイ時は "Production"
      }
      env {
        name = "APPLE_IAP_APP_APPLE_ID"
        value_source {
          secret_key_ref { secret = "apple-iap-app-apple-id", version = "latest" }
        }
      }
    }
  }
}
```

`gcloud` で手動デプロイの場合:

```bash
gcloud run deploy cyclejournal-api \
  --update-secrets=APPLE_IAP_ISSUER_ID=apple-iap-issuer-id:latest,\
APPLE_IAP_KEY_ID=apple-iap-key-id:latest,\
APPLE_IAP_PRIVATE_KEY=apple-iap-private-key:latest,\
APPLE_IAP_APP_APPLE_ID=apple-iap-app-apple-id:latest \
  --set-env-vars=APPLE_IAP_ENV=Sandbox
```

### 4. Cloud Run サービスアカウントに Secret Manager 読取権限を付与

```bash
SERVICE_ACCOUNT="$(gcloud run services describe cyclejournal-api \
  --region=asia-northeast1 \
  --format='value(spec.template.spec.serviceAccountName)')"

for SECRET in apple-iap-issuer-id apple-iap-key-id apple-iap-private-key apple-iap-app-apple-id; do
  gcloud secrets add-iam-policy-binding "$SECRET" \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/secretmanager.secretAccessor"
done
```

## 検証

### Cloud Run 上で環境変数が読めるか

```bash
# /health に環境変数のセットだけ確認するデバッグエンドポイントを一時的に追加するか、
# ログ確認:
gcloud logging read "resource.type=cloud_run_revision \
  AND resource.labels.service_name=cyclejournal-api" \
  --limit 20 --format=json | jq '.[].textPayload' | grep -i "apple_iap"
```

### App Store Server API への JWT 署名テスト

ローカルで一時的に `.p8` を使い、Python で JWT を生成して `/inApps/v1/transactions/{id}` を叩く:

```python
# scripts/test_app_store_api.py (動作確認用、コミットしない)
import jwt, time, os, requests

key_id = "9ABCDEFGHI"
issuer_id = "0123abcd-...."
bundle_id = "com.akitoando.CycleJournal"
private_key = open("./AuthKey_9ABCDEFGHI.p8").read()

token = jwt.encode(
    {
        "iss": issuer_id,
        "iat": int(time.time()),
        "exp": int(time.time()) + 1500,
        "aud": "appstoreconnect-v1",
        "bid": bundle_id,
    },
    private_key,
    algorithm="ES256",
    headers={"alg": "ES256", "kid": key_id, "typ": "JWT"},
)

# Sandbox 環境の任意の transactionId で試す
resp = requests.get(
    "https://api.storekit-sandbox.itunes.apple.com/inApps/v1/transactions/{tx_id}".format(
        tx_id="2000000000000001"
    ),
    headers={"Authorization": f"Bearer {token}"},
)
print(resp.status_code, resp.text[:200])
```

`200` または `404`（テスト用 ID なので存在しない）が返れば JWT 署名は正常。`401` なら鍵か Issuer ID が誤り。

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `401 Unauthorized` | Issuer ID 誤り or .p8 の改ざん | App Store Connect で再確認、PEM 改行が壊れていないか確認 |
| `403 Forbidden` | Bundle ID 不一致 | JWT の `bid` クレームが App Store Connect 登録と完全一致しているか |
| Secret Manager `Permission denied` | Cloud Run SA に IAM 不足 | 上記手順 4 で `roles/secretmanager.secretAccessor` 付与 |
| `gcloud secrets create` 失敗 | 重複作成 | `versions add` で更新 |

## 公式ドキュメント

- [Creating API Keys to Use With the App Store Server API](https://developer.apple.com/documentation/appstoreserverapi/creating-api-keys-to-use-with-the-app-store-server-api)
- [Generating JSON Web Tokens for API Requests](https://developer.apple.com/documentation/appstoreserverapi/generating-json-web-tokens-for-api-requests)
- [Google Cloud Secret Manager](https://cloud.google.com/secret-manager/docs)
- [Cloud Run: Use secrets](https://cloud.google.com/run/docs/configuring/secrets)

## 次のステップ

→ [03. Apple PKI ルート証明書配置](03-apple-root-certs.md)
