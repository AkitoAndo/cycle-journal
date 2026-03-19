# B-03: ベースプロンプト実装

| 項目 | 内容 |
|------|------|
| ステータス | :white_check_mark: Done |
| 優先度 | P0 |
| 依存 | C-05（Backend API接続） |
| 参照 | [コーチ設計](/product/coach-design), [Cycleモデル](/product/cycle-model), [プロンプトカタログ](/product/prompt-catalog) |

## ユーザーストーリー

> 開発者として、プロダクト設計で定義されたコーチの人格・トーン・ルールをシステムプロンプトに反映したい。

## 受け入れ条件

- [x] ベースプロンプト（大樹スタイル、7つのルール）が `api/app/services/coach_service.py` に実装
- [x] Cycle要素（土・水・根・幹・枝・葉・実・空）がプロンプトに含まれる
- [x] 口調例・応答の長さ（1〜3文）がプロンプトに含まれる
- [x] 禁止表現ルールがプロンプトに含まれる
- [ ] 会話フェーズ（導入→深掘り→統合→実行→ふりかえり）のテンプレートが利用可能
- [ ] Cycle要素のラベルがレスポンスメタデータに反映

## 実装内容

`api/app/services/coach_service.py` の `SYSTEM_PROMPT` に以下を実装:
- 役割定義（大樹の存在としてのAIコーチ）
- 目的（自分の感情・価値観を言葉にする → 自立へ）
- 7つのルール（答えを与えない、余白を残す、共感先行、ミラーリング等）
- Cycle構成要素（大樹メタファー 8要素）
- 口調例
- 応答の長さ（1〜3文、余白を残す）

Vertex AI Claude (`anthropic[vertex]` SDK) を使用、temperature 0.7、max_tokens 500。
