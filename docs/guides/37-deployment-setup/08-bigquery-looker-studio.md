# 08. BigQuery export と Looker Studio ダッシュボード

## 目的

Firebase Analytics（GA4）で収集したイベントを BigQuery に自動エクスポートし、Looker Studio で「Trial→Paid 転換率」「3ヶ月継続率」「アクティベーション率」を可視化する。

GA4 内蔵レポートでは粒度が浅いため、ASSN V2 から FastAPI が書き込む Firestore の `users/{uid}/subscription` テーブルと **SQL で JOIN** できる BigQuery export を中核に据える。

## 前提条件

- [06](06-firebase-analytics.md) / [07](07-ga4-measurement-protocol.md) 完了
- GCP 課金アカウントが Firebase プロジェクトに紐付け済（Blaze プラン）
  - BQ export 自体は無料だが Firebase が Blaze 必須

## 手順

### 1. BigQuery export 有効化

1. [Firebase Console](https://console.firebase.google.com/) → プロジェクト → **Project Settings**（歯車）
2. **Integrations** タブ
3. **BigQuery** → **Link**
4. **iOS app** を選択
5. **Configure integration**:
   - **Daily** ✅ チェック（毎日 1 回まとめてエクスポート）
   - **Streaming** ✅ チェック（リアルタイム、追加コストあり、デバッグ時のみで OK）
   - **Include advertising identifiers**: OFF（ATT 不要設定維持）
6. **Link to BigQuery**

24 時間以内に BQ にデータセットが作成される:
- データセット名: `analytics_<property_id>`
- テーブル名: `events_YYYYMMDD`（日次）、`events_intraday_YYYYMMDD`（streaming 時）

### 2. Firestore → BigQuery export 設定

サブスクリプション状態（`users/{uid}/subscription`）を BQ に取り込む。

**Option A**: Firebase Extensions の `Stream Firestore to BigQuery`
1. Firebase Console → **Extensions** → **Stream Firestore to BigQuery**
2. Install:
   - **Source Collection Path**: `users/{userId}/subscription`
   - **Dataset ID**: `firestore_export`
   - **Table ID**: `subscriptions`
   - **Backfill existing documents**: Yes
3. Install Extension

**Option B**: Cloud Functions で手動同期（既存運用がある場合）

### 3. SQL ビュー作成

BigQuery Console で以下のビューを作成。`PROJECT_ID` `analytics_NNNN` `firestore_export` は実値で置換:

#### a) Trial Started ユーザー
```sql
CREATE OR REPLACE VIEW `cycle-journal.analytics.trial_started_users` AS
SELECT
  user_pseudo_id,
  TIMESTAMP_MICROS(event_timestamp) AS started_at,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'product_id') AS product_id,
  DATE(TIMESTAMP_MICROS(event_timestamp)) AS started_date,
FROM `cycle-journal.analytics_NNNN.events_*`
WHERE event_name = 'trial_started';
```

#### b) Trial → Paid 転換
```sql
CREATE OR REPLACE VIEW `cycle-journal.analytics.trial_conversion` AS
WITH started AS (
  SELECT user_pseudo_id, started_at, product_id
  FROM `cycle-journal.analytics.trial_started_users`
),
converted AS (
  SELECT
    user_pseudo_id,
    TIMESTAMP_MICROS(event_timestamp) AS converted_at,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'product_id') AS product_id,
  FROM `cycle-journal.analytics_NNNN.events_*`
  WHERE event_name = 'trial_converted_to_paid'
)
SELECT
  s.user_pseudo_id,
  s.product_id,
  s.started_at,
  c.converted_at,
  c.converted_at IS NOT NULL AS converted,
  TIMESTAMP_DIFF(c.converted_at, s.started_at, HOUR) AS hours_to_convert
FROM started s
LEFT JOIN converted c USING (user_pseudo_id);
```

#### c) Trial→Paid 転換率（KPI: 25%）
```sql
CREATE OR REPLACE VIEW `cycle-journal.analytics.kpi_trial_conversion_rate` AS
SELECT
  DATE_TRUNC(DATE(started_at), WEEK(MONDAY)) AS cohort_week,
  COUNT(*) AS trials,
  COUNTIF(converted) AS conversions,
  SAFE_DIVIDE(COUNTIF(converted), COUNT(*)) AS conversion_rate
FROM `cycle-journal.analytics.trial_conversion`
GROUP BY cohort_week
ORDER BY cohort_week;
```

#### d) 3 ヶ月継続率（KPI: 60%）
```sql
CREATE OR REPLACE VIEW `cycle-journal.analytics.kpi_three_month_retention` AS
WITH converted AS (
  SELECT
    user_pseudo_id,
    converted_at,
  FROM `cycle-journal.analytics.trial_conversion`
  WHERE converted
    AND converted_at < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
),
still_active AS (
  SELECT
    document_id AS user_id,
    data.status AS status,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),
      TIMESTAMP(data.purchasedAt), DAY) AS days_since_purchase,
  FROM `cycle-journal.firestore_export.subscriptions`
  WHERE data.status = 'active'
)
SELECT
  DATE_TRUNC(DATE(c.converted_at), WEEK(MONDAY)) AS cohort_week,
  COUNT(*) AS converted_users,
  COUNTIF(s.user_id IS NOT NULL) AS still_active_users,
  SAFE_DIVIDE(COUNTIF(s.user_id IS NOT NULL), COUNT(*)) AS retention_rate
FROM converted c
LEFT JOIN still_active s ON c.user_pseudo_id = s.user_id
GROUP BY cohort_week
ORDER BY cohort_week;
```

#### e) アクティベーション率（first journal / signup）
```sql
CREATE OR REPLACE VIEW `cycle-journal.analytics.kpi_activation_rate` AS
WITH signups AS (
  SELECT
    user_pseudo_id,
    MIN(TIMESTAMP_MICROS(event_timestamp)) AS signup_at,
  FROM `cycle-journal.analytics_NNNN.events_*`
  WHERE event_name = 'signup_succeeded'
  GROUP BY user_pseudo_id
),
first_journals AS (
  SELECT
    user_pseudo_id,
    MIN(TIMESTAMP_MICROS(event_timestamp)) AS first_journal_at,
  FROM `cycle-journal.analytics_NNNN.events_*`
  WHERE event_name = 'journal_first_entry_created'
  GROUP BY user_pseudo_id
)
SELECT
  DATE_TRUNC(DATE(s.signup_at), WEEK(MONDAY)) AS cohort_week,
  COUNT(*) AS signups,
  COUNTIF(f.user_pseudo_id IS NOT NULL) AS activated,
  SAFE_DIVIDE(COUNTIF(f.user_pseudo_id IS NOT NULL), COUNT(*)) AS activation_rate
FROM signups s
LEFT JOIN first_journals f USING (user_pseudo_id)
GROUP BY cohort_week
ORDER BY cohort_week;
```

### 4. Looker Studio ダッシュボード作成

1. [Looker Studio](https://lookerstudio.google.com/) → **Create → Report**
2. **Add data → BigQuery → cycle-journal → analytics → kpi_trial_conversion_rate**
3. グラフ:
   - **Time series chart**: `cohort_week` × `conversion_rate`、目標ライン 25% を Constant に追加
   - **Scorecard**: 直近 4 週平均の `conversion_rate`
4. 同様に他 3 ビューも `Add Data` してチャート化:
   - 3-month retention (target 60%)
   - Activation rate
   - DAU / WAU
5. 共有 → メンバーのメールに **Viewer** 権限で配布

### 5. 自動更新

- Looker Studio はデフォルトで BQ をリアルタイム参照
- データの鮮度は GA4 BQ export の方式に依存:
  - Daily export: 翌日 朝
  - Streaming export: 数分以内

## 検証

### チェックリスト

- [ ] BQ Console で `cycle-journal.analytics_NNNN.events_YYYYMMDD` テーブルが存在
- [ ] `SELECT COUNT(*) FROM ...events_*` が 0 より大きい
- [ ] `firestore_export.subscriptions` テーブルにレコードがある
- [ ] 5 つのビューが SQL エラーなく `SELECT * LIMIT 10` できる
- [ ] Looker Studio に 5 つのチャートが表示
- [ ] 共有メンバーが「権限がありません」エラーなくアクセスできる

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| BQ にデータセットが作られない | Firebase Analytics と GCP プロジェクトが分離 | [06](06-firebase-analytics.md) で既存 GCP プロジェクトに Firebase を紐付け |
| `events_*` テーブルが空 | iOS アプリで Firebase 初期化されていない | `FirebaseApp.configure()` を確認 |
| `firestore_export.subscriptions` が空 | Extension の Backfill 未実行 / write event なし | Extension の "Run backfill" を実行 |
| Looker Studio で BQ コネクタが選べない | 課金アカウント未設定 | Firebase Blaze プランに upgrade |

## 公式ドキュメント

- [Export Firebase data to BigQuery](https://firebase.google.com/docs/projects/bigquery-export)
- [BigQuery Export schema for GA4](https://support.google.com/analytics/answer/7029846?hl=en)
- [Stream Firestore to BigQuery extension](https://extensions.dev/extensions/firebase/firestore-bigquery-export)
- [Looker Studio Help](https://support.google.com/looker-studio)

## 次のステップ

→ [09. Vertex AI Model Garden のモデル ID 検証](09-vertex-ai-models.md)
