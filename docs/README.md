# Cycle Journal

AIコーチング付きジャーナルアプリ。日記を書き、AIコーチとの対話を通じて内省を深め、小さな行動につなげる。

## コンセプト

Cycleは「大きな一本の樹」をメタファーとしたコーチングアプリ。ユーザーが自分の感情や価値観を言葉にし、理解し、行動につなげていく循環（Cycle）を支援する。最終的にはアプリがなくても自分と向き合える力を育てることが目的。

## 主な機能

| 機能 | 概要 | 状態 |
|------|------|------|
| Journal | 日記の作成・編集・タグ管理・検索 | iOS実装済 |
| Coach | AIコーチとの対話（Cycleモデルベース） | UIのみ、API未接続 |
| Tasks | タスク管理＋ふりかえり（fact/insight/nextAction） | iOS実装済 |
| Auth | Sign in with Apple | UI実装済、サーバー検証未実装 |

## 技術スタック

- **iOS**: Swift / SwiftUI / iOS 15+
- **Backend**: Cloud Run (Python 3.12) / Cloud SQL (PostgreSQL)
- **AI**: Claude (Vertex AI) / LangChain + LangGraph
- **IaC**: Terraform
- **認証**: Sign in with Apple + Cloud Run ミドルウェア

## ドキュメント構成

```
docs/
├── README.md              ← このファイル
├── roadmap.md             # AS-IS / TO-BE
├── architecture/          # 技術設計（＋なぜその選択をしたか）
│   ├── overview.md
│   ├── data-model.md
│   └── api-contract.md
├── product/               # プロダクト設計
│   ├── coach-design.md    # コーチの人格・トーン・ルール
│   ├── cycle-model.md     # Cycleモデルの定義
│   └── prompt-catalog.md  # プロンプト・ナレッジベース一覧
├── guides/                # 開発ガイド
│   ├── getting-started.md
│   └── conventions.md
├── legal/
│   └── privacy-policy.md
├── api/
│   └── openapi.yaml       # API仕様（単一の真実）
└── archive/               # 役目を終えたドキュメント
```
