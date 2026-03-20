//
//  DesignSystem.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import SwiftUI

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
    enum Fonts {
        /// 画面タイトル（28pt bold）— Today's Focus, 3月 等
        static let screenTitle: Font = .system(size: FontSize.title, weight: .bold)
        /// セクションタイトル（20pt semibold）— セクション見出し
        static let sectionTitle: Font = .system(size: FontSize.title3, weight: .semibold)
        /// ヘッダーアイコン（26pt）— ナビゲーションバーのアイコン
        static let headerIcon: Font = .system(size: 26)
        /// 見出し（17pt semibold）— フォームラベル、リスト見出し
        static let headline: Font = .system(size: FontSize.headline, weight: .semibold)
        /// 見出し（17pt regular）— 強調しない見出し
        static let headlineRegular: Font = .system(size: FontSize.headline)
        /// 本文（16pt）— 通常のテキスト
        static let body: Font = .system(size: FontSize.body)
        /// 本文（16pt medium）— やや強調したテキスト
        static let bodyMedium: Font = .system(size: FontSize.body, weight: .medium)
        /// 小見出し（15pt）— 補助テキスト
        static let subheadline: Font = .system(size: 15)
        /// ラベル（14pt medium）— タブ、フィルタ
        static let label: Font = .system(size: 14, weight: .medium)
        /// キャプション（12pt）— 日時、補足情報
        static let caption: Font = .system(size: FontSize.caption)
        /// 小キャプション（10pt）— バッジ、タブバーラベル
        static let caption2: Font = .system(size: 10)
        /// 大アイコン（48pt）— Empty State のアイコン
        static let largeIcon: Font = .system(size: 48)
        /// 特大アイコン（50pt）— コーチのビジュアル
        static let heroIcon: Font = .system(size: 50)
        /// ボタンテキスト（17pt semibold）— プライマリボタン
        static let button: Font = .system(size: FontSize.headline, weight: .semibold)
        /// 大タイトル（34pt bold）— ログイン画面等
        static let largeTitle: Font = .system(size: FontSize.largeTitle, weight: .bold)
        /// タイトル2（24pt semibold）— サブ画面タイトル
        static let title2: Font = .system(size: FontSize.title2, weight: .semibold)
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
    }

    enum Colors {
        static let background = Color(red: 0.99, green: 0.99, blue: 0.98)
        static let secondaryBackground = Color(red: 0.96, green: 0.96, blue: 0.95)
        static let surface = Color(red: 0.95, green: 0.94, blue: 0.93)

        static let textPrimary = Color(red: 0.15, green: 0.15, blue: 0.15)
        static let textSecondary = Color(red: 0.5, green: 0.48, blue: 0.46)
        static let textTertiary = Color(red: 0.65, green: 0.63, blue: 0.61)

        static let brown = Color(red: 0.55, green: 0.45, blue: 0.35)
        static let brownLight = Color(red: 0.75, green: 0.68, blue: 0.60)
        static let brownDark = Color(red: 0.35, green: 0.28, blue: 0.22)

        static let grey = Color(red: 0.88, green: 0.87, blue: 0.86)
        static let greyLight = Color(red: 0.94, green: 0.93, blue: 0.92)
        static let greyDark = Color(red: 0.70, green: 0.68, blue: 0.66)

        static let accent = brown
        static let accentLight = brownLight
    }
}
