//
//  RecordsView.swift
//  Cycle
//
//  「記録」タブ（U-04 実装単位2）。日付を選んで、その日の「日記」と「一歩」を1画面で見る・書く・直す。
//  - 大きなタイトル＝選んだ日（タップで月カレンダー）、右上「…」にメニュー
//  - 1週間の帯（横スワイプで週を切り替え）
//  - 「日記」「一歩」の2つのリスト（iOS 17 の inset grouped）。右下の＋は日記を書く
//  日記一覧（JournalListView）とタスク一覧（TaskListView）にあった機能はすべてここから使える。
//

import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var journalViewModel: JournalViewModel
    @EnvironmentObject private var taskViewModel: TaskViewModel
    @Environment(\.cycleTabIsActive) private var cycleTabIsActive

    /// 選択中の日付と、その週のオフセット（日記・タスクの ViewModel にも同期する）
    @State private var selectedDate = Date()
    @State private var weekOffset = 0

    // 日記
    @State private var showingNewEntry = false
    @State private var editingEntry: JournalEntry?
    @State private var quotingEntry: JournalEntry?
    @State private var chainEntry: JournalEntry?
    @State private var showingTagManagement = false
    @State private var showingDeletedEntries = false

    // 一歩
    @State private var showingNewTask = false
    @State private var editingTask: TaskItem?
    @State private var previewingTask: TaskItem?
    @State private var isReorderMode = false
    @State private var showingTaskSearch = false
    @State private var showingDeletedTasks = false
    @State private var showingTemplates = false
    /// チェック（完了）直後に事後情報フォームを出す対象タスク
    @State private var postActionTask: TaskItem?
    /// マイページの「完了時に事後情報を記入」設定
    @AppStorage(UserDataScope.scopedDefaultsKey("isPostActionPromptEnabled"))
    private var isPostActionPromptEnabled = true

    // 共通
    @State private var showingDatePicker = false

    private var calendar: Calendar { .current }

    // MARK: - 選択日のデータ

    private var entries: [JournalEntry] {
        journalViewModel.entries
            .filter { $0.deletedAt == nil && calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date > $1.date }
    }

    private var incompleteTasks: [TaskItem] { taskViewModel.incompleteTasks(on: selectedDate) }
    private var completedTasks: [TaskItem] { taskViewModel.completedTasks(on: selectedDate) }
    private var archivedCompletedTasks: [TaskItem] { taskViewModel.archivedCompletedTasks(on: selectedDate) }

    private var hasAnyStep: Bool {
        !incompleteTasks.isEmpty || !completedTasks.isEmpty || !archivedCompletedTasks.isEmpty
    }

    private func hasRecord(on date: Date) -> Bool {
        journalViewModel.hasRecord(on: date) || taskViewModel.hasRecord(on: date)
    }

    /// 月カレンダーのドット用（日記かタスクがある日）
    private var recordedDays: Set<DateComponents> {
        var days = taskViewModel.recordedDays
        for entry in journalViewModel.entries where entry.deletedAt == nil {
            days.insert(calendar.dateComponents([.year, .month, .day], from: entry.date))
        }
        return days
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.top, DesignSystem.Spacing.sm)
            RecordsWeekStrip(selectedDate: $selectedDate, weekOffset: $weekOffset, hasRecord: hasRecord)
                .padding(.top, DesignSystem.Spacing.sm)

            NetworkStatusBanner()
            // 開発ビルドで API をバイパス中（debugAuthBypass）は同期が意図的に
            // 遮断され .offline になるため、その場合はバナーを出さない
            if !APIClient.debugAuthBypass, let error = taskViewModel.lastSyncError, taskViewModel.syncError != nil {
                ErrorBannerView(
                    message: error.errorDescription ?? "同期エラー",
                    isRetryable: error.isRetryable,
                    onRetry: {
                        taskViewModel.clearSyncError()
                        Task { await taskViewModel.fetchServerTasks(force: true) }
                    },
                    onDismiss: { taskViewModel.clearSyncError() }
                )
            }

            recordsList
        }
        .background(DesignSystem.Colors.backgroundGradient)
        .navigationBarHidden(true)
        .overlay(alignment: .bottomTrailing) {
            FloatingActionButton(icon: "plus", accessibilityIdentifier: "journal_fab_plus") {
                showingNewEntry = true
            }
            .padding(.trailing, DesignSystem.Spacing.xxl)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .onAppear { syncDate(selectedDate) }
        .onChange(of: selectedDate) { _, date in syncDate(date) }
        // 検索結果などから ViewModel 側の日付が変わったら、こちらも合わせる
        .onChange(of: journalViewModel.selectedDate) { _, date in adopt(date) }
        .onChange(of: taskViewModel.selectedDate) { _, date in adopt(date) }
        .task(id: cycleTabIsActive) {
            guard cycleTabIsActive else { return }
            await taskViewModel.fetchServerTasks()
        }
        .modifier(RecordsSheets(
            journalViewModel: journalViewModel,
            taskViewModel: taskViewModel,
            selectedDate: $selectedDate,
            recordedDays: recordedDays,
            showingNewEntry: $showingNewEntry,
            editingEntry: $editingEntry,
            quotingEntry: $quotingEntry,
            chainEntry: $chainEntry,
            showingTagManagement: $showingTagManagement,
            showingDeletedEntries: $showingDeletedEntries,
            showingNewTask: $showingNewTask,
            editingTask: $editingTask,
            previewingTask: $previewingTask,
            showingTaskSearch: $showingTaskSearch,
            showingDeletedTasks: $showingDeletedTasks,
            showingTemplates: $showingTemplates,
            postActionTask: $postActionTask,
            showingDatePicker: $showingDatePicker,
            onPickDate: jump
        ))
    }

    // MARK: - 日付の同期

    private func syncDate(_ date: Date) {
        if !calendar.isDate(journalViewModel.selectedDate, inSameDayAs: date) {
            journalViewModel.jumpToDate(date)
        }
        if !calendar.isDate(taskViewModel.selectedDate, inSameDayAs: date) {
            taskViewModel.jumpToDate(date)
        }
    }

    private func adopt(_ date: Date) {
        guard !calendar.isDate(date, inSameDayAs: selectedDate) else { return }
        jump(to: date)
    }

    private func jump(to date: Date) {
        withAnimation(DesignSystem.Timing.bouncySpring) {
            selectedDate = date
            weekOffset = WeekNavigation.weekOffset(for: date)
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Button(action: { showingDatePicker = true }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.month().day().locale(Locale(identifier: "ja_JP"))))
                        .font(.largeTitle.bold())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(weekdayText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("日付を選ぶ")
            .accessibilityIdentifier("records_date_title")

            Spacer()
            menuButton
        }
    }

    /// 「土曜日」。今日なら「今日・土曜日」
    private var weekdayText: String {
        let weekday = selectedDate.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "ja_JP")))
        return calendar.isDateInToday(selectedDate) ? "今日・\(weekday)" : weekday
    }

    private var menuButton: some View {
        Menu {
            if !calendar.isDateInToday(selectedDate) {
                Button(action: { jump(to: Date()) }) {
                    Label("今日に戻る", systemImage: "arrow.uturn.backward")
                }
            }
            Button(action: { showingDatePicker = true }) {
                Label("日付選択", systemImage: "calendar")
            }
            Divider()
            Button(action: { journalViewModel.isSearching = true }) {
                Label("日記を検索", systemImage: "magnifyingglass")
            }
            Button(action: { showingTagManagement = true }) {
                Label("タグ管理", systemImage: "tag")
            }
            Button(action: { showingDeletedEntries = true }) {
                Label("最近削除した日記", systemImage: "trash")
            }
            Divider()
            Button(action: { showingTaskSearch = true }) {
                Label("一歩を検索", systemImage: "magnifyingglass")
            }
            Button(action: {
                withAnimation { isReorderMode.toggle() }
            }) {
                Label(
                    isReorderMode ? "並び替え完了" : "一歩を並び替え",
                    systemImage: isReorderMode ? "checkmark" : "arrow.up.arrow.down"
                )
            }
            Button(action: { showingTemplates = true }) {
                Label("テンプレート管理", systemImage: "square.on.square")
            }
            Button(action: { showingDeletedTasks = true }) {
                Label("最近削除した一歩", systemImage: "trash")
            }
        } label: {
            Image(systemName: isReorderMode ? "checkmark.circle" : "ellipsis.circle")
                .font(.system(size: 22))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("メニュー")
        .accessibilityIdentifier("records_menu")
    }

    // MARK: - リスト

    private var recordsList: some View {
        List {
            journalSection
            stepsSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
        // 末尾の行が右下の＋ボタンとタブバーのロゴに隠れないよう余白を空ける
        .contentMargins(.bottom, 56 + DesignSystem.Spacing.xxl * 2, for: .scrollContent)
        .animation(DesignSystem.Timing.spring, value: entries.map(\.id))
        .animation(DesignSystem.Timing.spring, value: incompleteTasks.map(\.id) + completedTasks.map(\.id))
        .refreshable {
            await taskViewModel.fetchServerTasks(force: true)
        }
    }

    private var journalSection: some View {
        Section {
            if entries.isEmpty {
                Text("この日の日記はありません")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .listRowBackground(DesignSystem.Colors.surface)
            } else {
                ForEach(entries) { entry in
                    RecordJournalRow(
                        entry: entry,
                        quoteCount: journalViewModel.quoteCount(of: entry),
                        onEdit: { editingEntry = entry },
                        onDelete: { journalViewModel.deleteEntry(entry) },
                        onQuote: { quotingEntry = entry },
                        onShowQuoteChain: { chainEntry = entry }
                    )
                    .listRowBackground(DesignSystem.Colors.surface)
                    .deleteDisabled(true)
                    .moveDisabled(true)
                }
            }
        } header: {
            RecordSectionHeader(title: "日記")
        }
    }

    private var stepsSection: some View {
        Section {
            ForEach(incompleteTasks) { task in
                stepRow(task)
                    .deleteDisabled(true)
                    .moveDisabled(!isReorderMode)
            }
            .onMove { source, destination in
                if isReorderMode {
                    taskViewModel.moveIncompleteTasks(on: selectedDate, from: source, to: destination)
                }
            }

            ForEach(completedTasks) { task in
                stepRow(task)
                    .deleteDisabled(true)
                    .moveDisabled(true)
            }

            ForEach(archivedCompletedTasks) { task in
                RecordStepRow(
                    task: task,
                    isReorderMode: isReorderMode,
                    canToggle: false,
                    onToggleCompletion: {},
                    onEdit: { editingTask = task },
                    onDelete: { taskViewModel.deleteArchivedTask(task) },
                    onPreview: { previewingTask = task }
                )
                .listRowBackground(DesignSystem.Colors.surface)
                .deleteDisabled(true)
                .moveDisabled(true)
            }

            if !isReorderMode {
                // リマインダーAppと同じく、リストの最後から追加できる
                Button(action: { showingNewTask = true }) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .frame(width: 28, height: 28)
                        Text(hasAnyStep ? "一歩を追加" : "この日の一歩を追加")
                            .font(.body)
                            .foregroundStyle(DesignSystem.Colors.accent)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(DesignSystem.Colors.surface)
                .deleteDisabled(true)
                .moveDisabled(true)
                .accessibilityIdentifier("task_fab_plus")
            }
        } header: {
            RecordSectionHeader(title: "一歩")
        }
    }

    private func stepRow(_ task: TaskItem) -> some View {
        RecordStepRow(
            task: task,
            isReorderMode: isReorderMode,
            onToggleCompletion: {
                let wasCompleted = task.isCompleted
                withAnimation(DesignSystem.Timing.spring) {
                    taskViewModel.toggleCompletion(task)
                }
                // 未完了 → 完了のチェック時のみ、設定がオンなら事後情報フォームを出す
                if !wasCompleted && isPostActionPromptEnabled {
                    postActionTask = task
                }
            },
            onEdit: { editingTask = task },
            onDelete: { taskViewModel.deleteTask(task) },
            onPreview: { previewingTask = task }
        )
        .listRowBackground(DesignSystem.Colors.surface)
    }
}

// MARK: - シートとアラート（本体を短く保つために分離）

private struct RecordsSheets: ViewModifier {
    @ObservedObject var journalViewModel: JournalViewModel
    @ObservedObject var taskViewModel: TaskViewModel
    @Binding var selectedDate: Date
    let recordedDays: Set<DateComponents>

    @Binding var showingNewEntry: Bool
    @Binding var editingEntry: JournalEntry?
    @Binding var quotingEntry: JournalEntry?
    @Binding var chainEntry: JournalEntry?
    @Binding var showingTagManagement: Bool
    @Binding var showingDeletedEntries: Bool

    @Binding var showingNewTask: Bool
    @Binding var editingTask: TaskItem?
    @Binding var previewingTask: TaskItem?
    @Binding var showingTaskSearch: Bool
    @Binding var showingDeletedTasks: Bool
    @Binding var showingTemplates: Bool
    @Binding var postActionTask: TaskItem?

    @Binding var showingDatePicker: Bool
    let onPickDate: (Date) -> Void

    func body(content: Content) -> some View {
        content
            // 日記
            .sheet(isPresented: $showingNewEntry) {
                JournalNewEntryView(vm: journalViewModel)
                    .softSheet()
            }
            .sheet(item: $editingEntry) { entry in
                JournalEditView(vm: journalViewModel, entry: entry)
                    .softSheet()
            }
            .sheet(item: $quotingEntry) { entry in
                JournalNewEntryView(vm: journalViewModel, quotedEntry: entry)
                    .softSheet()
            }
            .sheet(item: $chainEntry) { entry in
                JournalQuoteChainView(vm: journalViewModel, entry: entry)
                    .softSheet()
            }
            .sheet(isPresented: $journalViewModel.isSearching) {
                JournalSearchView(vm: journalViewModel)
                    .softSheet()
            }
            .sheet(isPresented: $showingTagManagement) {
                TagManagementView(vm: journalViewModel)
                    .softSheet()
            }
            .sheet(isPresented: $showingDeletedEntries) {
                JournalDeletedView(vm: journalViewModel)
                    .softSheet()
            }
            // 一歩
            .sheet(isPresented: $showingNewTask) {
                TaskNewEntryView(vm: taskViewModel, date: selectedDate)
                    .softSheet()
            }
            .sheet(item: $editingTask) { task in
                TaskEditView(vm: taskViewModel, task: task)
                    .softSheet()
            }
            .sheet(item: $previewingTask) { task in
                TaskPreviewView(task: task)
                    .softSheet()
            }
            .sheet(isPresented: $showingTaskSearch) {
                TaskSearchView(vm: taskViewModel)
                    .softSheet()
            }
            .sheet(isPresented: $showingDeletedTasks) {
                TaskDeletedView(vm: taskViewModel)
                    .softSheet()
            }
            .sheet(isPresented: $showingTemplates) {
                TaskTemplateManagementView(vm: taskViewModel)
                    .softSheet()
            }
            .sheet(item: $postActionTask) { task in
                TaskPostActionEntryView(vm: taskViewModel, task: task)
                    .softSheet()
            }
            // 共通
            .sheet(isPresented: $showingDatePicker) {
                CycleCalendarSheet(
                    selectedDate: $selectedDate,
                    recordedDays: recordedDays,
                    onSelect: { date in
                        onPickDate(date)
                        showingDatePicker = false
                    }
                )
                .presentationDetents([.medium])
                .presentationBackground(DesignSystem.Colors.background)
            }
            .alert(
                "変更を保存できませんでした",
                isPresented: Binding(
                    get: { taskViewModel.persistenceError != nil },
                    set: { if !$0 { taskViewModel.clearPersistenceError() } }
                )
            ) {
                Button("OK") { taskViewModel.clearPersistenceError() }
            } message: {
                Text(taskViewModel.persistenceError ?? "")
            }
            .alert("再ログインが必要です", isPresented: $taskViewModel.showReauthPrompt) {
                Button("OK") { taskViewModel.showReauthPrompt = false }
            } message: {
                Text("セッションの有効期限が切れました。マイページからサインインし直してください。")
            }
    }
}

#Preview {
    NavigationStack { RecordsView() }
        .environmentObject(JournalViewModel())
        .environmentObject(TaskViewModel())
        .environmentObject(CoachStore())
}
