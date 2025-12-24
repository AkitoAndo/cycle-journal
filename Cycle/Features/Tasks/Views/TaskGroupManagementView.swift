//
//  TaskGroupManagementView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/12/10.
//

import SwiftUI

/// タスクグループ管理画面
///
/// グループの追加、編集、削除を行う
struct TaskGroupManagementView: View {
    @ObservedObject var vm: TaskViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newGroupName: String = ""
    @State private var editingGroup: TaskGroup?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 新規グループ入力エリア
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "folder")
                        .font(.system(size: DesignSystem.FontSize.body))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    TextField("新しいグループを追加", text: $newGroupName)
                        .textFieldStyle(.plain)
                        .font(.system(size: DesignSystem.FontSize.body))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .focused($isInputFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addGroup()
                        }
                        .tint(DesignSystem.Colors.accent)

                    if !newGroupName.isEmpty {
                        Button(action: addGroup) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: DesignSystem.FontSize.title3))
                                .foregroundStyle(DesignSystem.Colors.accent)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.md)

                Divider()
                    .background(DesignSystem.Colors.grey)
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                // グループ一覧
                if vm.groups.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(vm.sortedGroups) { group in
                                groupRow(group)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                    }
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("グループ管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $editingGroup) { group in
            GroupEditSheet(vm: vm, group: group)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("グループがまだありません")
                    .font(.system(size: DesignSystem.FontSize.headline))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("上の入力欄から新しいグループを追加できます")
                    .font(.system(size: DesignSystem.FontSize.body))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func groupRow(_ group: TaskGroup) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(group.name)
                    .font(.system(size: DesignSystem.FontSize.body))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                let taskCount = vm.tasks.filter { $0.groupId == group.id }.count
                Text("\(taskCount)個のタスク")
                    .font(.system(size: DesignSystem.FontSize.caption))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            Button(action: {
                editingGroup = group
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: DesignSystem.FontSize.body))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(.trailing, DesignSystem.Spacing.sm)

            Button(action: {
                deleteGroup(group)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: DesignSystem.FontSize.body))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
    }

    private func addGroup() {
        vm.addGroup(name: newGroupName)
        newGroupName = ""
        isInputFocused = false
    }

    private func deleteGroup(_ group: TaskGroup) {
        vm.deleteGroup(group)
    }
}

// MARK: - Group Edit Sheet

/// グループ編集シート
private struct GroupEditSheet: View {
    @ObservedObject var vm: TaskViewModel
    let group: TaskGroup
    @Environment(\.dismiss) private var dismiss
    @State private var editName: String
    @State private var editColor: String

    init(vm: TaskViewModel, group: TaskGroup) {
        self.vm = vm
        self.group = group
        _editName = State(initialValue: group.name)
        _editColor = State(initialValue: group.colorHex ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("グループ名") {
                    TextField("グループ名", text: $editName)
                        .tint(DesignSystem.Colors.accent)
                }

                Section("カラー（オプション）") {
                    TextField("例: #FF5733", text: $editColor)
                        .tint(DesignSystem.Colors.accent)
                }
            }
            .navigationTitle("グループを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        let colorHex = editColor.isEmpty ? nil : editColor
        vm.updateGroup(group, newName: editName, newColorHex: colorHex)
        dismiss()
    }
}
