# 04. App Store Server Notifications V2 URL 登録

## 目的

サブスクリプションの状態変化（購入・更新・解約・払戻し・refund・grace period 等）を Apple から CycleJournal バックエンドにリアルタイム通知する。PR #43 で実装した `POST /iap/apple/notifications` エンドポイントを App Store Connect に登録する。

## 前提条件

- [01](01-app-store-connect-iap.md) / [02](02-iap-key-secret-manager.md) / [03](03-apple-root-certs.md) 完了
- Cloud Run の `cyclejournal-api` が Sandbox / Production の 2 環境にデプロイ済（または同一サービスを env で切替）
- 各環境の HTTPS URL が判明している
  - 例: Sandbox `https://api-sandbox.cycle-journal.example.com/iap/apple/notifications`
  - 例: Production `https://api.cycle-journal.example.com/iap/apple/notifications`
- Cloud Run / API Gateway / Load Balancer で **認証不要**でこのパスに到達できる
  - Cloud Run の場合、`/iap/apple/notifications` だけ unauthenticated にするか、サービス全体を `--allow-unauthenticated` にする
  - 認証必要にしたい場合は事前共有シークレットを URL クエリに含めて検証する独自実装が必要（推奨はしない）

## 手順

### 1. URL 登録

1. [App Store Connect](https://appstoreconnect.apple.com/) → 対象アプリ → **App Information**
2. 右下にスクロール → **App Store Server Notifications** セクション
3. **Production Server URL**: `https://api.cycle-journal.example.com/iap/apple/notifications`
4. **Sandbox Server URL**: `https://api-sandbox.cycle-journal.example.com/iap/apple/notifications`
5. **Version**: **Version 2 Notifications** を選択（V1 は廃止予定なので必須で V2）
6. **Save**

> URL は HTTPS 必須。HTTP は受け付けられない。

### 2. Cloud Run の Ingress / 認証設定

```bash
# サービス全体を unauthenticated にする (シンプル、推奨)
gcloud run services add-iam-policy-binding cyclejournal-api \
  --region=asia-northeast1 \
  --member="allUsers" \
  --role="roles/run.invoker"

# Ingress を all に
gcloud run services update cyclejournal-api \
  --region=asia-northeast1 \
  --ingress=all
```

> 内部の他エンドポイント（`/coach`, `/tasks` 等）は別途 `Authorization: Bearer` JWT で保護されているので unauthenticated 化しても安全。`/iap/apple/notifications` は JWS で署名検証する設計（PR #43）。

### 3. Test Notification の送信

App Store Connect から手動でテスト通知を送って疎通確認:

1. App Store Connect → 対象アプリ → **App Store Server Notifications** セクション
2. **Request a Test Notification** ボタン
3. **Sandbox** を選択して **Send**
4. 数秒以内に Cloud Run のログにリクエストが記録される

```bash
gcloud logging read "resource.type=cloud_run_revision \
  AND resource.labels.service_name=cyclejournal-api \
  AND httpRequest.requestUrl:apple/notifications" \
  --limit 5 --format=json | jq '.[].httpRequest'
# 200 OK が返っていれば成功
```

Firestore の `iap_notifications` コレクションに `notificationType: TEST` のドキュメントが 1 件作成される:

```bash
gcloud firestore documents read \
  iap_notifications/<notificationUUID>
```

### 4. Production 側の有効化（リリース時）

- Production URL を入力したら App Review 提出時に Apple がエンドポイントの疎通を試す
- レビュー前に「Sandbox はテスト済、Production URL は同等動作」を Review Notes に記載

### 5. リトライ動作の理解

Apple は ACK が 200-206 以外、または 5 秒以内にレスポンスがない場合に **最大 5 回 / 72 時間** リトライする。
- 同じ `notificationUUID` で複数回届く可能性 → **冪等処理必須**（PR #43 で実装済: `AlreadyExists` で 200 "duplicate"）
- 4xx を返すと「これ以上送らないで」になる → JWS 検証失敗時は 400 が正解

## 検証

### 疎通確認チェックリスト

- [ ] App Store Connect で Production / Sandbox URL が緑チェック表示
- [ ] **Request a Test Notification** で 200 が返る
- [ ] Firestore `iap_notifications` コレクションに `TEST` タイプのドキュメントが作成される
- [ ] Cloud Run ログに JWS デコード結果（`notificationType: TEST` など）が出る
- [ ] 同じ `notificationUUID` の再送で 200 "duplicate" 応答（冪等）
- [ ] 改ざんした payload を送ると 400 InvalidSignature

### 改ざんテスト（手動）

```bash
# 適当な無効な signedPayload で 400 が返ること
curl -X POST https://api-sandbox.cycle-journal.example.com/iap/apple/notifications \
  -H "Content-Type: application/json" \
  -d '{"signedPayload":"invalid-jws-string"}'
# {"detail":"invalid signature: ..."}
```

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `Request a Test Notification` ボタンがグレー | 商品が "Waiting for Review" 状態 | [01](01-app-store-connect-iap.md) で Subscription を Submit |
| Test 通知が届かない | Cloud Run が unauthenticated でない | `roles/run.invoker` を `allUsers` に付与 |
| 200 を返したのに Apple がリトライ | 5 秒以内に応答できていない | BackgroundTasks で重い処理を後ろに回す（PR #43 で対応済） |
| 401 / 403 が返る | Cloud Run の Ingress 制限 | `--ingress=all` で外部到達可能に |
| JWS 検証が失敗する | Sandbox 通知を Production verifier で検証 | `payload.data.environment` で verifier を切替、または APPLE_IAP_ENV を Sandbox にしてデプロイ分離 |

## 公式ドキュメント

- [App Store Server Notifications V2](https://developer.apple.com/documentation/appstoreservernotifications/app-store-server-notifications-v2)
- [Enter server URLs for App Store Server Notifications](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/enter-server-urls-for-app-store-server-notifications/)
- [responseBodyV2DecodedPayload](https://developer.apple.com/documentation/appstoreservernotifications/responsebodyv2decodedpayload)
- [Testing notifications: Request a test notification](https://developer.apple.com/documentation/appstoreserverapi/request_a_test_notification)

## 次のステップ

→ [05. .storekit Configuration ファイル作成](05-storekit-config-xcode.md)
