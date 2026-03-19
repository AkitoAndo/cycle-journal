import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Cycle Journal',
  description: 'Cycle Journal ドキュメント',
  lang: 'ja-JP',
  themeConfig: {
    nav: [
      { text: 'プロダクト設計', link: '/product/prompts/A-01_ベースプロンプト' },
      { text: 'API', link: '/api/00_API概要' },
      { text: '開発ガイド', link: '/development/DEVELOPMENT_GUIDE' },
      { text: 'モバイル', link: '/mobile/user-story/coach_chat_screens' },
    ],
    sidebar: [
      {
        text: 'プロダクト設計',
        collapsed: false,
        items: [
          {
            text: 'プロンプト設計',
            collapsed: true,
            items: [
              { text: 'タスクリスト', link: '/product/prompts/00_タスクリスト' },
              { text: 'A-01: ベースプロンプト', link: '/product/prompts/A-01_ベースプロンプト' },
              { text: 'A-02: 会話テンプレート', link: '/product/prompts/A-02_会話テンプレート' },
              { text: 'A-03: ユーザー状態別プロンプト', link: '/product/prompts/A-03_ユーザー状態別プロンプト' },
              { text: 'A-04: タスク提案プロンプト', link: '/product/prompts/A-04_タスク提案プロンプト' },
              { text: 'A-05: ふりかえり支援', link: '/product/prompts/A-05_ふりかえり支援' },
              { text: 'A-06: 禁止表現ルール', link: '/product/prompts/A-06_禁止表現ルール' },
              { text: 'B-01: 感情ラベル辞書', link: '/product/prompts/B-01_感情ラベル辞書' },
              { text: 'B-02: 価値観辞書', link: '/product/prompts/B-02_価値観辞書' },
              { text: 'B-03: 内省質問テンプレート', link: '/product/prompts/B-03_内省質問テンプレート' },
              { text: 'B-04: 行動変容モデル', link: '/product/prompts/B-04_行動変容モデル' },
              { text: 'B-05: ユーザーデータ活用', link: '/product/prompts/B-05_ユーザーデータ活用' },
              { text: 'B-06: 文脈管理ルール', link: '/product/prompts/B-06_文脈管理ルール' },
              { text: 'C-01: コーチ人格設計', link: '/product/prompts/C-01_コーチ人格設計' },
              { text: 'C-02: 会話トーンガイド', link: '/product/prompts/C-02_会話トーンガイド' },
              { text: 'C-03: 成長支援方針', link: '/product/prompts/C-03_成長支援方針' },
              { text: 'C-04: エラー対応', link: '/product/prompts/C-04_エラー対応' },
            ],
          },
          {
            text: '機能仕様',
            collapsed: true,
            items: [
              { text: '機能一覧', link: '/product/functions/00_機能一覧' },
              { text: 'F1. 会話エンジン', link: '/product/functions/F1_会話エンジン' },
              { text: 'F2. 感情分析', link: '/product/functions/F2_感情分析' },
              { text: 'F3. 価値観分析', link: '/product/functions/F3_価値観分析' },
              { text: 'F4. 質問生成', link: '/product/functions/F4_質問生成' },
              { text: 'F5. 状態判定', link: '/product/functions/F5_状態判定' },
              { text: 'F6. 行動提案', link: '/product/functions/F6_行動提案' },
              { text: 'F7. ふりかえり支援', link: '/product/functions/F7_ふりかえり支援' },
              { text: 'F8. 文脈管理', link: '/product/functions/F8_文脈管理' },
              { text: 'F9. ユーザーデータ管理', link: '/product/functions/F9_ユーザーデータ管理' },
              { text: 'F10. 安全フィルター', link: '/product/functions/F10_安全フィルター' },
              { text: 'F11. エラーハンドリング', link: '/product/functions/F11_エラーハンドリング' },
            ],
          },
        ],
      },
      {
        text: 'プライバシーポリシー',
        items: [
          { text: 'プライバシーポリシー', link: '/legal/PRIVACY_POLICY' },
        ],
      },
      {
        text: 'API ドキュメント',
        collapsed: false,
        items: [
          { text: 'API 概要', link: '/api/00_API概要' },
          { text: '認証', link: '/api/01_認証' },
          { text: 'エンドポイント一覧', link: '/api/02_エンドポイント一覧' },
        ],
      },
      {
        text: '開発ガイド',
        collapsed: false,
        items: [
          { text: '開発ガイド', link: '/development/DEVELOPMENT_GUIDE' },
          { text: '技術スタック', link: '/development/TECH_STACK' },
          { text: 'API 設計方針', link: '/development/API_DESIGN' },
          { text: 'インフラ設計', link: '/development/INFRASTRUCTURE' },
          { text: '認証セットアップ', link: '/development/01_認証セットアップ' },
          { text: 'テスト方針', link: '/development/TESTING' },
        ],
      },
      {
        text: 'モバイル',
        collapsed: false,
        items: [
          { text: 'チャット画面ストーリー', link: '/mobile/user-story/coach_chat_screens' },
          { text: '実装済み機能一覧', link: '/mobile/user-story/implemented_features' },
          { text: '開発状況', link: '/mobile/development/DEVELOPMENT_STATUS' },
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
