# Product Roadmap

## AS-IS（現状 / 2026-03時点）

### iOS
- Journal: ローカルCRUD完成（タグ管理、検索、週間カレンダー、ソフトデリート）
- Tasks: ローカルCRUD完成（ふりかえり項目: fact/insight/nextAction、並び替え、アーカイブ）
- Coach: チャットUI・セッション履歴・日記選択画面が動作。API接続済（requiresAuth: true）
- Auth: Sign in with Apple のUI実装済。サーバー検証エンドポイント接続済
- Settings: UI骨格のみ（通知・エクスポートは未実装）
- データ保存: JSONファイル（DocumentsDirectory）+ UserDefaults + サーバー同期（タスクCRUD・セッション履歴）
- E2Eテスト: Cloud Run APIに対する9テスト通過

### Backend
- FastAPI + Cloud Run: 全13エンドポイント実装・デプロイ済（dev環境）
- Firestore: データベース + 複合インデックス2つ作成済
- Terraform: 16リソース全てapply済・state管理下
- Docker: uvベースのコンテナビルド（linux/amd64）
- Apple JWT認証: JWKS取得・キャッシュ・検証ミドルウェア実装済
- コーチAI: SYSTEM_PROMPT（大樹メタファー + 7ルール）+ Vertex AI Claude + LangGraphフロー
- テスト: pytest 10件 + iOS E2E 9件 通過

## TO-BE

### v1.0 - MVP（1人で使える状態）
- [x] API基盤構築（FastAPI + Cloud Run + Firestore + Terraform）
- [x] 認証ミドルウェア実装（FastAPI ミドルウェア + Apple JWT検証）
- [x] セッション・タスクのCRUDエンドポイント実装
- [x] Coach ↔ Backend API接続（Vertex AI Claude）
- [x] 基本プロンプト動作（ベースプロンプト + 大樹メタファー + 安全フィルター）
- [x] iOS ↔ API接続（Coach送受信 + セッション履歴取得）
- [x] タスクのサーバー同期（CRUD + ステータス同期）
- [ ] 認証フロー完成（E2E: Sign in with Apple → JWT検証 → トークンリフレッシュ）

### v1.1 - コーチング品質向上
- [x] LangGraphフロー実装（感情分析 → Cycle要素判定 → 応答生成 → 安全フィルター）
- [ ] Cycleモデルに基づくプロンプト最適化
- [ ] 文脈管理（過去の会話・日記内容の参照）

### v1.2 - データ同期
- [ ] 日記のサーバー同期（オプション）

### v2.0 - リリース品質
- [ ] オンボーディング
- [ ] 通知（リマインダー、タスク期限）
- [ ] データエクスポート
- [ ] エラーハンドリング強化
- [ ] テスト充実（カバレッジ80%目標）
