# プロダクトバックログ

## 凡例

| ステータス | 意味 |
|-----------|------|
| :white_check_mark: Done | 実装済み（スクリーンショットあり） |
| :construction: In Progress | 実装中 |
| :memo: Refinement | 未実装・リファインメント中 |

---

## Journal

| # | アイテム | ステータス | 優先度 |
|---|---------|-----------|--------|
| J-01 | [日記の作成・編集・削除](./journal/J-01-crud) | :white_check_mark: Done | - |
| J-02 | [タグ管理（CRUD・並べ替え）](./journal/J-02-tags) | :white_check_mark: Done | - |
| J-03 | [キーワード検索・タグフィルタ](./journal/J-03-search) | :white_check_mark: Done | - |
| J-04 | [週間カレンダーナビゲーション](./journal/J-04-calendar) | :white_check_mark: Done | - |
| J-05 | [ゴミ箱（ソフトデリート・復元）](./journal/J-05-trash) | :white_check_mark: Done | - |
| J-06 | [日記のサーバー同期](./journal/J-06-sync) | :memo: Refinement | P1 |

## Coach

| # | アイテム | ステータス | 優先度 |
|---|---------|-----------|--------|
| C-01 | [コーチホーム画面](./coach/C-01-home) | :white_check_mark: Done | - |
| C-02 | [チャット画面（UI）](./coach/C-02-chat) | :white_check_mark: Done | - |
| C-03 | [会話履歴一覧](./coach/C-03-history) | :white_check_mark: Done | - |
| C-04 | [日記からコーチへ連携](./coach/C-04-diary-picker) | :white_check_mark: Done | - |
| C-05 | [Backend API接続（Vertex AI）](./coach/C-05-api) | :memo: Refinement | P0 |
| C-06 | [LangGraphフロー（感情分析・質問生成）](./coach/C-06-langgraph) | :memo: Refinement | P0 |
| C-07 | [文脈管理（過去の会話参照）](./coach/C-07-context) | :memo: Refinement | P1 |

## Tasks

| # | アイテム | ステータス | 優先度 |
|---|---------|-----------|--------|
| T-01 | [タスク一覧・追加・完了・削除](./tasks/T-01-crud) | :white_check_mark: Done | - |
| T-02 | [ふりかえり入力（fact/insight/nextAction）](./tasks/T-02-reflection) | :white_check_mark: Done | - |
| T-03 | [並べ替え（ドラッグ）](./tasks/T-03-reorder) | :white_check_mark: Done | - |
| T-04 | [アーカイブ（日別）](./tasks/T-04-archive) | :white_check_mark: Done | - |
| T-05 | [タスクのサーバー同期](./tasks/T-05-sync) | :memo: Refinement | P1 |

## Auth

| # | アイテム | ステータス | 優先度 |
|---|---------|-----------|--------|
| A-01 | [Sign in with Apple（UI）](./auth/A-01-signin-ui) | :white_check_mark: Done | - |
| A-02 | [認証ミドルウェア（JWT検証）](./auth/A-02-authorizer) | :memo: Refinement | P0 |
| A-03 | [認証フロー完成（E2E）](./auth/A-03-auth-flow) | :memo: Refinement | P0 |

## Settings

| # | アイテム | ステータス | 優先度 |
|---|---------|-----------|--------|
| S-01 | [設定画面（UI骨格）](./settings/S-01-ui) | :white_check_mark: Done | - |
| S-02 | [通知設定（リマインダー）](./settings/S-02-notifications) | :memo: Refinement | P2 |
| S-03 | [データエクスポート](./settings/S-03-export) | :memo: Refinement | P3 |

## Backend Infrastructure

| # | アイテム | ステータス | 優先度 |
|---|---------|-----------|--------|
| B-01 | [Terraform基本構成（Cloud Run）](./backend/B-01-cdk-base) | :memo: Refinement | P0 |
| B-02 | [Firestore セットアップ](./backend/B-02-aurora) | :memo: Refinement | P0 |
| B-03 | [ベースプロンプト実装](./backend/B-03-base-prompt) | :memo: Refinement | P0 |
| B-04 | [安全フィルター](./backend/B-04-safety) | :memo: Refinement | P0 |
| ~~B-05~~ | ~~Cloud Armor設定~~ | 削除 | - |

## UX

| # | アイテム | ステータス | 優先度 |
|---|---------|-----------|--------|
| U-01 | [オンボーディング](./ux/U-01-onboarding) | :memo: Refinement | P2 |
| U-02 | [エラーハンドリング強化](./ux/U-02-error-handling) | :memo: Refinement | P1 |
