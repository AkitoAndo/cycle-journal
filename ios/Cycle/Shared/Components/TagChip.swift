//
//  TagChip.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import SwiftUI
import Pow

/// タグを表示するための小さなチップコンポーネント
struct TagChip: View {
    let text: String
    var isInteractive: Bool = false
    var onTap: (() -> Void)? = nil
    @State private var tapCount = 0

    var body: some View {
        Group {
            if isInteractive, let onTap = onTap {
                Button {
                    tapCount += 1
                    onTap()
                } label: {
                    chipContent
                }
                .buttonStyle(.plain)
                .changeEffect(
                    .pulse(
                        shape: Capsule(style: .continuous),
                        style: DesignSystem.Colors.accent.opacity(0.18),
                        drawingMode: .stroke
                    ),
                    value: tapCount
                )
            } else {
                chipContent
            }
        }
    }

    private var chipContent: some View {
        Text(text)
            .font(.system(size: DesignSystem.FontSize.caption - 1, weight: .medium, design: .rounded))
            .foregroundStyle(DesignSystem.Colors.accent)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .modifier(TagChipBackgroundStyle())
    }
}

private struct TagChipBackgroundStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(DesignSystem.Colors.accent.opacity(0.10))
                .clipShape(Capsule())
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(DesignSystem.Colors.accent.opacity(0.10))
                .clipShape(Capsule())
        }
    }
}
