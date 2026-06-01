//
//  FloatingActionButton.swift
//  Cycle
//
//  フローティングアクションボタン（FAB）
//  iPhone iOS 26+: Liquid Glass 円形ボタン
//  iPad / iOS 17-25: ソリッド背景 + シャドウ
//

import SwiftUI
import Pow
import UIKit

/// フローティングアクションボタン（FAB）
/// タップ時のスケールアニメーションと触覚フィードバック付き
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void

    @State private var tapCount = 0

    var body: some View {
        Button(action: {
            tapCount += 1
            action()
        }) {
            Image(systemName: icon)
                .font(DesignSystem.Fonts.title2)
                .foregroundStyle(fabForeground)
                .frame(width: 56, height: 56)
                .modifier(FABBackgroundStyle())
                .contentShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .changeEffect(.jump(height: 10), value: tapCount)
        .changeEffect(.feedback(hapticImpact: .medium), value: tapCount)
        .accessibilityIdentifier("fab_\(icon)")
    }

    private var fabForeground: Color {
        if Self.useLiquidGlass {
            return DesignSystem.Colors.accent
        } else {
            return DesignSystem.Colors.background
        }
    }

    /// iPad では iOS 26+ でも Liquid Glass を使わない
    /// （iPadOS 26.x で `glassEffect` の hit-test が抜けるケースが報告されているため）
    static var useLiquidGlass: Bool {
        if #available(iOS 26.0, *) {
            return UIDevice.current.userInterfaceIdiom != .pad
        }
        return false
    }
}

private struct FABBackgroundStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), FloatingActionButton.useLiquidGlass {
            content
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
                .background(DesignSystem.Colors.accent)
                .clipShape(Circle())
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        }
    }
}

/// ボタン押下時のPowプレスエフェクト
private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .conditionalEffect(.pushDown, condition: configuration.isPressed)
    }
}
