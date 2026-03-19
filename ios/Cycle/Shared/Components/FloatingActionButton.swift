//
//  FloatingActionButton.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/29.
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
            // 触覚フィードバック
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.FontSize.title2, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.background)
                .frame(width: 56, height: 56)
                .background(DesignSystem.Colors.accent)
                .clipShape(Circle())
                .shadow(
                    color: Color.black.opacity(isPressed ? 0.1 : 0.2),
                    radius: isPressed ? 4 : 8,
                    x: 0,
                    y: isPressed ? 2 : 4
                )
        }
        .buttonStyle(ScaleButtonStyle())
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
