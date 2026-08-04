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

    @EnvironmentObject var vm: TaskViewModel
    @State private var showNewTask = false
    @State private var editingTask: TaskItem?
    @State private var previewingTask: TaskItem?
    @State private var isReorderMode = false
    @State private var showArchive = false
    @State private var showDeleted = false
    @State private var showTemplates = false

    /// チェック（完了）直後に事後情報フォームを出す対象タスク
    @State private var postActionTask: TaskItem?
    /// マイページの「完了時に事後情報を記入」設定
    @AppStorage("isPostActionPromptEnabled") private var isPostActionPromptEnabled = true

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
                    .softSheet()
            }
            .sheet(item: $editingTask) { task in
                TaskEditView(vm: vm, task: task)
                    .softSheet()
            }
            .sheet(item: $previewingTask) { task in
                TaskPreviewView(task: task)
                    .softSheet()
            }
            .sheet(isPresented: $showArchive) {
                TaskArchiveView(vm: vm)
                    .softSheet()
            }
            .sheet(isPresented: $showDeleted) {
                TaskDeletedView(vm: vm)
                    .softSheet()
            }
            .sheet(isPresented: $showTemplates) {
                TaskTemplateManagementView(vm: vm)
                    .softSheet()
            }
            .sheet(item: $postActionTask) { task in
                TaskPostActionEntryView(vm: vm, task: task)
                    .softSheet()
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
        VStack(spacing: 0) {
            header

            NetworkStatusBanner()

            // 開発ビルドで API をバイパス中（debugAuthBypass）は同期が意図的に
            // 遮断され .offline になるため、その場合はバナーを出さない
            if !APIClient.debugAuthBypass, let error = vm.lastSyncError, vm.syncError != nil {
                ErrorBannerView(
                    message: error.errorDescription ?? "同期エラー",
                    isRetryable: error.isRetryable,
                    onRetry: {
                        vm.clearSyncError()
                        Task { await vm.fetchServerTasks(force: true) }
                    },
                    onDismiss: { vm.clearSyncError() }
                )
            }

            taskListOrEmptyState
        }
        .background(DesignSystem.Colors.backgroundGradient)
        .alert("再ログインが必要です", isPresented: $vm.showReauthPrompt) {
            Button("OK") {
                vm.showReauthPrompt = false
            }
        } message: {
            Text("セッションの有効期限が切れました。設定画面からサインインし直してください。")
        }
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
            },
            onShowTemplates: {
                showTemplates = true
            }
        )
    }

    @ViewBuilder
    private var taskListOrEmptyState: some View {
        // 表示対象（未完了+完了）が無ければ空表示。
        // vm.tasks はソフトデリート済みも含むため、それで判定すると
        // 全削除後に「空でも一覧でもない」ブランクになるので使わない。
        if vm.incompleteTasks.isEmpty && vm.completedTasks.isEmpty {
            EmptyStateView(
                icon: "checkmark.circle",
                title: "タスクはありません",
                titleColor: DesignSystem.Colors.textTertiary
            )
        } else {
            ZStack(alignment: .top) {
                TaskList(
                    incompleteTasks: vm.incompleteTasks,
                    completedTasks: vm.completedTasks,
                    isReorderMode: isReorderMode,
                    onMove: { source, destination in
                        vm.moveIncompleteTasks(from: source, to: destination)
                    },
                    onToggleCompletion: { task in
                        let wasCompleted = task.isCompleted
                        vm.toggleCompletion(task)
                        // 未完了 → 完了のチェック時のみ、設定がオンなら事後情報フォームを出す
                        if !wasCompleted && isPostActionPromptEnabled {
                            postActionTask = task
                        }
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
                .refreshable {
                    await vm.fetchServerTasks(force: true)
                }
            }
        }
    }

    private var floatingActionButton: some View {
        FloatingActionButton(icon: "plus", accessibilityIdentifier: "task_fab_plus") {
            showNewTask = true
        }
        .padding(.trailing, 40)
        .padding(.bottom, 40)
    }
}
