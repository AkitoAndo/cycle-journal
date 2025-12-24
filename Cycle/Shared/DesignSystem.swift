//
//  DesignSystem.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import SwiftUI

/// アプリ全体で使用するデザイントークン
enum DesignSystem {

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

    enum ComponentSize {
        static let inputHeight: CGFloat = 50
        static let buttonHeight: CGFloat = 44
        static let weekStripHeight: CGFloat = 80
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
