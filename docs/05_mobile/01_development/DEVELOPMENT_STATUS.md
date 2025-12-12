# CycleJournal 開発状況

## 概要

CycleJournalプロジェクトの開発状況を整理する。Mobile（iOS）とAPI（バックエンド）の実装状況および今後の開発予定を記載。

---

## 全体アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                         CycleJournal                             │
├──────────────────────────┬──────────────────────────────────────┤
│        Mobile (iOS)       │            API (Backend)             │
│       [部分的に実装済み]    │            [未実装]                  │
├──────────────────────────┼──────────────────────────────────────┤
│ ・SwiftUI                 │ ・AWS Lambda (Python)                │
│ ・ローカルストレージ        │ ・API Gateway                        │
│   (UserDefaults)         │ ・Aurora Serverless (PostgreSQL)     │
│                          │ ・Bedrock (Claude Haiku)             │
│                          │ ・LangChain + LangGraph              │
└──────────────────────────┴──────────────────────────────────────┘
```

---

## Mobile (iOS) - 実装状況

### 実装済み

| カテゴリ | 機能 | ファイル | 状態 |
|---------|------|----------|------|
| **日記機能** | 日記の作成・編集・削除 | `DiaryListView.swift`, `DiaryStore.swift` | ✅ 完了 |
| | タグ管理（CRUD） | `TagManagementView.swift` | ✅ 完了 |
| | キーワード検索 | `DiaryListView.swift` (SearchView) | ✅ 完了 |
| | タグフィルタリング | `DiaryStore.swift` | ✅ 完了 |
| | 週間カレンダー | `WeeklyCalendarView.swift` | ✅ 完了 |
| | 月間カレンダー | `CalendarView.swift` | ✅ 完了 |
| **ナビゲーション** | タブナビゲーション | `MainTabView.swift` | ✅ 完了 |
| **コーチ機能** | コーチホーム画面 | `CoachHomeView.swift` | ✅ 完了 |
| | チャット画面（UI） | `CoachChatView.swift` | ✅ 完了 |
| | 会話履歴一覧 | `CoachHomeView.swift` (SessionHistoryView) | ✅ 完了 |
| | 日記選択画面 | `CoachHomeView.swift` (DiaryPickerView) | ✅ 完了 |
| | セッション管理 | `CoachStore.swift` | ✅ 完了 |
| | **モックAPI応答** | `CoachStore.swift` | ⚠️ モック |
| **タスク機能** | タスク一覧 | `TaskListView.swift` | ✅ 完了 |
| | タスク追加 | `TaskListView.swift` (AddTaskView) | ✅ 完了 |
| | タスク完了・削除 | `TaskStore.swift` | ✅ 完了 |
| | ふりかえり入力（4ステップ） | `TaskReflectionView.swift` | ✅ 完了 |
| **設定機能** | 設定画面（UI） | `SettingsView.swift` | ✅ 完了 |
| **データモデル** | CoachSession, CoachMessage | `Models/CoachSession.swift` | ✅ 完了 |
| | ActionTask, TaskReflection | `Models/ActionTask.swift` | ✅ 完了 |

### 未実装

| カテゴリ | 機能 | 優先度 | 備考 |
|---------|------|--------|------|
| **認証** | Sign in with Apple | P0 | バックエンド連携が必要 |
| **API連携** | コーチAPI呼び出し | P0 | `CoachStore.sendMessage()` の実装 |
| | タスクAPI同期 | P1 | サーバーとのデータ同期 |
| | 日記API同期 | P1 | サーバーとのデータ同期 |
| **オンボーディング** | 初回オンボーディング画面 | P2 | `OnboardingView.swift` |
| **通知** | リマインダー通知 | P2 | UserNotifications |
| | タスク期限通知 | P2 | UserNotifications |
| **データ** | データエクスポート | P3 | JSON形式でのエクスポート |
| | iCloud同期 | P3 | 将来的な機能 |
| **UI改善** | 日記からコーチへの連携強化 | P2 | 日記詳細画面にボタン追加 |
| | エラーハンドリング強化 | P1 | ネットワークエラー等 |

---

## API (Backend) - 実装状況

### 実装済み

| カテゴリ | 機能 | ファイル | 状態 |
|---------|------|----------|------|
| **インフラ** | CDK スタック構築 | `api/cdk/` | ✅ 完了 |
| | API Gateway 設定 | `api/cdk/stacks/api_stack.py` | ✅ 完了 |
| **Lambda関数** | health handler | `api/src/handlers/health.py` | ✅ 完了 |
| | coach handler（モック） | `api/src/handlers/coach.py` | ⚠️ モック |

**デプロイ済み環境:**
- API URL: `https://8sgr31xa31.execute-api.ap-northeast-1.amazonaws.com/dev/`
- リージョン: ap-northeast-1（東京）

