# 10. Terms / Privacy URL の差し替え

## 目的

PR #45 で実装した `PaywallView.swift` にプレースホルダで入っている利用規約・プライバシーポリシー URL を、公開済の本番 URL に差し替える。**App Store Review でこれらが本物のページに到達しないとリジェクト対象**。

## 前提条件

- 利用規約・プライバシーポリシーが公開済（HTML / Markdown のホスティング）
- 推奨ホスティング:
  - GitHub Pages（`docs/legal/` を public 公開する場合）
  - Notion → Public Page
  - 独自ドメイン CMS
  - App Store Connect の **Privacy Policy URL** フィールドにも同じ URL を入れる

## 手順

### 1. 公開ページの準備

すでに `docs/legal/` 配下にドラフトがある場合はそれを公開化:

```bash
ls docs/legal/
# terms.md, privacy.md, ...
```

GitHub Pages で公開する場合:
1. **Settings → Pages** → **Source**: `main` ブランチ `/docs` フォルダ
2. URL 例: `https://akitoando.github.io/cycle-journal/legal/terms`

独自ドメインなら DNS 設定後 `https://cycle-journal.app/legal/terms` 等。

### 2. PaywallView.swift の差し替え

```swift
// ios/Cycle/Features/Subscription/Views/PaywallView.swift
let termsURL = URL(string: "https://akitoando.github.io/cycle-journal/legal/terms")!
let privacyURL = URL(string: "https://akitoando.github.io/cycle-journal/legal/privacy")!
```

### 3. App Store Connect の Privacy 設定

1. App Store Connect → 対象アプリ → **App Information**
2. **Privacy Policy URL** に同じプライバシー URL を入力
3. **App Privacy** タブで収集データを宣言（Firebase Analytics 利用なら "Product Interaction" / "Crash Data" / "Performance Data" 等を選択）
4. **Save**

### 4. App Store Server Notifications V2 のサブスク利用規約

iOS のサブスク商品には **EULA**（End User License Agreement）が必須。Apple のデフォルト EULA を使う場合は何もしない。独自 EULA を使う場合は `App Information → Custom EULA` に URL 登録。

### 5. 動作確認

- iOS シミュレータで Paywall を表示 → 「利用規約」「プライバシーポリシー」リンクをタップ
- Safari で実 URL が開く
- 404 や白画面でないこと

## 検証

### チェックリスト

- [ ] `PaywallView.swift` の `termsURL` / `privacyURL` が本番 URL
- [ ] 両 URL が 200 OK で実コンテンツを返す
- [ ] App Store Connect の Privacy Policy URL に同じ URL を登録
- [ ] App Privacy で収集データを正確に宣言
- [ ] Paywall からのタップで Safari が立ち上がりページ表示

## 公式ドキュメント

- [App Store Review Guideline 5.1.1 (Data Collection and Storage)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)
- [App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/)
- [Schedule, report, and refund in-app purchases](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-a-subscription/)

## 完了

すべてのセットアップが終わったら → [動作確認チェックリスト](verification-checklist.md)
