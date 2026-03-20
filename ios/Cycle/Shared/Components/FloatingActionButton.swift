//
//  FloatingActionButton.swift
//  Cycle
//
//  フローティングアクションボタン（FAB）
//  iOS 26+: Liquid Glass 円形ボタン
//  iOS 17-25: ソリッド背景 + シャドウ
//

import SwiftUI

/// フローティングアクションボタン（FAB）
/// タップ時のスケールアニメーションと触覚フィードバック付き
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(DesignSystem.Fonts.title2)
                .foregroundStyle(fabForeground)
                .frame(width: 56, height: 56)
                .modifier(FABBackgroundStyle(isPressed: isPressed))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("fab_\(icon)")
    }

    private var fabForeground: Color {
        if #available(iOS 26.0, *) {
            return DesignSystem.Colors.accent
        } else {
            return DesignSystem.Colors.background
        }
    }
}

private struct FABBackgroundStyle: ViewModifier {
    let isPressed: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
                .background(DesignSystem.Colors.accent)
                .clipShape(Circle())
                .shadow(
                    color: Color.black.opacity(isPressed ? 0.1 : 0.2),
                    radius: isPressed ? 4 : 8,
                    x: 0,
                    y: isPressed ? 2 : 4
                )
        }
    }
}

/// ボタン押下時のスケールエフェクト
private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(DesignSystem.Timing.fastEasing, value: configuration.isPressed)
    }
}