### 未実装

| カテゴリ | 機能 | 優先度 | 備考 |
|---------|------|--------|------|
| **インフラ** | VPC・サブネット設定 | P1 | `network_stack.py` |
| | Aurora Serverless 構築 | P1 | `db_stack.py` |
| | WAF 設定 | P2 | `monitoring_stack.py` |
| **認証** | Lambda Authorizer | P0 | Sign in with Apple JWT検証 |
| | Apple 公開鍵取得 | P0 | JWT 署名検証用 |
| **Lambda関数** | auth handler | P0 | `src/handlers/auth.py` |
| **LangGraph** | コーチングフロー | P0 | `src/graph/coach_graph.py` |
| | 感情分析ノード | P1 | F2機能 |
| | 価値観分析ノード | P1 | F3機能 |
| | 質問生成ノード | P0 | F4機能 |
| | 状態判定ノード | P1 | F5機能 |
| | 行動提案ノード | P1 | F6機能 |
| | ふりかえり支援ノード | P1 | F7機能 |
| | 安全フィルター | P0 | F10機能 |
| **プロンプト** | ベースプロンプト | P0 | `src/prompts/base.py` |
| | 会話テンプレート | P0 | `src/prompts/templates/` |
| | Cycle要素別質問 | P1 | `src/prompts/questions/` |
| **DB** | SQLAlchemy モデル | P0 | `src/models/` |
| | Alembic マイグレーション | P0 | `src/db/migrations/` |
| | ユーザーテーブル | P0 | users |
| | セッションテーブル | P0 | sessions |
| | メッセージテーブル | P0 | messages |
| | タスクテーブル | P1 | tasks |
| **テスト** | ユニットテスト | P1 | `tests/unit/` |
| | 統合テスト | P2 | `tests/integration/` |
| **CI/CD** | GitHub Actions | P1 | `.github/workflows/` |

---

## ディレクトリ構成（現在 vs 計画）

### 現在の構成

```
CycleJournal/
├── docs/
│   ├── 01_product/          # プロダクト設計 ✅
│   ├── 02_privacy_policy/   # プライバシーポリシー ✅
│   ├── 03_api_doc/          # API仕様 ✅
│   ├── 04_development/      # 開発ガイド ✅
│   └── 05_mobile/           # モバイル開発 ✅
│       ├── 00_user_story/   # ユーザーストーリー ✅
│       └── 01_development/  # 開発状況 ✅ ← このファイル
├── mobile/                   # iOSアプリ ⚠️ 部分実装
│   └── CycleJournal/
│       ├── Models/          # ✅ 新規作成
│       ├── Stores/          # ✅ 新規作成
│       └── Views/           # ✅ 新規作成
│           ├── Coach/
│           ├── Tasks/
│           └── Settings/
└── api/                      # ⚠️ 基本構成完了
    ├── cdk/                  # ✅ CDKインフラ
    ├── src/handlers/         # ⚠️ 一部実装
```

### 計画構成

