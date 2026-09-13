//
//  AppearanceMode.swift
//  Cycle
//

import SwiftUI

/// ユーザーが選択できるアプリの表示モード。
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "cycle.appearanceMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            "システム"
        case .light:
            "ライト"
        case .dark:
            "ダーク"
        }
    }

    var description: String {
        switch self {
        case .system:
            "端末の外観設定に合わせます"
        case .light:
            "明るい背景で表示します"
        case .dark:
            "暗い背景で表示します"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
