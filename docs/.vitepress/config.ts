import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Cycle Journal',
  description: 'Cycle Journal ドキュメント',
  lang: 'ja-JP',
  themeConfig: {
    nav: [
      { text: 'ビジネス', link: '/business/' },
      { text: 'テクノロジー', link: '/technology/' },
      { text: 'デザイン', link: '/design/' },
    ],
    sidebar: {
      '/business/': [
        {
          text: 'ビジネス',
          items: [
            { text: '概要', link: '/business/' },
            { text: 'プロダクト概要', link: '/business/product-overview' },
            { text: '機能一覧', link: '/business/features' },
            { text: 'ユーザーストーリー', link: '/business/user-stories' },
            { text: 'プライバシーポリシー', link: '/business/privacy-policy' },
          ],
        },
      ],
      '/technology/': [
        {
          text: 'テクノロジー',
          items: [
            { text: '概要', link: '/technology/' },
            { text: 'アーキテクチャ', link: '/technology/architecture' },
            { text: 'API リファレンス', link: '/technology/api-reference' },
            { text: '認証', link: '/technology/authentication' },
            { text: 'インフラストラクチャ', link: '/technology/infrastructure' },
            { text: '開発ガイド', link: '/technology/development-guide' },
            { text: 'テスト戦略', link: '/technology/testing' },
          ],
        },
      ],
      '/design/': [
        {
          text: 'デザイン',
          items: [
            { text: '概要', link: '/design/' },
            { text: 'デザインシステム', link: '/design/design-system' },
            { text: '画面一覧', link: '/design/screens' },
            { text: 'ナビゲーション設計', link: '/design/navigation' },
            { text: 'インタラクション', link: '/design/interactions' },
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
