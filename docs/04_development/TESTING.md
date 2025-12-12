# テスト方針

## 概要

CycleJournalプロジェクトのテスト戦略を定義。

---

## API (Python/Lambda)

### ユニットテスト

| 項目 | 選定 |
|------|------|
| フレームワーク | pytest |
| AWSモック | moto |
| カバレッジ目標 | 80%以上 |
| カバレッジツール | pytest-cov |

### テスト構成

```
api/
└── tests/
    ├── unit/               # ユニットテスト
    │   ├── test_handlers/  # Lambda関数テスト
    │   ├── test_graph/     # LangGraphテスト
    │   └── test_models/    # モデルテスト
    ├── integration/        # 結合テスト
    │   └── test_api.py     # E2Eテスト
    ├── conftest.py         # 共通フィクスチャ
    └── fixtures/           # テストデータ
```

### LLMテスト戦略

| レイヤー | 方式 |
|----------|------|
| ユニットテスト | モックレスポンス使用 |
| E2Eテスト | 実Bedrock API呼び出し |

#### モックレスポンス例

```python
# tests/fixtures/llm_responses.py
COACH_RESPONSE_MOCK = {
    "content": "今日の振り返りについて...",
    "usage": {"input_tokens": 100, "output_tokens": 50}
}
```

#### ユニットテスト例

```python
# tests/unit/test_handlers/test_coach.py
import pytest
from unittest.mock import patch
from handlers.coach import handler

@patch("handlers.coach.bedrock_client")
def test_coach_handler(mock_bedrock):
    mock_bedrock.invoke.return_value = COACH_RESPONSE_MOCK

    event = {"body": '{"message": "今日は疲れた"}'}
    result = handler(event, None)

    assert result["statusCode"] == 200
```

### CI設定 (GitHub Actions)

```yaml
# .github/workflows/api-test.yml
name: API Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
      - run: uv sync
      - run: uv run pytest --cov=src --cov-report=xml
      - uses: codecov/codecov-action@v4
```

---

## Mobile (iOS/Swift)

### ユニットテスト

| 項目 | 選定 |
|------|------|
| フレームワーク | XCTest |
| APIモック | URLProtocol |
| カバレッジ目標 | 80%以上 |

### UIテスト

| 項目 | 選定 |
|------|------|
| フレームワーク | XCUITest |

### テスト構成

```
mobile/
├── CycleJournalTests/          # ユニットテスト
│   ├── ViewModels/
│   ├── Services/
│   ├── Mocks/
│   │   └── MockURLProtocol.swift
│   └── Fixtures/
└── CycleJournalUITests/        # UIテスト
    ├── DiaryFlowTests.swift
    └── CoachFlowTests.swift
```

### APIモック実装

```swift
// CycleJournalTests/Mocks/MockURLProtocol.swift
class MockURLProtocol: URLProtocol {
    static var mockResponses: [URL: (Data, HTTPURLResponse)] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override func startLoading() {
        guard let url = request.url,
              let (data, response) = Self.mockResponses[url] else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
```

### テスト例

```swift
// CycleJournalTests/Services/CoachServiceTests.swift
import XCTest
@testable import CycleJournal

final class CoachServiceTests: XCTestCase {
    var sut: CoachService!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        sut = CoachService(session: URLSession(configuration: config))
    }

    func testSendMessage_Success() async throws {
        // Given
        let mockResponse = CoachResponse(message: "...")
        MockURLProtocol.mockResponses[coachURL] = (
            try JSONEncoder().encode(mockResponse),
            HTTPURLResponse(url: coachURL, statusCode: 200, ...)
        )

        // When
        let result = try await sut.sendMessage("今日は疲れた")

        // Then
        XCTAssertEqual(result.message, "...")
    }
}
```

### CI設定 (GitHub Actions)

```yaml
# .github/workflows/ios-test.yml
name: iOS Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - run: |
          xcodebuild test \
            -project mobile/CycleJournal.xcodeproj \
            -scheme CycleJournal \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -enableCodeCoverage YES
```

---

## テストピラミッド

```
        /\
       /  \     E2E (実API)
      /----\
     /      \   結合テスト
    /--------\
   /          \ ユニットテスト (モック)
  --------------
```

| レイヤー | 比率 | 速度 | コスト |
|----------|------|------|--------|
| ユニット | 70% | 高速 | 低 |
| 結合 | 20% | 中速 | 中 |
| E2E | 10% | 低速 | 高 |
