//
//  TaskListView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/15.
//

import SwiftUI

/// タスク管理のメインビュー
/// ジャーナルと同じく週カレンダーで日付を選び、その日のタスクを表示・追加・編集・並び替えする
struct TaskListView: View {
    // MARK: - Properties

    @EnvironmentObject var vm: TaskViewModel
    @Environment(\.cycleTabIsActive) private var cycleTabIsActive
    @State private var showNewTask = false
    @State private var editingTask: TaskItem?
    @State private var previewingTask: TaskItem?
    @State private var isReorderMode = false
    @State private var showSearch = false
    @State private var showDatePicker = false
    @State private var showDeleted = false
    @State private var showTemplates = false

    /// チェック（完了）直後に事後情報フォームを出す対象タスク
    @State private var postActionTask: TaskItem?
    /// マイページの「完了時に事後情報を記入」設定
    @AppStorage(UserDataScope.scopedDefaultsKey("isPostActionPromptEnabled"))
    private var isPostActionPromptEnabled = true

    // MARK: - Body

    var body: some View {
        content
            .navigationBarHidden(true)
            .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
            .task(id: cycleTabIsActive) {
                guard cycleTabIsActive else { return }
                await vm.fetchServerTasks()
            }
            .sheet(isPresented: $showNewTask) {
                TaskNewEntryView(vm: vm, date: vm.selectedDate)
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
            .sheet(isPresented: $showSearch) {
                TaskSearchView(vm: vm)
                    .softSheet()
            }
            .sheet(isPresented: $showDatePicker) {
                CycleCalendarSheet(
                    selectedDate: Binding(
                        get: { vm.selectedDate },
                        set: { vm.selectedDate = $0 }
                    ),
                    recordedDays: vm.recordedDays,
                    onSelect: { date in
                        vm.jumpToDate(date)
                        showDatePicker = false
                    }
                )
                .presentationDetents([.medium])
                .presentationBackground(DesignSystem.Colors.background)
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
            .alert(
                "変更を保存できませんでした",
                isPresented: Binding(
                    get: { vm.persistenceError != nil },
                    set: { if !$0 { vm.clearPersistenceError() } }
                )
            ) {
                Button("OK") {
                    vm.clearPersistenceError()
                }
            } message: {
                Text(vm.persistenceError ?? "")
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

            WeekCalendarView(vm: vm)
                .padding(.bottom, DesignSystem.Spacing.sm)

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
            selectedDate: vm.selectedDate,
            onToday: {
                withAnimation(DesignSystem.Timing.bouncySpring) {
                    vm.jumpToDate(Date())
                }
            },
            isReorderMode: isReorderMode,
            onToggleReorderMode: {
                withAnimation {
                    isReorderMode.toggle()
                }
            },
            onShowSearch: {
                showSearch = true
            },
            onShowDatePicker: {
                showDatePicker = true
            },
            onShowTemplates: {
                showTemplates = true
            },
            onShowDeleted: {
                showDeleted = true
            }
        )
    }

    @ViewBuilder
    private var taskListOrEmptyState: some View {
        // 選択日に表示するもの（未完了・完了）が無ければ空表示。
        let date = vm.selectedDate
        let incomplete = vm.incompleteTasks(on: date)
        let completed = vm.completedTasks(on: date)
        let archivedCompleted = vm.archivedCompletedTasks(on: date)

        if incomplete.isEmpty && completed.isEmpty && archivedCompleted.isEmpty {
            EmptyStateView(
                icon: "checkmark.circle",
                title: "この日のタスクはありません",
                titleColor: DesignSystem.Colors.textTertiary
            )
            .frame(maxHeight: .infinity)
        } else {
            ZStack(alignment: .top) {
                TaskList(
                    incompleteTasks: incomplete,
                    completedTasks: completed,
                    archivedCompletedTasks: archivedCompleted,
                    isReorderMode: isReorderMode,
                    onMove: { source, destination in
                        vm.moveIncompleteTasks(on: date, from: source, to: destination)
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
                    onDeleteArchived: { task in
                        vm.deleteArchivedTask(task)
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
        .padding(.trailing, DesignSystem.Spacing.xxl)
        .padding(.bottom, DesignSystem.Spacing.xxl)
    }
}
