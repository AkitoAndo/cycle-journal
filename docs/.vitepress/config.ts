import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Cycle Journal',
  description: 'Cycle Journal ドキュメント',
  lang: 'ja-JP',
  themeConfig: {
    nav: [
      { text: 'プロダクト', link: '/01_product/02_function/00_機能一覧' },
      { text: 'API', link: '/03_api_doc/00_API概要' },
      { text: '開発ガイド', link: '/04_development/DEVELOPMENT_GUIDE' },
      { text: 'モバイル', link: '/05_mobile/' },
    ],
    sidebar: {
      '/01_product/': [
        {
          text: 'プロダクト設計',
          items: [
            { text: '機能一覧', link: '/01_product/02_function/00_機能一覧' },
            { text: 'F1 会話エンジン', link: '/01_product/02_function/F1_会話エンジン' },
            { text: 'F2 感情分析', link: '/01_product/02_function/F2_感情分析' },
            { text: 'F3 価値観分析', link: '/01_product/02_function/F3_価値観分析' },
            { text: 'F4 質問生成', link: '/01_product/02_function/F4_質問生成' },
            { text: 'F5 状態判定', link: '/01_product/02_function/F5_状態判定' },
            { text: 'F6 行動提案', link: '/01_product/02_function/F6_行動提案' },
            { text: 'F7 ふりかえり支援', link: '/01_product/02_function/F7_ふりかえり支援' },
            { text: 'F8 文脈管理', link: '/01_product/02_function/F8_文脈管理' },
            { text: 'F9 ユーザーデータ管理', link: '/01_product/02_function/F9_ユーザーデータ管理' },
            { text: 'F10 安全フィルター', link: '/01_product/02_function/F10_安全フィルター' },
            { text: 'F11 エラーハンドリング', link: '/01_product/02_function/F11_エラーハンドリング' },
          ],
        },
      ],
      '/03_api_doc/': [
        {
          text: 'API ドキュメント',
          items: [
            { text: 'API 概要', link: '/03_api_doc/00_API概要' },
            { text: '認証', link: '/03_api_doc/01_認証' },
            { text: 'エンドポイント一覧', link: '/03_api_doc/02_エンドポイント一覧' },
          ],
        },
      ],
      '/04_development/': [
        {
          text: '開発ガイド',
          items: [
            { text: '開発ガイド', link: '/04_development/DEVELOPMENT_GUIDE' },
            { text: '技術スタック', link: '/04_development/TECH_STACK' },
            { text: 'API 設計', link: '/04_development/API_DESIGN' },
            { text: 'インフラ', link: '/04_development/INFRASTRUCTURE' },
            { text: 'テスト', link: '/04_development/TESTING' },
            { text: '認証セットアップ', link: '/04_development/01_認証セットアップ' },
          ],
        },
      ],
      '/02_privacy_policy/': [
        {
          text: 'プライバシーポリシー',
          items: [
            { text: 'プライバシーポリシー', link: '/02_privacy_policy/PRIVACY_POLICY' },
          ],
        },
      ],
    },
    search: {
      provider: 'local',
    },
    outline: {
      level: [2, 3],
      label: '目次',
    },
  },
  ignoreDeadLinks: true,
})
