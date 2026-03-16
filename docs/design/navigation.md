# ナビゲーション設計

## ナビゲーション構造

### 全体ツリー

```
RootView
├── 未認証
│   └── SignInView（サインイン）
│
└── 認証済み
    └── MainTabView
        ├── Tab 1: 📔 日記
        │   └── DiaryListView
        │       ├── [Sheet] JournalComposerView（日記作成）
        │       ├── [Sheet] JournalComposerView（日記編集）
        │       ├── [Sheet] SearchView（検索）
        │       ├── [Sheet] CalendarView（カレンダー）
        │       └── [Sheet] TagManagementView（タグ管理）
        │
        ├── Tab 2: 🤖 コーチ
        │   └── CoachHomeView
        │       ├── [FullScreen] CoachChatView（チャット）
        │       ├── [Sheet] SessionHistoryView（セッション履歴）
        │       └── [Sheet] DiaryPickerView（日記選択）
        │
        ├── Tab 3: ✅ タスク
        │   └── TaskListView
        │       ├── [Sheet] AddTaskView（タスク作成）
        │       ├── [Sheet] AddTaskView（タスク編集）
        │       ├── [Sheet] TaskDetailView（タスク詳細）
        │       └── [Sheet] TaskReflectionView（振り返り）
        │
        └── Tab 4: ⚙️ 設定
            └── SettingsView
                ├── [Sheet] WebDocumentView（ポリシー等）
                └── [Sheet] DataExportView（データ出力）
```

## タブバー

4つのタブで構成されるメインナビゲーション。

| タブ | アイコン | SF Symbol | ラベル |
|------|---------|-----------|--------|
| 1 | 📔 | `book.fill` | 日記 |
| 2 | 🤖 | `bubble.left.and.bubble.right.fill` | コーチ |
| 3 | ✅ | `checkmark.circle.fill` | タスク |
| 4 | ⚙️ | `gearshape.fill` | 設定 |

## 画面遷移パターン

### Sheet（ボトムシート）

ほとんどの画面遷移は Sheet で実装されています。親画面のコンテキストを保持したまま、子画面を表示します。

| 起点 | Sheet 画面 | トリガー |
|------|-----------|---------|
| 日記一覧 | 日記作成 | FAB タップ |
| 日記一覧 | 日記編集 | スワイプ→編集 |
| 日記一覧 | 検索 | 🔍 ボタン |
| 日記一覧 | カレンダー | 📅 ボタン |
| コーチホーム | セッション履歴 | 「履歴」タップ |
| コーチホーム | 日記選択 | 「日記から話す」タップ |
| タスク一覧 | タスク作成 | FAB タップ |
| タスク一覧 | タスク詳細 | タスク行タップ |
| タスク一覧 | 振り返り | 完了チェック |

### FullScreenCover（フルスクリーン）

没入的な体験が必要な画面で使用します。

| 起点 | FullScreen 画面 | トリガー |
|------|----------------|---------|
| コーチホーム | コーチチャット | 「コーチと話す」タップ |

## 画面遷移フロー

### 認証フロー

```
アプリ起動 → AuthStore 状態チェック
    ├── トークンあり → MainTabView
    └── トークンなし → SignInView
                          ↓
                    Sign in with Apple
                          ↓
                    POST /auth/verify
                          ↓
                    MainTabView
```

### コーチ対話フロー

```
コーチホーム
    ├── 「コーチと話す」
    │       ↓
    │   CoachChatView（新規セッション）
    │       ↓
    │   対話 → 対話 → ... → 終了
    │       ↓
    │   コーチホーム（セッション履歴に追加）
    │
    └── 「日記から話す」
            ↓
        DiaryPickerView（日記選択）
            ↓
        CoachChatView（日記コンテキスト付き）
```

### タスク振り返りフロー

```
タスク一覧
    ↓
完了チェックをタップ
    ↓
TaskReflectionView
    ↓
Step 1: 事実の確認 → Step 2: 感情の観察
    ↓
Step 3: 学びの抽出 → Step 4: 次への調整
    ↓
完了セレブレーション
    ↓
タスク一覧（完了セクションに移動）
```

## 状態管理とナビゲーション

各 Store が画面の表示状態を制御します。

| Store | 管理する状態 | 影響する画面 |
|-------|-------------|-------------|
| AuthStore | 認証状態、ユーザー情報 | Root 分岐（SignIn / Main） |
| DiaryStore | 日記一覧、フィルター | 日記タブ全体 |
| CoachStore | セッション、メッセージ | コーチタブ全体 |
| TaskStore | タスク一覧、振り返り | タスクタブ全体 |
