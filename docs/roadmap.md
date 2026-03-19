# Product Roadmap

## AS-IS（現状 / 2026-03時点）

### iOS
- Journal: ローカルCRUD完成（タグ管理、検索、週間カレンダー、ソフトデリート）
- Tasks: ローカルCRUD完成（ふりかえり項目: fact/insight/nextAction、並び替え、アーカイブ）
- Coach: チャットUI・セッション履歴・日記選択画面が動作。応答はモックのみ
- Auth: Sign in with Apple のUI実装済。サーバー検証なし
- Settings: UI骨格のみ（通知・エクスポートは未実装）
- データ保存: JSONファイル（DocumentsDirectory）+ UserDefaults。API同期なし

### Backend
- CDKインフラ基本構成デプロイ済（API Gateway + Lambda）
- health / coach(モック) の2エンドポイントのみ
- Aurora, VPC, WAF, Lambda Authorizer, LangGraph: 未実装
- デプロイ済URL: `https://8sgr31xa31.execute-api.ap-northeast-1.amazonaws.com/dev/`

## TO-BE

### v1.0 - MVP（1人で使える状態）
- [ ] Coach ↔ Backend API接続（Bedrock Claude Haiku）
- [ ] 認証フロー完成（Lambda Authorizer + Apple JWT検証）
- [ ] 基本プロンプト動作（ベースプロンプト + 会話テンプレート + 安全フィルター）
- [ ] セッション・メッセージのDB保存（Aurora）

### v1.1 - コーチング品質向上
- [ ] LangGraphフロー実装（感情分析・質問生成・状態判定）
- [ ] Cycleモデルに基づくプロンプト最適化
- [ ] 文脈管理（過去の会話・日記内容の参照）

### v1.2 - データ同期
- [ ] タスクのサーバー同期
- [ ] 日記のサーバー同期（オプション）

### v2.0 - リリース品質
- [ ] オンボーディング
- [ ] 通知（リマインダー、タスク期限）
- [ ] データエクスポート
- [ ] エラーハンドリング強化
- [ ] テスト充実（カバレッジ80%目標）
