import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Cycle Journal',
  description: 'Cycle Journal ドキュメント',
  lang: 'ja-JP',
  base: '/cycle-journal/',
  ignoreDeadLinks: true,
  themeConfig: {
    nav: [
      { text: 'バックログ', link: '/backlog/' },
      { text: 'プロダクト設計', link: '/product/coach-design' },
      { text: 'アーキテクチャ', link: '/architecture/overview' },
      { text: '開発ガイド', link: '/guides/getting-started' },
    ],
    sidebar: [
      {
        text: 'はじめに',
        items: [
          { text: 'プロジェクト概要', link: '/README' },
          { text: 'ロードマップ', link: '/roadmap' },
        ],
      },
      {
        text: 'プロダクト設計',
        collapsed: false,
        items: [
          { text: 'コーチ設計', link: '/product/coach-design' },
          { text: 'Cycleモデル', link: '/product/cycle-model' },
          { text: 'プロンプトカタログ', link: '/product/prompt-catalog' },
        ],
      },
      {
        text: 'アーキテクチャ',
        collapsed: false,
        items: [
          { text: '全体構成', link: '/architecture/overview' },
          { text: 'データモデル', link: '/architecture/data-model' },
          { text: 'API設計', link: '/architecture/api-contract' },
        ],
      },
      {
        text: '開発ガイド',
        collapsed: false,
        items: [
          { text: 'Getting Started', link: '/guides/getting-started' },
          { text: '開発規約', link: '/guides/conventions' },
          { text: 'App Storeリリース', link: '/guides/app-store-release' },
          {
            text: '#37 デプロイメントセットアップ',
            collapsed: true,
            items: [
              { text: '進行表 (README)', link: '/guides/37-deployment-setup/' },
              { text: '01. App Store Connect IAP', link: '/guides/37-deployment-setup/01-app-store-connect-iap' },
              { text: '02. IAP Key と Secret Manager', link: '/guides/37-deployment-setup/02-iap-key-secret-manager' },
              { text: '03. Apple PKI ルート証明書', link: '/guides/37-deployment-setup/03-apple-root-certs' },
              { text: '04. ASSN V2 Webhook 登録', link: '/guides/37-deployment-setup/04-assn-v2-webhook' },
              { text: '05. .storekit Configuration', link: '/guides/37-deployment-setup/05-storekit-config-xcode' },
              { text: '06. Firebase / iOS SDK', link: '/guides/37-deployment-setup/06-firebase-analytics' },
              { text: '07. GA4 Measurement Protocol', link: '/guides/37-deployment-setup/07-ga4-measurement-protocol' },
              { text: '08. BigQuery + Looker Studio', link: '/guides/37-deployment-setup/08-bigquery-looker-studio' },
              { text: '09. Vertex AI モデル検証', link: '/guides/37-deployment-setup/09-vertex-ai-models' },
              { text: '10. Terms / Privacy URL', link: '/guides/37-deployment-setup/10-legal-urls' },
              { text: '動作確認チェックリスト', link: '/guides/37-deployment-setup/verification-checklist' },
            ],
          },
        ],
      },
      {
        text: 'バックログ',
        collapsed: false,
        items: [
          { text: 'PBL一覧', link: '/backlog/' },
          {
            text: 'Journal',
            collapsed: true,
            items: [
              { text: 'J-01: 日記CRUD', link: '/backlog/journal/J-01-crud' },
              { text: 'J-02: タグ管理', link: '/backlog/journal/J-02-tags' },
              { text: 'J-03: 検索', link: '/backlog/journal/J-03-search' },
              { text: 'J-04: カレンダー', link: '/backlog/journal/J-04-calendar' },
              { text: 'J-05: ゴミ箱', link: '/backlog/journal/J-05-trash' },
              { text: 'J-06: サーバー同期', link: '/backlog/journal/J-06-sync' },
            ],
          },
          {
            text: 'Coach',
            collapsed: true,
            items: [
              { text: 'C-01: ホーム画面', link: '/backlog/coach/C-01-home' },
              { text: 'C-02: チャットUI', link: '/backlog/coach/C-02-chat' },
              { text: 'C-03: 会話履歴', link: '/backlog/coach/C-03-history' },
              { text: 'C-04: 日記連携', link: '/backlog/coach/C-04-diary-picker' },
              { text: 'C-05: API接続', link: '/backlog/coach/C-05-api' },
              { text: 'C-06: LangGraph', link: '/backlog/coach/C-06-langgraph' },
              { text: 'C-07: 文脈管理', link: '/backlog/coach/C-07-context' },
              { text: 'C-08: 導入体験', link: '/backlog/coach/C-08-intro-breathing' },
              { text: 'C-09: チャットUI(内省型)', link: '/backlog/coach/C-09-chat-ui' },
              { text: 'C-10: セッション設計', link: '/backlog/coach/C-10-session-design' },
              { text: 'C-11: システムプロンプト', link: '/backlog/coach/C-11-system-prompt' },
            ],
          },
          {
            text: 'Store',
            collapsed: true,
            items: [
              { text: 'AS-01: App Store掲載テキスト', link: '/backlog/store/AS-01-store-description' },
            ],
          },
          {
            text: 'Tasks',
            collapsed: true,
            items: [
              { text: 'T-01: タスクCRUD', link: '/backlog/tasks/T-01-crud' },
              { text: 'T-02: ふりかえり', link: '/backlog/tasks/T-02-reflection' },
              { text: 'T-03: 並べ替え', link: '/backlog/tasks/T-03-reorder' },
              { text: 'T-04: アーカイブ', link: '/backlog/tasks/T-04-archive' },
              { text: 'T-05: サーバー同期', link: '/backlog/tasks/T-05-sync' },
            ],
          },
          {
            text: 'Auth',
            collapsed: true,
            items: [
              { text: 'A-01: サインインUI', link: '/backlog/auth/A-01-signin-ui' },
              { text: 'A-02: 認証ミドルウェア', link: '/backlog/auth/A-02-authorizer' },
              { text: 'A-03: 認証フロー', link: '/backlog/auth/A-03-auth-flow' },
            ],
          },
          {
            text: 'Settings',
            collapsed: true,
            items: [
              { text: 'S-01: 設定画面UI', link: '/backlog/settings/S-01-ui' },
              { text: 'S-02: 通知', link: '/backlog/settings/S-02-notifications' },
              { text: 'S-03: エクスポート', link: '/backlog/settings/S-03-export' },
            ],
          },
          {
            text: 'Backend',
            collapsed: true,
            items: [
              { text: 'B-01: Terraform基本構成', link: '/backlog/backend/B-01-cdk-base' },
              { text: 'B-02: Firestore', link: '/backlog/backend/B-02-aurora' },
              { text: 'B-03: ベースプロンプト', link: '/backlog/backend/B-03-base-prompt' },
              { text: 'B-04: 安全フィルター', link: '/backlog/backend/B-04-safety' },
                          ],
          },
          {
            text: 'UX',
            collapsed: true,
            items: [
              { text: 'U-01: オンボーディング', link: '/backlog/ux/U-01-onboarding' },
              { text: 'U-02: エラーハンドリング', link: '/backlog/ux/U-02-error-handling' },
            ],
          },
        ],
      },
      {
        text: 'その他',
        items: [
          { text: 'プライバシーポリシー', link: '/legal/PRIVACY_POLICY' },
        ],
      },
    ],
    search: {
      provider: 'local',
    },
    outline: {
      level: [2, 3],
      label: '目次',
    },
  },
})
