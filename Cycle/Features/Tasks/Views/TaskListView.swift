//
//  TaskListView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/15.
//

import SwiftUI

struct TaskListView: View {
    @StateObject private var vm = TaskViewModel()
    @State private var showNewTask = false
    @State private var editingTask: TaskItem?
    @State private var showDrawer = false

    var body: some View {
        ZStack(alignment: .leading) {
            mainContent

            // ドロワーメニュー
            TaskGroupDrawer(vm: vm, isPresented: $showDrawer)
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Tasks list
                if vm.tasks.isEmpty {
                    emptyStateView
                } else {
                    List {
                        if !vm.incompleteTasks.isEmpty {
                            Section {
                                ForEach(vm.incompleteTasks) { task in
                                    taskRow(task)
                                }
                            } header: {
                                Text("未完了")
                                    .font(.system(size: DesignSystem.FontSize.caption))
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                        }

                        if !vm.completedTasks.isEmpty {
                            Section {
                                ForEach(vm.completedTasks) { task in
                                    taskRow(task)
                                }
                            } header: {
                                Text("完了")
                                    .font(.system(size: DesignSystem.FontSize.caption))
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(DesignSystem.Colors.background)
                }
            }
            .background(DesignSystem.Colors.background)

            // 新規作成ボタン（オーバーレイ）
            FloatingActionButton(icon: "plus") {
                showNewTask = true
            }
            .padding(.trailing, DesignSystem.Spacing.xl + 2)
            .padding(.bottom, DesignSystem.Spacing.xl - 2)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    withAnimation {
                        showDrawer.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: DesignSystem.FontSize.title3))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showNewTask) {
            TaskNewEntryView(vm: vm)
        }
        .sheet(item: $editingTask) { task in
            TaskEditView(vm: vm, task: task)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("タスクがまだありません")
                    .font(.system(size: DesignSystem.FontSize.headline))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("+ボタンから新しいタスクを追加できます")
                    .font(.system(size: DesignSystem.FontSize.body))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func taskRow(_ task: TaskItem) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(action: {
                vm.toggleCompletion(task)
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: DesignSystem.FontSize.title3))
                    .foregroundStyle(task.isCompleted ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
            }

            Text(task.title)
                .font(.system(size: DesignSystem.FontSize.body))
                .foregroundStyle(task.isCompleted ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)

            Spacer()
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous)
                .stroke(DesignSystem.Colors.grey.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(
            color: DesignSystem.Colors.brownDark.opacity(0.08),
            radius: 4,
            x: 0,
            y: 2
        )
        .listRowInsets(
            EdgeInsets(
                top: DesignSystem.Spacing.xs,
                leading: DesignSystem.Spacing.lg,
                bottom: DesignSystem.Spacing.xs,
                trailing: DesignSystem.Spacing.lg
            )
        )
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                vm.deleteTask(task)
            } label: {
                Label("削除", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }

            Button {
                editingTask = task
            } label: {
                Label("編集", systemImage: "pencil")
                    .labelStyle(.iconOnly)
            }
            .tint(DesignSystem.Colors.accent)
        }
    }

}
