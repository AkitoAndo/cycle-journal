//
//  PrimaryButton.swift
//  Cycle
//
//  プライマリ・セカンダリボタン
//  iOS 26+: Liquid Glass スタイル
//  iOS 17-25: ソリッド背景 / 枠線スタイル
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
    var color: Color = DesignSystem.Colors.accent
    let action: () -> Void
    @State private var tapCount = 0

    init(_ title: String, icon: String? = nil, color: Color = DesignSystem.Colors.accent, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
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
        .modifier(PrimaryButtonStyle(color: color))
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
    @State private var tapCount = 0

    init(_ title: String, icon: String? = nil, color: Color = DesignSystem.Colors.accent, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
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
        .modifier(SecondaryButtonStyle(color: color))
        .changeEffect(
            .pulse(
                shape: RoundedRectangle(cornerRadius: 12, style: .continuous),
                style: color.opacity(0.24),
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
                .background(
                    // 単色の上に上端ハイライトを重ねて奥行きを出す
                    ZStack {
                        color
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: color.opacity(0.25), radius: 8, x: 0, y: 4)
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
