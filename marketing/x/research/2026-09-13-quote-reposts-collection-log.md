# 引用リポスト100件の収集記録

- 観測日: 2026-09-13
- 候補: 112件
- 重複除外後: 104件
- 分析対象: 100件
- 分析対象の最小いいね数: 110件
- 引用日の範囲: 2025-09-21から2026-09-12まで

## 分析対象の内訳

| 収集区分 | 件数 |
|---|---:|
| 先に詳しく確認した基準事例 | 12 |
| ジャーナリング、日記 | 24 |
| 手帳、ノート | 22 |
| 勉強記録、読書記録 | 20 |
| 作り手、利用者、続報 | 22 |
| 合計 | 100 |

区分をまたぐ投稿があり、候補112件のうち8件が重複していた。
ステータスIDで重複を除いた。

## 使用した主な検索条件

### ジャーナリング、日記

```text
ジャーナリング filter:quote min_faves:100 since:2025-09-13 until:2026-09-14
日記 filter:quote min_faves:100 since:2025-09-13 until:2026-09-14
```

### 手帳、ノート

```text
手帳 filter:quote min_faves:100
手帳術 filter:quote min_faves:50
バレットジャーナル filter:quote min_faves:20
ほぼ日手帳 filter:quote min_faves:50
ロルバーン filter:quote min_faves:50
システム手帳 filter:quote min_faves:50
```

### 勉強記録、読書記録

```text
(日記 OR 手帳 OR 読書 OR 勉強 OR 学習 OR ログ) filter:quote min_faves:100 since:2025-09-13 until:2026-09-14
"勉強手帳" filter:quote min_faves:100 since:2025-09-13 until:2026-09-14
("勉強記録" OR "学習記録" OR "学習ログ") filter:quote min_faves:100 since:2025-09-13 until:2026-09-14
("読書記録" OR "読書ノート" OR "読了") filter:quote min_faves:100 since:2025-09-13 until:2026-09-14
(日記 OR ジャーナリング) filter:quote min_faves:100 since:2025-09-13 until:2026-09-14
```

### 作り手、利用者、続報

```text
手帳 filter:quote min_faves:100 since:2025-09-13
from:kanayama_yuko filter:quote min_faves:100 since:2025-09-13
from:mogu_pisu filter:quote min_faves:100 since:2025-09-13
from:iyupi__20 filter:quote min_faves:100 since:2025-09-13
from:kmxmmc filter:quote min_faves:100 since:2025-09-13
from:pnly_tar filter:quote min_faves:100 since:2025-09-13
from:isshukan_1 filter:quote min_faves:100 since:2025-09-13
(手帳 OR ノート OR 日記) 作りました filter:quote min_faves:100 since:2025-09-13
(日記 OR 手帳 OR ノート OR 記録) (使ってくれて OR 使っていただき) filter:quote min_faves:100 since:2025-09-13
```

## 検証結果

- JSON Linesの解析: 成功
- 必須項目の欠落: 0件
- ステータスIDによる重複除外: 実施済み
- 反応数の型: 0以上の整数または未取得
- 5段階評価: 1から5まで
- Hinakaへの適合: `adopt`、`adapt`、`reject`へ統一
- 反応の主な役割: 10種類へ統一
- 文量: 引用側の全文を基準に3種類へ統一
- 元投稿の形式: 8種類へ統一
- 元投稿との関係: 6種類へ統一
- 短い抜粋: 80文字以内

検証と集計には、[データセット生成スクリプト](./scripts/build-quote-repost-dataset.mjs)を使用した。

## 再生成

リポジトリのルートで、次を実行する。

```bash
node marketing/x/research/scripts/build-quote-repost-dataset.mjs
```

次の3ファイルが生成される。

- `data/2026-09-13-quote-reposts-100.jsonl`
- `data/2026-09-13-quote-reposts-100.csv`
- `data/2026-09-13-quote-reposts-analysis.json`

候補が100件未満の場合や、分類値に誤りがある場合は失敗する。
