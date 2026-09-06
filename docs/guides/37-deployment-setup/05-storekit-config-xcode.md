# 05. .storekit Configuration ファイル作成（Xcode）

## 目的

シミュレータ / 実機デバッグ時に App Store Connect / Sandbox を経由せずに購入フローをテストできるようにする。Xcode の **StoreKit Configuration** ファイル（`.storekit`）で商品定義をローカルにモック化する。

> 本番リリース時は Scheme から `.storekit` を外す（または "None" にする）こと。残したまま提出すると審査でリジェクトされる可能性は低いが、Sandbox / Production の挙動とは異なるため動作確認は別途必要。

## 前提条件

- Xcode 16+
- 本プロジェクト（`ios/Cycle.xcodeproj`）が開ける状態

## 手順

### 1. StoreKit Configuration ファイル作成

1. Xcode で `Cycle.xcodeproj` を開く
2. **File → New → File from Template**
3. iOS タブ → **StoreKit Configuration File** を選択 → **Next**
4. Save As: `Configuration.storekit`
5. Group: `Cycle` ターゲット直下（`ios/Cycle/` 配下）に保存
6. **Create**

### 2. 商品の追加

`.storekit` ファイルを開くと空のリストが表示される。

#### 月額プラン
1. **+** → **Add Auto-Renewable Subscription**
2. **Reference Name**: `Monthly Premium`
3. **Product ID**: `com.akitoando.CycleJournal.monthly_1800`
4. **Subscription Group**: `Treow Premium` を新規作成して選択
5. **Subscription Duration**: 1 month
6. **Price**: ¥1,800 → 1800.00 / JPY
7. **Family Sharing**: Off（必要なら On）

#### 年額プラン
1. **+** → **Add Auto-Renewable Subscription**
2. **Reference Name**: `Yearly Premium`
3. **Product ID**: `com.akitoando.CycleJournal.yearly_14400`
4. **Subscription Group**: 上で作った `Treow Premium` を選択
5. **Subscription Duration**: 1 year
6. **Price**: ¥14,400 → 14400.00 / JPY

#### 年額プランに Introductory Offer を追加
1. 年額プランを選択した状態で **Subscription Group / Introductory Offer** タブ
2. **+ Add Introductory Offer**
3. **Offer Type**: `Free Trial`
4. **Duration**: 1 Week
5. **Pricing**: 0
6. **Mode**: `Pay As You Go` / `Pay Up Front` ではなく **`Free Trial`** が選ばれていることを確認

### 3. Scheme への紐付け

1. Xcode 上部の **Cycle スキーム** → **Edit Scheme...**
2. **Run** → **Options** タブ
3. **StoreKit Configuration**: ドロップダウンで `Configuration.storekit` を選択
4. **Close**

### 4. テスト実行

シミュレータで実行（Cmd+R）し、Paywall に到達:

- `Product.products(for: [...])` がローカル定義から商品 2 つを返す
- 「7日間無料で始める」を押すと **Sandbox アカウント不要**で即購入が走る（パスワードダイアログ出ず）
- `SubscriptionStore.state` が `.trial(...)` になる

### 5. デバッグ操作（時間操作・取消し）

シミュレータ起動中、Xcode **Debug → StoreKit → Manage Transactions**

- 任意のトランザクションを選択 → **Refund** で払戻しをシミュレート
- **Resolve Issues** で課金エラーをシミュレート
- Subscription Group の **Time Rate** で時間進行速度を倍速にできる（1 second = 1 day など → 7日トライアル終了を数秒で確認可能）

## 検証

### 動作確認チェックリスト

- [ ] `Product.products(for:)` がエラーなく 2 商品を返す
- [ ] 「7日間無料で始める」タップ → ダイアログなし or 簡易確認のみで `state == .trial(...)` になる
- [ ] **Manage Transactions** で `Refund` → `Transaction.updates` に通知が来て `state == .expired` になる
- [ ] **Time Rate** を 1s = 1d にして 7 秒待つ → トライアル終了し自動課金 → `state == .active(...)`
- [ ] Day3 通知（C-2）の `scheduledAt` がローカルで実際に発火するか（`Time Rate` 倍速だと通知も加速）

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `Product.products(for:)` が空配列 | Scheme で `.storekit` 未選択 | Edit Scheme → Run → Options → StoreKit Configuration |
| Introductory Offer がアクティブにならない | Subscription Group が違う | 月額・年額・Intro Offer が同一 Group に属しているか |
| 購入後 `state == .unknown` のまま | `refreshEntitlements` 呼び忘れ | `Transaction.updates` リスナーが起動しているか確認、または手動で `await store.refreshEntitlements()` |
| Time Rate を変えても何も起きない | シミュレータを完全に再起動 | `xcrun simctl shutdown all` → 再起動 |

## 本番リリース前のチェック

- [ ] Scheme から `.storekit` を **外す** または **None** にする
- [ ] Configuration.storekit はリポジトリに含めて良い（個人情報なし）
- [ ] Sandbox アカウントで実機テストを完了
- [ ] App Store Connect の本番商品で動作することを TestFlight ビルドで確認

## 公式ドキュメント

- [Setting up StoreKit testing in Xcode](https://developer.apple.com/documentation/Xcode/setting-up-storekit-testing-in-xcode)
- [Creating a StoreKit configuration file](https://developer.apple.com/documentation/Xcode/setting-up-storekit-testing-in-xcode#Create-a-StoreKit-configuration-file)
- [Testing in-app purchases with sandbox](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox)

## 次のステップ

→ [06. Firebase Project / iOS SDK 統合](06-firebase-analytics.md)
