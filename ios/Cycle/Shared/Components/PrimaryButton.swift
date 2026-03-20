//
//  PrimaryButton.swift
//  Cycle
//
//  プライマリ・セカンダリボタン
//  iOS 26+: Liquid Glass スタイル
//  iOS 17-25: ソリッド背景 / 枠線スタイル
//

import SwiftUI

/// 全幅のプライマリボタン
///
/// 使用例:
/// ```swift
/// PrimaryButton("話しかける", icon: "bubble.left") { startChat() }
/// PrimaryButton("保存する") { save() }
/// ```
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = DesignSystem.Colors.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            buttonContent
        }
        .modifier(PrimaryButtonStyle(color: color))
    }

    private var buttonContent: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
            }
            Text(title)
        }
        .font(DesignSystem.Fonts.button)
        .frame(maxWidth: .infinity)
        .padding()
    }
}

/// 全幅のセカンダリボタン（枠線 / ガラススタイル）
///
/// 使用例:
/// ```swift
/// SecondaryButton("日記から話す", icon: "book", color: .green) { pickDiary() }
/// ```
struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = DesignSystem.Colors.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            buttonContent
        }
        .modifier(SecondaryButtonStyle(color: color))
    }

    private var buttonContent: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
            }
            Text(title)
        }
        .font(DesignSystem.Fonts.button)
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Button Styles

private struct PrimaryButtonStyle: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .foregroundStyle(.white)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        } else {
            content
                .foregroundStyle(.white)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct SecondaryButtonStyle: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .foregroundStyle(color)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        } else {
            content
                .foregroundStyle(color)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color, lineWidth: 1)
                )
        }
    }
}
