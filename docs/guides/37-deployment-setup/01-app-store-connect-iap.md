# 01. App Store Connect: サブスクリプション商品設定

## 目的

Treow の課金プラン（月額 ¥1,800 / 年額 ¥14,400 + 7 日無料トライアル）を App Store Connect に登録し、StoreKit 2 経由で購入可能にする。

## 前提条件

- Apple Developer Program に加入済（年 $99）
- App Store Connect の **Admin** または **App Manager** ロール
- 対象アプリ（Bundle ID `com.akitoando.CycleJournal`）が App Store Connect に登録済
- 課金契約（Paid Apps Agreement）に署名済
  - [App Store Connect](https://appstoreconnect.apple.com/) → **Agreements, Tax, and Banking** で "Active" になっていること
  - 銀行口座・税情報入力が完了していないと商品が "Waiting for Agreement" になり Sandbox でも取得不可

## 手順

### 1. Subscription Group の作成

1. [App Store Connect](https://appstoreconnect.apple.com/) → 対象アプリ → **Monetization** → **Subscriptions**
2. **Create Subscription Group** をクリック
3. **Reference Name**: `Treow Premium`（内部識別用、ユーザーには見えない）
4. **Save**

> 同じ Group 内のサブスクは「アップグレード／ダウングレード」の関係になる。月額・年額は同一 Group に入れる。

### 2. 月額プランの作成

1. Subscription Group `Treow Premium` を開く
2. **Create Subscription** をクリック
3. 入力項目:
   - **Reference Name**: `Monthly Premium`
   - **Product ID**: **`com.akitoando.CycleJournal.monthly_1800`**
     - ⚠️ 必ずこの ID。`ios/Cycle/Features/Subscription/Models/SubscriptionProduct.swift` の `SubscriptionProductID.monthly` と完全一致
   - **Subscription Duration**: `1 Month`
4. **Create**
5. 次画面の Subscription Pricing で **Add Subscription Price**
   - **Country/Region**: 日本 → **¥1,800**
   - 他国は Apple の自動換算テンプレートで OK（米国基準: $14.99 相当の Tier を選択）
6. **Subscription Information**（Localizations）で日本語版を入力
   - **Subscription Display Name**: `月額プレミアム`
   - **Description**: `すべての Premium 機能を月額でご利用いただけます。`
7. **App Review Information**:
   - **Review Screenshot**: Paywall のスクリーンショット（後述、Sandbox テスト後に撮影）
   - **Review Notes**: `テスト用 Sandbox アカウントは TestFlight で配布済`
8. **Save**

### 3. 年額プランの作成（7 日無料トライアル付き）

1. Subscription Group `Treow Premium` で再度 **Create Subscription**
2. 入力項目:
   - **Reference Name**: `Yearly Premium`
   - **Product ID**: **`com.akitoando.CycleJournal.yearly_14400`**
   - **Subscription Duration**: `1 Year`
3. **Subscription Pricing**:
   - 日本 → **¥14,400**
4. **Subscription Information**:
   - **Display Name**: `年額プレミアム`
   - **Description**: `すべての Premium 機能を年額でご利用いただけます。最初の 7 日間は無料。`
5. **Introductory Offers** セクションへスクロール → **Set Up Introductory Offer**
6. 入力項目:
   - **Countries or Regions**: All Countries（or 提供国のみ）
   - **Offer Type**: **Free Trial**
   - **Duration**: **1 Week** （= 7 日）
   - **Start Date**: 即時 / **End Date**: 無期限 or 一定期間
   - **Eligibility**: `New Subscribers`（新規購読者のみ）
7. **Save**
8. App Review Information / Review Screenshot を月額と同様に設定

### 4. Sandbox テスター作成

1. App Store Connect → **Users and Access** → **Sandbox Testers** タブ
2. **+** → 新規アカウント作成
   - メールアドレス（実在しないものでよい、`test+sandbox@example.com` 等）
   - パスワード（強度高）
   - 国/地域: **Japan**
3. **Invite**
4. iOS 実機 / シミュレータの **Settings → Apple Account → Sandbox Account** にこのアカウントでサインイン
5. アプリ側で課金ダイアログが出たときにこのアカウントで承認

## 検証

### Sandbox での購入フロー
1. Xcode で実機ビルド & 起動
2. Paywall に到達するまで操作
3. 「7 日間無料で始める」タップ
4. Sandbox アカウントのパスワード入力ダイアログ → 承認
5. `SubscriptionStore.state` が `.trial(productID: "com.akitoando.CycleJournal.yearly_14400", expiresAt: ...)` になる
6. `Settings → Apple Account → Subscriptions` に "Treow" が表示される

### App Store Connect 側の状態
- 商品が `Ready to Submit` になっていればアプリの審査提出に同梱可能
- `Missing Metadata` の場合は Localizations / Pricing / Review Screenshot の不足を解消

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `Product.products(for:)` が空配列を返す | 商品が "Waiting for Review" or "Waiting for Agreement" | Agreements, Tax, and Banking を完了させる。商品を Submit |
| `userCancelled` ばかり返る | Sandbox アカウントが地域不一致 | Sandbox アカウントを Japan で作り直す |
| Trial が `nil` | `isEligibleForIntroOffer` が false（過去にトライアル経験あり） | 別の Sandbox アカウントを作って再テスト |
| `purchase()` が `unverified` を返す | `.storekit` Configuration が Production 設定 | [05](05-storekit-config-xcode.md) を見直す |

## 公式ドキュメント

- [Setting up Auto-Renewable Subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/create-auto-renewable-subscriptions/)
- [Set up introductory offers for auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/)
- [Creating Sandbox Apple Accounts](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/create-sandbox-apple-accounts/)

## 次のステップ

→ [02. IAP Key (.p8) と Secret Manager](02-iap-key-secret-manager.md)
