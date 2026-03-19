# C-06: LangGraphフロー（感情分析・質問生成）

| 項目 | 内容 |
|------|------|
| ステータス | :white_check_mark: Done |
| 優先度 | P0 |
| 依存 | C-05（Backend API接続） |

## ユーザーストーリー

> ユーザーとして、コーチが自分の感情を理解し、適切な問いかけをしてほしい。

## 受け入れ条件

- [x] ユーザーの入力から感情が検出される
- [x] 検出された感情に応じて質問が生成される
- [x] Cycleモデルの要素（根/枝/葉など）が会話に反映される
- [x] 安全フィルターノードが応答の安全性を検証する

## 実装内容

### LangGraphフロー（4ノード）

`api/app/services/coach_graph.py` に実装:

```
User Input
    │
    ▼
┌──────────────────┐
│ analyze_emotion  │  ← ユーザーメッセージから感情を1単語で検出
└──────┬───────────┘    （喜び、不安、怒り、悲しみ、迷い、期待、疲れ、安心）
       │
       ▼
┌──────────────────┐
│ determine_cycle  │  ← Cycle要素（8種）のどれに該当するか判定
└──────┬───────────┘    （Soil, Water, Root, Trunk, Branch, Leaf, Fruit, Sky）
       │
       ▼
┌──────────────────┐
│ generate_response│  ← 分析結果を含む拡張プロンプトで応答生成
└──────┬───────────┘    （SYSTEM_PROMPT + 感情 + Cycle要素）
       │
       ▼
┌──────────────────┐
│ safety_filter    │  ← 応答の安全性チェック（unsafe時はフォールバック）
└──────┬───────────┘
       │
       ▼
  Coach Response
```

### 状態管理

`CoachState` dataclass で以下を保持:
- `user_message`, `diary_content`, `history`（入力）
- `detected_emotion`, `cycle_element`（分析結果）
- `response`, `is_safe`（出力）

### フラグ切り替え

- 環境変数 `USE_LANGGRAPH=true/false` で有効化（`config.py` の `use_langgraph`）
- `false`（デフォルト）: 従来のシンプルな `coach_service.chat()` を使用
- `true`: LangGraphフローを使用（Claude呼び出し4回/リクエスト）
- Terraform の `var.use_langgraph` で Cloud Run 環境変数を管理

### 依存関係

- `langgraph>=0.2.0`, `langchain-core>=0.3.0` を `pyproject.toml` に追加

### 検討事項（残タスク）

- レイテンシ最適化（4回のClaude呼び出しを並列化 or 統合）
- 条件分岐の追加（感情の種類に応じてフローを変える）
- 感情検出の精度評価
