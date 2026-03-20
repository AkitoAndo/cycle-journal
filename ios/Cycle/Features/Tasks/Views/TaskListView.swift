//
//  TaskListView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/15.
//

import SwiftUI

/// タスク管理のメインビュー
/// グループ別のタスク表示、追加、編集、削除、並び替えを提供
struct TaskListView: View {
    // MARK: - Properties

    @StateObject private var vm = TaskViewModel()
    @State private var showNewTask = false
    @State private var editingTask: TaskItem?
    @State private var previewingTask: TaskItem?
    @State private var isReorderMode = false
    @State private var showArchive = false
    @State private var showDeleted = false

    // MARK: - Body

    var body: some View {
        content
            .navigationBarHidden(true)
            .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
            .task {
                await vm.fetchServerTasks()
            }
            .sheet(isPresented: $showNewTask) {
                TaskNewEntryView(vm: vm)
            }
            .sheet(item: $editingTask) { task in
                TaskEditView(vm: vm, task: task)
            }
            .sheet(item: $previewingTask) { task in
                TaskPreviewView(task: task)
            }
            .sheet(isPresented: $showArchive) {
                TaskArchiveView(vm: vm)
            }
            .sheet(isPresented: $showDeleted) {
                TaskDeletedView(vm: vm)
            }
    }

    // MARK: - Content

    private var content: some View {
        ZStack(alignment: .bottomTrailing) {
            mainContent
            floatingActionButton
        }
    }

    private var mainContent: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            header
            taskListOrEmptyState
        }
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Components

    private var header: some View {
        TaskHeader(
            isReorderMode: isReorderMode,
            onToggleReorderMode: {
                withAnimation {
                    isReorderMode.toggle()
                }
            },
            onShowArchive: {
                showArchive = true
            },
            onShowDeleted: {
                showDeleted = true
            }
        )
    }

    @ViewBuilder
    private var taskListOrEmptyState: some View {
        if vm.tasks.isEmpty {
            EmptyStateView(icon: "checkmark.circle", title: "タスクがまだありません", subtitle: "＋ボタンから新しいタスクを追加しましょう")
        } else {
            TaskList(
                incompleteTasks: vm.incompleteTasks,
                completedTasks: vm.completedTasks,
                isReorderMode: isReorderMode,
                onMove: { source, destination in
                    vm.moveIncompleteTasks(from: source, to: destination)
                },
                onToggleCompletion: { task in
                    vm.toggleCompletion(task)
                },
                onEdit: { task in
                    editingTask = task
                },
                onDelete: { task in
                    vm.deleteTask(task)
                },
                onPreview: { task in
                    previewingTask = task
                },
                onArchive: { task in
                    vm.archiveTask(task)
                }
            )
        }
    }

    private var floatingActionButton: some View {
        FloatingActionButton(icon: "plus") {
            showNewTask = true
        }
        .padding(.trailing, DesignSystem.Spacing.xl + 2)
        .padding(.bottom, DesignSystem.Spacing.xl - 2)
    }
}
