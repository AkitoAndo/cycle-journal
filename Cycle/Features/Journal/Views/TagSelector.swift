//
//  TagSelector.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/29.
//

import SwiftUI

/// タグ選択用のコンポーネント
/// 利用可能なタグ一覧から複数選択可能
struct TagSelector: View {
    let availableTags: [String]
    @Binding var selectedTags: [String]

    var body: some View {
        if !availableTags.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("タグ")
                    .font(.system(size: DesignSystem.FontSize.headline, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                FlowLayout(spacing: DesignSystem.Spacing.sm) {
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

    private func toggleTag(_ tag: String) {
        withAnimation(DesignSystem.Timing.fastEasing) {
            if selectedTags.contains(tag) {
                selectedTags.removeAll { $0 == tag }
            } else {
                selectedTags.append(tag)
            }
        }

        // 触覚フィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
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
                .font(.system(size: DesignSystem.FontSize.caption))
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs + 2)
                .background(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.greyLight)
                .foregroundStyle(isSelected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
