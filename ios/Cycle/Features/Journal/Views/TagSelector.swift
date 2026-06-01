//
//  TagSelector.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/29.
//

import SwiftUI
import Pow

/// タグ選択用のコンポーネント
/// 利用可能なタグ一覧から複数選択可能
struct TagSelector: View {
    let availableTags: [String]
    @Binding var selectedTags: [String]

    var body: some View {
        if !availableTags.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("タグ")
                    .font(DesignSystem.Fonts.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(availableTags, id: \.self) { tag in
                            TagButton(
                                tag: tag,
                                isSelected: selectedTags.contains(tag)
                            ) {
                                toggleTag(tag)
                            }
                        }
                    }
                }
            }
        }
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.removeAll { $0 == tag }
        } else {
            selectedTags.append(tag)
        }

    }
}

/// 個別のタグボタン
private struct TagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(DesignSystem.Fonts.caption)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs + 2)
                .modifier(TagButtonStyle(isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .changeEffect(
            .pulse(
                shape: Capsule(style: .continuous),
                style: DesignSystem.Colors.accent.opacity(0.2),
                drawingMode: .stroke
            ),
            value: isSelected,
            isEnabled: isSelected
        )
        .changeEffect(.feedbackHapticSelection, value: isSelected)
    }
}

private struct TagButtonStyle: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if isSelected {
                content
                    .background(DesignSystem.Colors.accent)
                    .foregroundStyle(DesignSystem.Colors.background)
                    .clipShape(Capsule())
                    .glassEffect(.regular.interactive(), in: .capsule)
            } else {
                content
                    .background(DesignSystem.Colors.greyLight)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .clipShape(Capsule())
            }
        } else {
            content
                .background(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.greyLight)
                .foregroundStyle(isSelected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                .clipShape(Capsule())
        }
    }
}
