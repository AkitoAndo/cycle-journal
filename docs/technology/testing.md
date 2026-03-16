# テスト戦略

## 概要

品質を担保するためのテスト方針を定めます。テストピラミッドに基づき、ユニットテストを重視しつつ、統合テストとE2Eテストで全体の品質を保証します。

## テストピラミッド

```
        ┌───────┐
        │  E2E  │  少数・高コスト
        ├───────┤
        │ 統合  │  中程度
        ├───────┤
        │ ユニット │  多数・低コスト
        └───────┘
```

## バックエンド（Python）

### フレームワーク

| ツール | 用途 |
|--------|------|
| pytest | テストランナー |
| pytest-cov | カバレッジ計測 |
| moto（予定） | AWS サービスモック |

### カバレッジ目標

| レベル | 目標 |
|--------|------|
| 全体 | 80% 以上 |
| ハンドラー | 90% 以上 |
| ビジネスロジック | 95% 以上 |

### テストディレクトリ構成

```
tests/
├── unit/
│   ├── test_handlers/
│   │   ├── test_health.py
│   │   ├── test_auth.py
│   │   ├── test_coach.py
│   │   └── test_authorizer.py
│   ├── test_models/
│   └── test_graph/
├── integration/
│   └── test_api.py
├── conftest.py
└── fixtures/
```

### ユニットテスト

Lambda ハンドラーの入出力をテストします。外部依存（Bedrock, Apple API）はモックします。

```python
# test_health.py の例
def test_health_handler_returns_200():
    event = {}
    context = {}
    response = handler(event, context)
    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["status"] == "healthy"
```

### モック戦略

| 対象 | モック方法 | 説明 |
|------|-----------|------|
| AWS Bedrock | `unittest.mock.patch` | AI レスポンスを固定値で返す |
| Apple 公開鍵 | `unittest.mock.patch` | HTTP リクエストをモック |
| DynamoDB（予定） | moto | ローカルでサービスをエミュレート |

### 統合テスト

デプロイ済みの API エンドポイントに対して実行します。

```bash
# dev 環境に対して実行
STAGE=dev uv run pytest tests/integration/
```

### テスト実行コマンド

```bash
# 全テスト
uv run pytest

# ユニットテストのみ
uv run pytest tests/unit/

# カバレッジ付き
uv run pytest --cov=src --cov-report=html

# 特定テスト
uv run pytest tests/unit/test_handlers/test_health.py -v
```

## iOS（Swift）

### フレームワーク

| ツール | 用途 |
|--------|------|
| XCTest | 標準テストフレームワーク |
| XCUITest | UI テスト |

### テスト対象

| レイヤー | テスト対象 | 優先度 |
|---------|-----------|--------|
| Store | 状態遷移、ビジネスロジック | 高 |
| Service | API 通信、レスポンスパース | 高 |
| Model | エンコード/デコード、バリデーション | 中 |
| View | UI 表示、インタラクション | 低 |

## CI/CD

### GitHub Actions（計画中）

```
Push → Lint/Format Check → Unit Tests → Build → Deploy (dev)
```

| ステップ | ツール | 条件 |
|---------|--------|------|
| Lint | Ruff | 全 PR |
| Type Check | mypy | 全 PR |
| Unit Test | pytest | 全 PR |
| Coverage | pytest-cov | 80% ゲート |
| Deploy (dev) | CDK | main マージ時 |
| Deploy (prod) | CDK | タグ作成時 |

## 現在のステータス

| 項目 | ステータス |
|------|-----------|
| テストディレクトリ構成 | ✅ 定義済み |
| ユニットテスト | ⬜ 未作成 |
| 統合テスト | ⬜ 未作成 |
| CI/CD パイプライン | ⬜ 未構築 |
| iOS テスト | ⬜ 未作成 |
