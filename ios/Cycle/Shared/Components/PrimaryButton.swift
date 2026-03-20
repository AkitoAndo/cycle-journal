//
//  PrimaryButton.swift
//  Cycle
//
//  プライマリ・セカンダリボタン
//  CoachHome, SignIn, Settings 等の全幅ボタンで共通利用
//

import SwiftUI

/// 全幅のプライマリボタン
///
/// 使用例:
/// ```swift
/// PrimaryButton("話しかける", icon: "bubble.left") { startChat() }
/// PrimaryButton("保存する") { save() }
/// SecondaryButton("日記から話す", icon: "book", color: .green) { pickDiary() }
/// ```
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = DesignSystem.Colors.accent
    let action: () -> Void

    init(_ title: String, icon: String? = nil, color: Color = DesignSystem.Colors.accent, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(DesignSystem.Fonts.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// 全幅のセカンダリボタン（枠線スタイル）
struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = DesignSystem.Colors.accent
    let action: () -> Void

    init(_ title: String, icon: String? = nil, color: Color = DesignSystem.Colors.accent, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(DesignSystem.Fonts.button)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 1)
            )
        }
    }
}
