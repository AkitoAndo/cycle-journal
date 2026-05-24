# #37 デプロイメントセットアップ手順

Issue #37 で実装した B 系（AI モデル分離）／A 系（IAP）／C 系（オンボーディング・通知・Analytics）を **本番稼働させるための手動セットアップ手順** をまとめた索引。

PR #42 〜 #47 のコードはすべて main にマージ済だが、以下の外部システム設定が揃わないと動かない。**順序通りに進めることを推奨**。

## 進行表

| # | ドキュメント | 想定時間 | 担当 | 完了条件 |
|---|---|---|---|---|
| 01 | [App Store Connect: サブスクリプション商品設定](01-app-store-connect-iap.md) | 30 分 | 開発者 | `monthly_1800` / `yearly_14400` 商品が "Ready to Submit" 状態 |
| 02 | [IAP Key (.p8) と Secret Manager](02-iap-key-secret-manager.md) | 20 分 | 開発者 | Cloud Run 環境変数に `APPLE_IAP_PRIVATE_KEY` が注入されている |
| 03 | [Apple PKI ルート証明書配置](03-apple-root-certs.md) | 10 分 | 開発者 | `api/app/certs/AppleRootCA-G3.cer` が存在し Docker イメージに含まれる |
| 04 | [App Store Server Notifications V2 URL 登録](04-assn-v2-webhook.md) | 15 分 | 開発者 | Sandbox / Production 両方の URL が登録され、Test Notification が 200 で返る |
| 05 | [.storekit Configuration ファイル作成](05-storekit-config-xcode.md) | 15 分 | 開発者 | Xcode の Scheme で `Configuration.storekit` が選択され、シミュレータで Sandbox 課金なしに動作 |
| 06 | [Firebase Project / iOS SDK 統合](06-firebase-analytics.md) | 30 分 | 開発者 | `GoogleService-Info.plist` が `ios/Cycle/` に存在し、Crashlytics ダッシュボードに最初のセッションが届く |
| 07 | [GA4 Measurement Protocol API secret 発行](07-ga4-measurement-protocol.md) | 10 分 | 開発者 | Secret Manager に `GA4_API_SECRET` が格納され、Cloud Run 環境変数で参照 |
| 08 | [BigQuery export と Looker Studio ダッシュボード](08-bigquery-looker-studio.md) | 60 分 | 開発者 | Looker Studio に「Trial→Paid 転換率」「3ヶ月継続率」のグラフが出ている |
| 09 | [Vertex AI Model Garden のモデル ID 検証](09-vertex-ai-models.md) | 10 分 | 開発者 | `claude-sonnet-4-5@...` / `claude-haiku-4-5@...` が `asia-northeast1` で GA 確認済 |
| 10 | [Terms / Privacy URL の差し替え](10-legal-urls.md) | 10 分 | 開発者 | `PaywallView.swift` の `termsURL` / `privacyURL` が公開 URL に差し替え済 |

合計目安: 約 3 時間。

## 依存関係

```
01 (App Store Connect 商品)
  ├──> 04 (ASSN V2 URL 登録)
  └──> 05 (.storekit Config)
02 (IAP Key) ──> 04 (ASSN V2 URL 登録: 検証に必要)
03 (Apple PKI) ──> 04 (検証に必要)
06 (Firebase Project) ──> 07 (GA4 secret) ──> 08 (BQ export)
09 (Vertex AI) [独立]
10 (Legal URL) [独立]
```

## 完了後の動作確認

すべてのセットアップが完了したら [動作確認チェックリスト](verification-checklist.md) を実施する。

## 公式ドキュメント早見表

| 領域 | 公式 URL |
|---|---|
| App Store Connect Help | https://developer.apple.com/help/app-store-connect/ |
| Apple Developer: Auto-Renewable Subscriptions | https://developer.apple.com/documentation/storekit/in-app_purchase/auto-renewable_subscriptions |
| App Store Server API | https://developer.apple.com/documentation/appstoreserverapi |
| App Store Server Notifications V2 | https://developer.apple.com/documentation/appstoreservernotifications |
| Apple PKI Repository | https://www.apple.com/certificateauthority/ |
| Firebase iOS SDK | https://firebase.google.com/docs/ios/setup |
| GA4 Measurement Protocol | https://developers.google.com/analytics/devguides/collection/protocol/ga4 |
| Firebase → BigQuery export | https://firebase.google.com/docs/projects/bigquery-export |
| Looker Studio | https://lookerstudio.google.com/ |
| Vertex AI: Claude models | https://cloud.google.com/vertex-ai/generative-ai/docs/partner-models/use-claude |
| App Store Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ |
