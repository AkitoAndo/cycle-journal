# 開発ガイド

## 前提条件

| ツール | バージョン | 用途 |
|--------|-----------|------|
| Python | 3.12 | バックエンド開発 |
| uv | latest | Python パッケージ管理 |
| Node.js | 22+ | ドキュメント（VitePress） |
| AWS CDK | 2.100+ | インフラデプロイ |
| AWS CLI | 2.x | AWS 操作 |
| Xcode | latest | iOS アプリ開発 |

## プロジェクト構成

```
cycle-journal/
├── api/                # バックエンド
│   ├── src/handlers/   # Lambda ハンドラー
│   ├── src/layers/     # Lambda レイヤー
│   ├── cdk/            # CDK インフラ
│   ├── tests/          # テスト
│   └── pyproject.toml  # Python 設定
├── mobile/             # iOS アプリ（SwiftUI）
│   └── CycleJournal/
├── docs/               # ドキュメント（VitePress）
└── scripts/            # ユーティリティ
```

## バックエンド開発

### セットアップ

```bash
cd api

# 依存パッケージのインストール
uv sync

# 開発用依存を含む
uv sync --extra dev
```

### コード規約

#### Python（Ruff）

```bash
# リント
uv run ruff check .

# フォーマット
uv run ruff format .

# 型チェック
uv run mypy .
```

**主な Ruff ルール:**
- E, W: PEP 8 スタイル
- F: Pyflakes
- I: isort（import 順序）
- UP: pyupgrade

#### 命名規則

| 対象 | 規則 | 例 |
|------|------|-----|
| ファイル名 | snake_case | `coach.py` |
| 関数 | snake_case | `verify_apple_token()` |
| クラス | PascalCase | `CycleJournalApiStack` |
| 定数 | UPPER_SNAKE_CASE | `SYSTEM_PROMPT` |
| 環境変数 | UPPER_SNAKE_CASE | `BEDROCK_MODEL_ID` |

### Lambda ハンドラーの構造

```python
import json
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "OPTIONS,POST,GET",
}

def handler(event, context):
    try:
        # ビジネスロジック
        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps({"data": result}),
        }
    except Exception as e:
        logger.error(f"Error: {e}")
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": {"code": "InternalError", "message": str(e)}}),
        }
```

### テスト

```bash
# テスト実行
uv run pytest

# カバレッジ付き
uv run pytest --cov=src --cov-report=term-missing
```

### デプロイ

```bash
cd api/cdk

# 差分確認
cdk diff --context stage=dev

# デプロイ
cdk deploy --context stage=dev
```

## iOS 開発

### セットアップ

1. Xcode で `mobile/CycleJournal.xcodeproj` を開く
2. 開発チーム・Bundle ID を設定
3. 実機またはシミュレーターでビルド・実行

### アーキテクチャ

MVVM パターンを採用しています。

```
View (SwiftUI)
  ↓ @EnvironmentObject
Store (ObservableObject + @Published)
  ↓
Service (API Client / Local Storage)
```

### ディレクトリ構成

| ディレクトリ | 役割 |
|------------|------|
| `Views/` | SwiftUI ビュー |
| `Models/` | データモデル |
| `Services/` | API 通信・外部サービス |
| `Stores/` | 状態管理（ViewModel 相当） |

## ドキュメント開発

```bash
cd docs

# 依存インストール
npm install

# 開発サーバー起動
npm run dev

# ビルド
npm run build

# プレビュー
npm run preview
```

## Git 運用

### ブランチ戦略

| ブランチ | 用途 |
|---------|------|
| `main` | 本番リリース |
| `develop` | 開発統合 |
| `feature/*` | 機能開発 |
| `fix/*` | バグ修正 |

### コミットメッセージ規約

```
<type>: <description>

<body (optional)>
```

| Type | 用途 |
|------|------|
| feat | 新機能 |
| fix | バグ修正 |
| docs | ドキュメント |
| refactor | リファクタリング |
| test | テスト |
| chore | その他 |
