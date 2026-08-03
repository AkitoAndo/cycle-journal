//
//  PrimaryButton.swift
//  Cycle
//
//  プライマリ・セカンダリボタン
//  日記CTA / チャット吹き出しと同じアクセント色を使う共通ボタン
//

import SwiftUI
import Pow

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
    var fullWidth: Bool = true
    let action: () -> Void
    @State private var tapCount = 0

    init(_ title: String, icon: String? = nil, fullWidth: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.fullWidth = fullWidth
        self.action = action
    }

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            buttonContent
        }
        .buttonStyle(PressableButtonStyle())
        .modifier(PrimaryButtonStyle())
        .changeEffect(.shine(angle: .degrees(24), duration: DesignSystem.Timing.slow), value: tapCount)
        .changeEffect(.feedback(hapticImpact: .light), value: tapCount)
    }

    private var buttonContent: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
            }
            Text(title)
        }
        .font(DesignSystem.Fonts.button)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .padding(.horizontal, DesignSystem.Spacing.xxl)
        .padding(.vertical, DesignSystem.Spacing.md)
    }
}

/// 全幅のセカンダリボタン（チャットのコーチ吹き出しに近い surface 色）
///
/// 使用例:
/// ```swift
/// SecondaryButton("日記から話す", icon: "book") { pickDiary() }
/// ```
struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    @State private var tapCount = 0

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            buttonContent
        }
        .buttonStyle(PressableButtonStyle())
        .modifier(SecondaryButtonStyle())
        .changeEffect(
            .pulse(
                shape: Capsule(),
                style: DesignSystem.Colors.accent.opacity(0.24),
                drawingMode: .stroke
            ),
            value: tapCount
        )
        .changeEffect(.feedbackHapticSelection, value: tapCount)
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
        .padding(.horizontal, DesignSystem.Spacing.xxl)
        .padding(.vertical, DesignSystem.Spacing.md)
    }
}

// MARK: - Button Styles

private struct PrimaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.white)
            .background(DesignSystem.Colors.accentGradient)
            .clipShape(Capsule())
            .shadow(color: DesignSystem.Colors.accent.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

private struct SecondaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(DesignSystem.Colors.accent)
            .background(DesignSystem.Colors.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(DesignSystem.Colors.accent.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: DesignSystem.Colors.brownDark.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
