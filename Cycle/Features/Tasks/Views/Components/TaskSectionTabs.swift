//
//  TaskSectionTabs.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2026/02/07.
//

import SwiftUI

/// タスク入力セクション切り替えタブ
/// 基本情報と詳細情報を切り替え
struct TaskSectionTabs: View {
    enum Section: String, CaseIterable, Identifiable {
        case basic = "基本情報"
        case detail = "事前情報"
        case postAction = "事後情報"

        var id: String { rawValue }
    }

    let selectedSection: Section
    let onSelectSection: (Section) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Section.allCases) { section in
                    SectionTabButton(
                        section: section,
                        isSelected: selectedSection == section,
                        onTap: { onSelectSection(section) }
                    )
                }
            }

            // アンダーライン
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(selectedSection == .basic ? DesignSystem.Colors.accent : DesignSystem.Colors.grey)
                        .frame(width: geometry.size.width / 3, height: selectedSection == .basic ? 2 : 0.5)

                    Rectangle()
                        .fill(selectedSection == .detail ? DesignSystem.Colors.accent : DesignSystem.Colors.grey)
                        .frame(width: geometry.size.width / 3, height: selectedSection == .detail ? 2 : 0.5)

                    Rectangle()
                        .fill(selectedSection == .postAction ? DesignSystem.Colors.accent : DesignSystem.Colors.grey)
                        .frame(width: geometry.size.width / 3, height: selectedSection == .postAction ? 2 : 0.5)
                }
            }
            .frame(height: 2)
        }
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Section Tab Button

/// 個別のセクションタブボタン
private struct SectionTabButton: View {
    let section: TaskSectionTabs.Section
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(section.rawValue)
                .font(.system(size: DesignSystem.FontSize.body, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
        }
    }
}
