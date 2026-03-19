# データモデル

## iOS（ローカル）

### JournalEntry

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | UUID | |
| date | Date | |
| text | String | 日記本文 |
| tags | [String] | タグ一覧 |
| deletedAt | Date? | ソフトデリート用 |

### TaskItem

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | UUID | |
| title | String | |
| description | String? | |
| isCompleted | Bool | |
| createdAt | Date | |
| completedAt | Date? | |
| intent | String? | やる前の意図 |
| achievementVision | String? | 達成イメージ |
| notes | String? | メモ |
| fact | String? | やったこと（ふりかえり） |
| insight | String? | 気づいたこと（ふりかえり） |
| nextAction | String? | 次にやりたいこと（ふりかえり） |
| sortOrder | Int | 並び順 |
| deletedAt | Date? | ソフトデリート用 |

### CoachSession

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | UUID | |
| messages | [CoachMessage] | |
| summary | String? | セッション要約 |
| emotionLabel | String? | 検出された感情 |
| isActive | Bool | |
| createdAt | Date | |

### CoachMessage

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | UUID | |
| role | MessageRole | user / coach |
| content | String | |
| metadata | MessageMetadata? | 感情、Cycle要素、提案アクション |
| createdAt | Date | |

### AuthUser

| フィールド | 型 | 説明 |
|-----------|-----|------|
| userId | String | |
| appleUserId | String | |
| email | String? | |
| fullName | String? | |
| createdAt | Date | |

## Backend（Firestore）

### コレクション構造

```
users/{userId}
  ├── apple_user_id: string
  ├── email: string
  ├── display_name: string
  ├── settings: map
  ├── created_at: timestamp
  │
  ├── sessions/{sessionId}
  │     ├── title: string
  │     ├── cycle_element: string
  │     ├── created_at: timestamp
  │     │
  │     └── messages/{messageId}
  │           ├── role: string (user | assistant)
  │           ├── content: string
  │           ├── metadata: map
  │           └── created_at: timestamp
  │
  └── tasks/{taskId}
        ├── title: string
        ├── description: string
        ├── status: string (pending | completed)
        ├── session_id: string
        ├── cycle_element: string
        ├── created_at: timestamp
        │
        └── reflections/{reflectionId}
              ├── what_i_did: string
              ├── what_i_noticed: string
              ├── what_i_want_to_try: string
              ├── overall_feeling: string
              └── created_at: timestamp
```

API側のリクエスト/レスポンス形式は `docs/api/openapi.yaml` を参照。

### なぜFirestoreか

Cloud SQL（PostgreSQL）ではなくFirestoreを選んだ理由:
- **コスト**: Cloud SQLは最小でも月$10の常時起動コスト。Firestoreは個人利用なら無料枠内
- **スケールtoゼロ**: Cloud Runと合わせて完全にゼロコスト運用が可能
- **データ構造**: users/sessions/messages の入れ子構造がドキュメントDBに自然に対応
- **構成のシンプルさ**: VPC ConnectorやプライベートIP接続が不要

## ストレージ方式

### 現在（ローカルファースト）

| データ | 保存先 |
|--------|--------|
| Journal | `journals.json`（DocumentsDirectory） |
| Tasks | `tasks.json`（DocumentsDirectory） |
| TaskArchive | 日付別JSONファイル |
| CoachSession | UserDefaults |
| AuthToken | Keychain |
| Tags | UserDefaults (`availableTags`) |

### なぜこうしたか

JSONファイル保存にした理由: CoreDataはマイグレーション管理が重く、現段階のデータ量（個人利用）ではオーバー。将来的にAPI同期に移行する前提なので、ローカルは軽量に保つ判断。JSONなら構造が見えやすく、デバッグも容易。
