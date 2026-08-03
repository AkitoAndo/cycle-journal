//
//  DesignSystem.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import SwiftUI
import UIKit

/// アプリ全体で使用するデザイントークン
///
/// カラー、スペーシング、フォントサイズ、タイミングなどの
/// デザインシステムの定数を一元管理します。
///
/// - Note: 全てのUI要素はここで定義された値を使用することで、
///         一貫性のあるデザインを実現します。
enum DesignSystem {

    /// スペーシング（余白・間隔）の定数
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let mlg: CGFloat = 14
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    enum FontSize {
        static let caption: CGFloat = 12
        static let body: CGFloat = 16
        static let headline: CGFloat = 17
        static let title3: CGFloat = 20
        static let title2: CGFloat = 24
        static let title: CGFloat = 28
        static let largeTitle: CGFloat = 34
    }

    /// フォントスタイルのプリセット
    /// 使用例: .font(DesignSystem.Fonts.screenTitle)
    ///
    /// - 見出し・ボタン・ラベルは rounded デザインで柔らかさを出し、
    ///   本文は可読性を優先して標準デザインのままにする。
    /// - テキストはすべてテキストスタイル基準で Dynamic Type にスケールする。
    ///   装飾アイコンのみ固定サイズ。
    enum Fonts {
        /// 画面タイトル（.title / 28pt bold）— Today's Focus, 3月 等
        static let screenTitle: Font = .system(.title, design: .rounded, weight: .bold)
        /// セクションタイトル（.title3 / 20pt semibold）— セクション見出し
        static let sectionTitle: Font = .system(.title3, design: .rounded, weight: .semibold)
        /// ヘッダーアイコン（26pt 固定）— ナビゲーションバーのアイコン
        static let headerIcon: Font = .system(size: 26)
        /// 見出し（.headline / 17pt semibold）— フォームラベル、リスト見出し
        static let headline: Font = .system(.headline)
        /// 見出し（.body / 17pt regular）— 強調しない見出し
        static let headlineRegular: Font = .system(.body)
        /// 本文（.callout / 16pt）— 通常のテキスト
        static let body: Font = .system(.callout)
        /// 本文（.callout / 16pt medium）— やや強調したテキスト
        static let bodyMedium: Font = .system(.callout, weight: .medium)
        /// 小見出し（.subheadline / 15pt）— 補助テキスト
        static let subheadline: Font = .system(.subheadline)
        /// ラベル（.subheadline / 15pt medium）— タブ、フィルタ
        static let label: Font = .system(.subheadline, design: .rounded, weight: .medium)
        /// キャプション（.caption / 12pt）— 日時、補足情報
        static let caption: Font = .system(.caption)
        /// 小キャプション（.caption2 / 11pt）— バッジ、タブバーラベル
        static let caption2: Font = .system(.caption2)
        /// 大アイコン（48pt 固定）— Empty State のアイコン
        static let largeIcon: Font = .system(size: 48)
        /// 特大アイコン（50pt 固定）— コーチのビジュアル
        static let heroIcon: Font = .system(size: 50)
        /// ボタンテキスト（.headline / 17pt semibold）— プライマリボタン
        static let button: Font = .system(.headline, design: .rounded)
        /// 大タイトル（.largeTitle / 34pt bold）— ログイン画面等
        static let largeTitle: Font = .system(.largeTitle, design: .rounded, weight: .bold)
        /// タイトル2（.title2 / 22pt semibold）— サブ画面タイトル
        static let title2: Font = .system(.title2, design: .rounded, weight: .semibold)
    }

    enum ComponentSize {
        static let inputHeight: CGFloat = 50
        static let buttonHeight: CGFloat = 44
        static let weekStripHeight: CGFloat = 68
        static let iconSize: CGFloat = 24
        static let dateCircle: CGFloat = 40
    }

    enum Timing {
        /// 標準的なアニメーション時間（短い）
        static let fast: Double = 0.15
        /// 標準的なアニメーション時間（通常）
        static let standard: Double = 0.25
        /// 標準的なアニメーション時間（長い）
        static let slow: Double = 0.35

        /// 標準的なイージング
        static let easing: SwiftUI.Animation = .easeInOut(duration: standard)
        /// 速いイージング
        static let fastEasing: SwiftUI.Animation = .easeInOut(duration: fast)
        /// 遅いイージング
        static let slowEasing: SwiftUI.Animation = .easeInOut(duration: slow)

