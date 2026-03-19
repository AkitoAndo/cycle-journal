//
//  HapticFeedback.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import UIKit

/// 触覚フィードバックを提供するユーティリティ
///
/// アプリ全体で一貫した触覚フィードバックを提供するための
/// 簡潔なインターフェースを提供
enum HapticFeedback {
    /// 軽い触覚フィードバック（タグ選択、軽いインタラクション）
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// 中程度の触覚フィードバック（保存、決定アクション）
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// 強い触覚フィードバック（重要なアクション）
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// 成功フィードバック
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// エラーフィードバック
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    /// 警告フィードバック
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}
