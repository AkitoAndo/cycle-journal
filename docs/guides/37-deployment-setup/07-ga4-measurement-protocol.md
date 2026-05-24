# 07. GA4 Measurement Protocol API secret 発行

## 目的

サーバーサイド（FastAPI）から GA4 にイベントを送信できるようにする。
PR #44 の `app/services/analytics_service.py` が `https://www.google-analytics.com/mp/collect` に POST する際に必要な **Measurement ID** と **API Secret** を発行する。

サーバーサイドで送るイベント:
- `trial_started` (StoreKit 購入時に iOS でも発火するが server 重複 OK)
- `trial_converted_to_paid` (ASSN V2 `DID_RENEW` 初回)
- `trial_expired_without_conversion` (ASSN V2 `EXPIRED`)
- `subscription_renewed`
- `subscription_cancelled`
- `subscription_refunded`

## 前提条件

- [06](06-firebase-analytics.md) 完了（Firebase Analytics が iOS で動作している）

## 手順

### 1. Measurement ID の確認

1. [Firebase Console](https://console.firebase.google.com/) → プロジェクト → **Project Settings**（歯車）
2. **Integrations** タブ → **Google Analytics → Manage**
3. [GA4 Admin](https://analytics.google.com/) に遷移
4. **Admin（歯車）** → **Data Streams** → 該当 iOS stream を選択
5. **Measurement ID** をコピー（`G-XXXXXXXXXX` 形式）

### 2. API Secret の発行

GA4 Admin の同じ Data Stream 詳細画面下部:

1. **Measurement Protocol API secrets**
2. **Create**
3. **Nickname**: `cyclejournal-api-server`
4. **Create**
5. **Secret value** をコピー（**一度しか表示されない**）

> Secret は 10 個まで発行可能。古いものは Revoke して入れ替えできる。

### 3. Secret Manager に格納

```bash
echo -n "G-XXXXXXXXXX" | \
  gcloud secrets create ga4-measurement-id --data-file=-

echo -n "your-secret-value-here" | \
  gcloud secrets create ga4-api-secret --data-file=-
```

### 4. Cloud Run の環境変数に注入

Terraform で:

```hcl
env {
  name = "GA4_MEASUREMENT_ID"
  value_source {
    secret_key_ref { secret = "ga4-measurement-id", version = "latest" }
  }
}
env {
  name = "GA4_API_SECRET"
  value_source {
    secret_key_ref { secret = "ga4-api-secret", version = "latest" }
  }
}
# GA4_ENDPOINT はデフォルト (Production) でよい。デバッグ時のみ /debug/mp/collect に切替
```

gcloud で:

```bash
gcloud run deploy cyclejournal-api \
  --update-secrets=GA4_MEASUREMENT_ID=ga4-measurement-id:latest,\
GA4_API_SECRET=ga4-api-secret:latest
```

### 5. サービスアカウントに権限付与

```bash
SERVICE_ACCOUNT="$(gcloud run services describe cyclejournal-api \
  --region=asia-northeast1 \
  --format='value(spec.template.spec.serviceAccountName)')"

for SECRET in ga4-measurement-id ga4-api-secret; do
  gcloud secrets add-iam-policy-binding "$SECRET" \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/secretmanager.secretAccessor"
done
```

## 検証

### Debug Endpoint でドライラン

GA4 には Production と同等の検証用エンドポイントがある:
`https://www.google-analytics.com/debug/mp/collect`

一時的に Cloud Run の `GA4_ENDPOINT` を debug 版に切り替え、Python REPL から呼ぶ:

```bash
cd api
.venv/bin/python <<'EOF'
import asyncio, os
os.environ["GA4_MEASUREMENT_ID"] = "G-XXXXXXXXXX"
os.environ["GA4_API_SECRET"] = "your-secret-value"
os.environ["GA4_ENDPOINT"] = "https://www.google-analytics.com/debug/mp/collect"

from app.services.analytics_service import send_event

async def main():
    result = await send_event(
        client_id="test-client-123",
        event_name="trial_converted_to_paid",
        params={"product_id": "yearly_14400", "revenue_jpy": 14400},
        event_id="test-uuid-1",
    )
    print(result)

asyncio.run(main())
EOF
```

`200` が返り、debug endpoint は `validationMessages: []` を返せば成功。

### Realtime レポート確認

Production endpoint に向けて Cloud Run から実イベントを送り、GA4 Realtime レポートに反映されるか:

1. ASSN V2 webhook を Sandbox で発火させる（[04](04-assn-v2-webhook.md) の Test Notification）
2. Cloud Run 内で `send_event` が呼ばれる（コード統合は後続 PR で）
3. GA4 → **Reports → Realtime** に `trial_converted_to_paid` イベントが 30 秒以内に表示

> Production レポート（Realtime 以外）には反映に 24-48 時間かかる。

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `400 Bad Request` | client_id 未設定 or params の型不正 | params の値は文字列・数値・bool のみ。Dict/Array 不可 |
| `2xx 返るが Realtime に出ない` | Measurement ID が iOS の物と違う | Data Streams で iOS stream の ID を再確認 |
| `event_id` で重複排除されない | event_id を params に入れていない | `app/services/analytics_service.py` の実装通り、params に同梱必須 |
| `send_event` が no-op になる | secret 未設定 | `gcloud secrets versions list ga4-api-secret` で確認 |

## 公式ドキュメント

- [GA4 Measurement Protocol](https://developers.google.com/analytics/devguides/collection/protocol/ga4)
- [Sending events](https://developers.google.com/analytics/devguides/collection/protocol/ga4/sending-events)
- [Validating events](https://developers.google.com/analytics/devguides/collection/protocol/ga4/validating-events)

## 次のステップ

→ [08. BigQuery export と Looker Studio ダッシュボード](08-bigquery-looker-studio.md)
