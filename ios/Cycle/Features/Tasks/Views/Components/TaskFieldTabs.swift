//
//  TaskFieldTabs.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2026/02/07.
//

import SwiftUI

/// タスク詳細フィールド切り替えタブ
/// 横スクロール可能なタブで、意図・完了イメージ・注意点を切り替え
struct TaskFieldTabs: View {
    enum Field: String, CaseIterable, Identifiable {
        case intent = "意図"
        case achievementVision = "完了イメージ"
        case notes = "注意点"

        var id: String { rawValue }

        var placeholder: String {
            switch self {
            case .intent: return "このタスクの目的や意図を記述"
            case .achievementVision: return "完了時の理想的な状態を記述"
            case .notes: return "注意すべき点やリスクを記述"
            }
        }
    }

    let selectedField: Field
    let onSelectField: (Field) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(Field.allCases) { field in
                    FieldTabButton(
                        field: field,
                        isSelected: selectedField == field,
                        onTap: { onSelectField(field) }
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Field Tab Button

/// 個別のフィールドタブボタン
private struct FieldTabButton: View {
    let field: TaskFieldTabs.Field
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(field.rawValue)
                .font(DesignSystem.Fonts.bodyMedium)
                .foregroundStyle(
                    isSelected
                        ? DesignSystem.Colors.background
                        : DesignSystem.Colors.textPrimary
                )
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    isSelected
                        ? DesignSystem.Colors.accent
                        : DesignSystem.Colors.surface
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            DesignSystem.Colors.grey.opacity(0.3),
                            lineWidth: isSelected ? 0 : 1
                        )
                )
        }
        .animation(DesignSystem.Timing.easing, value: isSelected)
    }
}
