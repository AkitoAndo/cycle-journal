# cycle-journal-ops

App Store Connect / Firebase / GA4 などの Web 管理画面操作を Playwright で自動化するためのスクリプト群。Claude が「クリックを伴う運用作業」まで担保できるようにする。

## 想定読者

- 課金リリース・KPI 計測まわりで Web コンソール作業が残っているとき
- Claude（または自分）が再現可能な手順で ASC / Firebase / GA4 を操作したいとき

## セットアップ（初回のみ）

```sh
cd scripts/ops
npm install
npx playwright install chromium

cp .env.example .env
# .env を編集して ASC_APPLE_ID / ASC_APP_ID などを入れる
```

## ログイン（最初の1回 + 期限切れ時）

```sh
npm run asc:login
```

ブラウザが立ち上がるので、画面で Apple ID / パスワード / 2FA を入力。Apps 一覧が表示された状態で、ターミナルで Enter を押すと `.auth/asc.json` に Cookie + localStorage が保存される。

```sh
# 期限切れ確認 (失敗したら再 login)
npm run asc:status
```

## 課金まわりの作業

### 月額に 3日 Introductory Offer を設定（#54 方針反映）

```sh
npm run asc:set-intro-offer
```

### 年額をフェーズ1中は Removed from Sale

```sh
npm run asc:remove-from-sale
```

## 設計メモ

- 認証 state は `.auth/` にローカル保存（`.gitignore` 済み）
- ASC の DOM はラベル依存。UI 変更で壊れたらスクリーンショットを取り直してセレクタを更新
- 公式 API がある操作（ASSN URL 登録など）は将来 App Store Connect API（`.p8` 鍵）に置き換える方が安定
- 完全に人手必須な操作（Apple ID 2FA / Review 提出ボタン）はスクリプト化しない

## 既知の制約

- Apple ID 2FA の初回承認は人手必須（信頼デバイスのプッシュ通知）
- ASC の locale は英語想定。日本語表示の場合はセレクタを揃える必要あり
- ASC 側の DOM 構造は予告なく変わる。壊れたら issue を立てて修正
