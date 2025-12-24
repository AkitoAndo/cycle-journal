//
//  TaskGroupDrawer.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/12/10.
//

import SwiftUI

/// タスクグループを表示するサイドドロワー
///
/// 左から飛び出すメニューで、グループ一覧とグループ管理機能を提供
struct TaskGroupDrawer: View {
    @ObservedObject var vm: TaskViewModel
    @Binding var isPresented: Bool
    @State private var showGroupManagement = false

    var body: some View {
        ZStack(alignment: .leading) {
            // 背景オーバーレイ
            if isPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }
            }

            // ドロワーメニュー
            if isPresented {
                drawerContent
                    .transition(.move(edge: .leading))
            }
        }
        .sheet(isPresented: $showGroupManagement) {
            TaskGroupManagementView(vm: vm)
        }
    }

    private var drawerContent: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Text("グループ")
                    .font(.system(size: DesignSystem.FontSize.title2, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Spacer()

                Button(action: {
                    showGroupManagement = true
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: DesignSystem.FontSize.title3))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.xl)
            .padding(.bottom, DesignSystem.Spacing.md)

            Divider()
                .background(DesignSystem.Colors.grey)

            // グループ一覧
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    // 全てのタスク
                    groupRow(
                        icon: "tray.fill",
                        name: "すべて",
                        count: vm.tasks.count,
                        isSelected: vm.selectedGroupId == nil,
                        action: {
                            vm.selectGroup(nil)
                            withAnimation {
                                isPresented = false
                            }
                        }
                    )

                    // 各グループ
                    ForEach(vm.sortedGroups) { group in
                        let taskCount = vm.tasks.filter { $0.groupId == group.id }.count
                        groupRow(
                            icon: "folder.fill",
                            name: group.name,
                            count: taskCount,
                            isSelected: vm.selectedGroupId == group.id,
                            colorHex: group.colorHex,
                            action: {
                                vm.selectGroup(group.id)
                                withAnimation {
                                    isPresented = false
                                }
                            }
                        )
                    }
                }
                .padding(.top, DesignSystem.Spacing.md)
            }

            Spacer()
        }
        .frame(width: 280)
        .background(DesignSystem.Colors.background)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 2, y: 0)
    }

    private func groupRow(
        icon: String,
        name: String,
        count: Int,
        isSelected: Bool,
        colorHex: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.FontSize.body))
                    .foregroundStyle(
                        colorHex != nil ? Color(hex: colorHex!) : DesignSystem.Colors.accent
                    )
                    .frame(width: 24)

                Text(name)
                    .font(.system(size: DesignSystem.FontSize.body))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Spacer()

                Text("\(count)")
                    .font(.system(size: DesignSystem.FontSize.caption))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(
                isSelected ? DesignSystem.Colors.surface : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Extension

extension Color {
    /// 16進数カラーコードからColorを生成
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