```
CycleJournal/
├── api/                          # バックエンドAPI
│   ├── cdk/                      # CDKインフラ定義
│   │   ├── app.py
│   │   ├── stacks/
│   │   │   ├── network_stack.py
│   │   │   ├── db_stack.py
│   │   │   ├── auth_stack.py
│   │   │   ├── api_stack.py
│   │   │   └── monitoring_stack.py
│   │   └── cdk.json
│   ├── src/
│   │   ├── handlers/             # Lambda関数
│   │   │   ├── coach.py
│   │   │   ├── auth.py
│   │   │   └── health.py
│   │   ├── graph/                # LangGraphフロー
│   │   │   ├── nodes/
│   │   │   │   ├── emotion_analyzer.py
│   │   │   │   ├── value_analyzer.py
│   │   │   │   ├── question_generator.py
│   │   │   │   ├── state_detector.py
│   │   │   │   ├── action_proposer.py
│   │   │   │   ├── reflection_helper.py
│   │   │   │   └── safety_filter.py
│   │   │   └── coach_graph.py
│   │   ├── prompts/              # プロンプトテンプレート
│   │   │   ├── base.py
│   │   │   ├── templates/
│   │   │   └── questions/
│   │   ├── models/               # SQLAlchemyモデル
│   │   │   ├── user.py
│   │   │   ├── session.py
│   │   │   ├── message.py
│   │   │   └── task.py
│   │   └── db/                   # DB接続・マイグレーション
│   │       ├── connection.py
│   │       └── migrations/
│   ├── tests/
│   │   ├── unit/
│   │   └── integration/
│   ├── pyproject.toml
│   └── uv.lock
├── mobile/                       # ✅ 実装済み
└── docs/                         # ✅ 実装済み
```

---

## 開発フェーズ

### Phase 1: MVP（現在）
**目標**: ローカルで動作するプロトタイプ

| 項目 | 状態 |
|------|------|
| Mobile UI | ✅ 完了 |
| ローカルデータ保存 | ✅ 完了 |
| モックAPI応答 | ✅ 完了 |

### Phase 2: バックエンド構築
**目標**: AWS上でAPIを稼働

| 項目 | 状態 |
|------|------|
| CDKインフラ構築 | ✅ 完了（基本構成） |
| Lambda関数実装 | ⚠️ 一部完了（health, coach mock） |
| LangGraphフロー実装 | ❌ 未着手 |
| Bedrock連携 | ❌ 未着手 |

### Phase 3: 認証・API連携
**目標**: Mobile ↔ API の連携完了

| 項目 | 状態 |
|------|------|
| Sign in with Apple | ❌ 未着手 |
| Mobile API クライアント | ❌ 未着手 |
| データ同期 | ❌ 未着手 |

### Phase 4: 品質向上
**目標**: 本番リリースに向けた品質改善

| 項目 | 状態 |
|------|------|
| オンボーディング | ❌ 未着手 |
| 通知機能 | ❌ 未着手 |
| エラーハンドリング | ❌ 未着手 |
| テスト充実 | ❌ 未着手 |

---

## 次のステップ（推奨）

1. ~~**api/ ディレクトリの作成とセットアップ**~~ ✅ 完了
   - `uv init` でPythonプロジェクト作成
   - 依存関係（langchain, langchain-aws, sqlalchemy等）追加

2. ~~**CDKインフラの構築（基本）**~~ ✅ 完了
   - API Gateway、Lambdaのスタック作成
   - dev環境へのデプロイ

3. **Bedrock連携の実装**
   - coach.py に Bedrock (Claude Haiku) 呼び出しを追加
   - プロンプトテンプレートの適用

4. **認証機能の実装**
   - Lambda Authorizer の作成
   - Sign in with Apple JWT検証

5. **LangGraphフローの実装**
   - coach_graph.py の基本フロー
   - 感情分析・質問生成ノードの追加

6. **Mobile API クライアントの実装**
   - URLSession ベースのAPIクライアント
   - CoachStore.sendMessage() の実API呼び出し

---

## 技術的な決定事項

| 項目 | 決定 | 備考 |
|------|------|------|
| LLM | Claude 3 Haiku (Bedrock) | コスト効率重視 |
| フレームワーク | LangChain + LangGraph | 複雑なフロー制御 |
| DB | Aurora Serverless v2 | PostgreSQL互換 |
| 認証 | Sign in with Apple | iOSネイティブ |
| IaC | AWS CDK (Python) | インフラのコード管理 |
| iOS最低バージョン | iOS 15+ | 広めのサポート |