        /// 標準スプリング — 選択状態の移動、カードの出現など UI 全般
        static let spring: SwiftUI.Animation = .spring(response: 0.4, dampingFraction: 0.8)
        /// 弾むスプリング — タブ切替やインジケーター移動など遊びを持たせたい箇所
        static let bouncySpring: SwiftUI.Animation = .spring(response: 0.45, dampingFraction: 0.7)
        /// 穏やかなスプリング — 画面遷移・大きな要素の移動
        static let gentleSpring: SwiftUI.Animation = .spring(response: 0.55, dampingFraction: 0.85)
    }

    /// ライト/ダーク両対応のセマンティックカラー
    ///
    /// ライトはクリーム×ブラウンの温かい世界観、ダークは同系統の
    /// ウォームダーク（焦茶ベース）で世界観を保ったまま反転する。
    enum Colors {
        /// ライト/ダークで切り替わる動的 UIColor を生成する
        /// （UIKit appearance 用にも公開）
        static func adaptiveUIColor(
            light: (CGFloat, CGFloat, CGFloat),
            dark: (CGFloat, CGFloat, CGFloat)
        ) -> UIColor {
            UIColor { trait in
                let (r, g, b) = trait.userInterfaceStyle == .dark ? dark : light
                return UIColor(red: r, green: g, blue: b, alpha: 1)
            }
        }

        private static func adaptive(
            light: (CGFloat, CGFloat, CGFloat),
            dark: (CGFloat, CGFloat, CGFloat)
        ) -> Color {
            Color(adaptiveUIColor(light: light, dark: dark))
        }

        // UIKit appearance（ナビバー等）用の動的 UIColor
        static let backgroundUIColor = adaptiveUIColor(light: (0.98, 0.95, 0.88), dark: (0.11, 0.10, 0.09))
        static let textPrimaryUIColor = adaptiveUIColor(light: (0.15, 0.15, 0.15), dark: (0.93, 0.91, 0.89))
        static let accentUIColor = adaptiveUIColor(light: (0.55, 0.45, 0.35), dark: (0.71, 0.60, 0.49))

        /// ライトの背景はアプリアイコンの生成り（#F8ECD4）を少し薄めたトーン
        static let background = adaptive(light: (0.98, 0.95, 0.88), dark: (0.11, 0.10, 0.09))
        /// カードは背景より明るい温白にして生成り背景から浮かせる
        static let surface = adaptive(light: (0.99, 0.98, 0.95), dark: (0.17, 0.16, 0.15))

        static let textPrimary = adaptive(light: (0.15, 0.15, 0.15), dark: (0.93, 0.91, 0.89))
        static let textSecondary = adaptive(light: (0.45, 0.43, 0.41), dark: (0.66, 0.63, 0.60))
        static let textTertiary = adaptive(light: (0.58, 0.56, 0.54), dark: (0.50, 0.48, 0.46))

        /// アクセント。ダークでは背景に沈まないよう一段明るいブラウンにする
        static let brown = adaptive(light: (0.55, 0.45, 0.35), dark: (0.71, 0.60, 0.49))
        static let brownLight = adaptive(light: (0.75, 0.68, 0.60), dark: (0.55, 0.47, 0.39))
        /// シャドウ用途があるため両モードで暗いまま固定
        static let brownDark = Color(red: 0.35, green: 0.28, blue: 0.22)

        static let grey = adaptive(light: (0.88, 0.87, 0.86), dark: (0.25, 0.24, 0.23))
        static let greyLight = adaptive(light: (0.94, 0.93, 0.92), dark: (0.18, 0.17, 0.16))
        static let greyDark = adaptive(light: (0.70, 0.68, 0.66), dark: (0.45, 0.43, 0.41))

        /// カード上端のハイライト線（ライト: 白 / ダーク: ごく淡い白）
        static let hairlineHighlight = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.08)
                : UIColor(white: 1, alpha: 0.8)
        })

        static let accent = brown
        static let accentLight = brownLight

        /// アクセントのグラデーション — プライマリボタン、選択インジケーター等
        static let accentGradient = LinearGradient(
            colors: [brown, brownDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        /// 画面背景。[0710] 生成り単色（旧グラデーションは廃止）
        static let backgroundGradient = LinearGradient(
            colors: [background, background],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
