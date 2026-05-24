# 動作確認チェックリスト

セットアップ [01](01-app-store-connect-iap.md) 〜 [10](10-legal-urls.md) がすべて完了したあと、エンドツーエンドで動作確認するためのチェックリスト。

## 1. 単体確認

### A backend (IAP webhook)

- [ ] Cloud Run の `cyclejournal-api` がデプロイされている
- [ ] `gcloud secrets list | grep apple-iap` で 4 つの secret が存在
- [ ] Cloud Run ログに `Loaded N certs` (N >= 1) が出ている
- [ ] `curl https://api.../iap/apple/notifications -d '{}'` で `400 missing signedPayload` が返る
- [ ] App Store Connect の **Request a Test Notification** で 200 が返り、Firestore `iap_notifications` に `TEST` ドキュメントが作成される

### A iOS (StoreKit 2 + Paywall)

- [ ] `Configuration.storekit` がプロジェクトに含まれている
- [ ] Scheme で `.storekit` が選択されている（local テスト用）/ または None（Sandbox / Production テスト用）
- [ ] シミュレータ起動 → Paywall 到達 → `Product.products(for:)` が 2 件返る
- [ ] 「7日間無料で始める」タップ → `state == .trial(...)` になる
- [ ] **Debug → StoreKit → Manage Transactions** で Refund → `state == .expired` になる

### B (AI モデル分離)

- [ ] `/coach` を認証付きで叩く → 応答が返る
- [ ] Cloud Run ログに `claude-sonnet-4-5@...` 呼び出し（generate_response）が記録される
- [ ] LangGraph を有効化（`USE_LANGGRAPH=true`）した場合、`claude-haiku-4-5@...` 呼び出し（analyze_emotion 等）も出る
- [ ] 同一 system prompt の連続呼び出しで `cache_read_input_tokens > 0`（Vertex AI レスポンスメタで確認、または Anthropic 直 API ログ）

### C-1 (オンボーディングフロー)

- [ ] アプリ初回起動 → Welcome → Cycle 概念 → Goal 選択（必須）→ Sign In → 初ジャーナル（必須）→ 通知 opt-in → Paywall の順に遷移
- [ ] Goal 未選択で「つぎへ」を押しても進まない
- [ ] 初ジャーナルテキスト空のままでは進まない
- [ ] Paywall で購入完了 → ホームに遷移

### C-2 (トライアル通知)

- [ ] `.storekit` の Time Rate を `1s = 1d` にしてシミュレータで購入
- [ ] Day1/3/6/7 のローカル通知がスケジュールされている
  ```bash
  xcrun simctl spawn booted log stream | grep "trial.day"
  ```
- [ ] StoreKit Manage Transactions で auto-renew をオフ → 通知が cancel される（解約検知連携 PR が必要）

### C-3 (Analytics)

- [ ] Firebase Analytics DebugView に `app_opened` / `signup_succeeded` / `journal_first_entry_created` が出る
- [ ] サーバーから送った `trial_converted_to_paid` が GA4 Realtime に出る
- [ ] BigQuery `analytics_NNNN.events_*` テーブルにデータが流入
- [ ] Looker Studio で `kpi_trial_conversion_rate` チャートに値が出る

## 2. エンドツーエンド: 7 日間トライアルフル走行

`.storekit` の Time Rate を `1s = 1d` 加速で 1 周回す:

1. シミュレータ起動 → 新規ユーザーで Apple Sign In（Sandbox アカウント）
2. オンボーディング完了 → 初ジャーナル投稿 → 通知 opt-in → Paywall
3. 「7日間無料で始める」タップ
4. **Day 0**:
   - Firestore `users/{uid}/subscription.status == "trial"`
   - GA4 で `trial_started`
   - 4 件のローカル通知（trial.day1〜7）がスケジュール
5. **Day 1**（1秒待機）: 通知発火「今日の振り返りを 3 分で」
6. **Day 3**: Goal 別の Day3 通知発火
7. **Day 6**: 「明日トライアル終了」通知、解約導線含む
8. **Day 7**: 課金 2h 前通知
9. **Day 7 終了**: 自動課金成功 → Apple ASSN V2 `DID_RENEW` → Cloud Run 受信
10. **Firestore**: `subscription.status == "active"`
11. **GA4**: `trial_converted_to_paid` イベント
12. **Looker Studio** で当該 cohort の conversion_rate が +1 件分上昇

## 3. ネガティブパス

### 解約パス
1. Trial 中に **Manage Transactions → auto-renew オフ**
2. ASSN V2 `DID_CHANGE_RENEWAL_STATUS` を Cloud Run が受信
3. Firestore `subscription.autoRenewStatus == false`
4. 解約検知 silent push → iOS が `cancelAllTrialNotifications` を呼ぶ
5. 予約されていた Day3/6/7 通知が消える
6. Day 7 で `EXPIRED` 通知 → Firestore `status == "expired"`、GA4 `trial_expired_without_conversion`

### Refund パス
1. Active sub に対し Manage Transactions → **Refund**
2. ASSN V2 `REFUND` を受信
3. Firestore `status == "revoked"`、GA4 `subscription_refunded`
4. iOS `SubscriptionStore.state` が `.expired` になる

### Receipt 改ざんパス
1. 改ざんした `jwsRepresentation` を `POST /iap/apple/verify` に送る
2. 400 invalid signature が返る
3. ユーザーには「購入の検証に失敗しました」エラー表示

## 4. App Store 提出前最終確認

- [ ] `.storekit` を Scheme から **None** に変更
- [ ] iOS bundle ID と App Store Connect の Bundle ID 一致
- [ ] App Store Connect で商品が "Ready to Submit"
- [ ] Paywall Review Screenshot を撮影 → App Store Connect にアップロード
- [ ] Privacy Policy URL / Custom EULA URL 設定
- [ ] App Privacy で収集データ宣言完了
- [ ] TestFlight で内部テスターが Sandbox 課金を実行
- [ ] Review Notes に「Sandbox テスト用アカウント不要、Apple のテスター用に通常購入フローをそのまま提供」と記載

## 5. 本番デプロイ後監視

最初の 7-14 日間は毎日確認:

- [ ] Cloud Run エラーレート < 1%
- [ ] ASSN V2 通知のリトライ率（同じ notificationUUID で 2 回以上届く割合）< 5%
- [ ] Vertex AI クォータ使用率 < 80%
- [ ] Firestore 読み書き量が想定範囲内
- [ ] GA4 Realtime にイベントが定常的に流入
- [ ] Crashlytics の Crash-free users > 99%
- [ ] App Store Connect のサブスク tab で課金が発生していることを確認

## トラブルが起きたら

1. Cloud Run ログ → `gcloud logging read ... severity=ERROR`
2. Firebase Console → Crashlytics
3. App Store Connect → Sales and Trends（Sandbox は別タブ）
4. GA4 → DebugView → 該当ユーザーの行動を追跡
5. Firestore → `users/{uid}/subscription` と `iap_notifications/{uuid}` を直接確認
