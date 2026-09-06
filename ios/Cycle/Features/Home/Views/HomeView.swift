//
//  HomeView.swift
//  Cycle
//
//  ホーム画面（0710バージョンで新設）
//  選択中の1日の ジャーナル / セッション / タスク を3セクションで表示する。
//  - 日付ヘッダー: タップで月カレンダーを開き、日付を選ぶと3セクションを更新
//  - 各セクション: 畳み（横スクロール）/ 展開（縦全件）をトグルできる
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var journalViewModel: JournalViewModel
    @EnvironmentObject private var coachStore: CoachStore
    @EnvironmentObject private var meditationStore: MeditationStore
    @EnvironmentObject private var taskViewModel: TaskViewModel

    /// 選択中の日付（既定は今日）
    @State private var selectedDate = Date()

    /// シート表示中のセクション（ボタンタップで下から表示）
    @State private var presentedSection: HomeSectionKind?

    /// スワイプ「編集」で開くジャーナル（ジャーナル一覧と同じ JournalEditView）
    @State private var editingJournalEntry: JournalEntry?
    /// スワイプ「編集」で開くタスク（アーカイブ一覧と同じ TaskEditView）
    @State private var editingTask: TaskItem?
    /// スワイプ「プレビュー」で開くタスク
    @State private var previewingTask: TaskItem?
    /// スワイプ「チェック」で開くセッション（履歴と同じ SessionDetailView）
    @State private var viewingSession: CoachSession?
    /// セッションシート内のタブ（0: セッション / 1: 瞑想。履歴画面と同じ構成）
    @State private var sessionTab = 0

    /// アプリ独自の予定（ローカル保存）
    @StateObject private var scheduleStore = ScheduleStore()

    /// 予定の追加・編集シート（item で対象を確実に渡す）
    @State private var scheduleEditTarget: ScheduleEditTarget?
    /// 1日のタイムライン表示
    @State private var showingTimeline = false

    private var calendar: Calendar { Calendar.current }

    /// 選択日の予定
    private var dayEvents: [ScheduleEvent] {
        scheduleStore.events(on: selectedDate)
    }

    // MARK: - 選択日のデータ

    private var dayJournals: [JournalEntry] {
        // 1日の流れを上から追えるよう古い順（時系列順）で表示する
        journalViewModel.entries
            .filter { $0.deletedAt == nil && calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }

    private var daySessions: [CoachSession] {
        coachStore.sessions
            .filter { calendar.isDate($0.createdAt, inSameDayAs: selectedDate) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var dayMeditations: [MeditationLog] {
        meditationStore.logs
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date > $1.date }
    }

    private var dayTasks: [TaskItem] {
        taskViewModel.homeTasks(on: selectedDate)
    }

    /// カレンダーに記録ドットを出す日（ジャーナル/セッション/タスクのいずれかがある日）
    private var recordedDays: Set<DateComponents> {
        var days = Set<DateComponents>()
        let add: (Date) -> Void = { date in
            days.insert(self.calendar.dateComponents([.year, .month, .day], from: date))
        }
        journalViewModel.entries.filter { $0.deletedAt == nil }.forEach { add($0.date) }
        coachStore.sessions.forEach { add($0.createdAt) }
        meditationStore.logs.forEach { add($0.date) }
        taskViewModel.completedTasks.compactMap(\.completedAt).forEach { add($0) }
        taskViewModel.archives.filter { !$0.completedTasks.isEmpty }.forEach { add($0.date) }
        if !taskViewModel.incompleteTasks.isEmpty { add(Date()) }
        scheduleStore.events.forEach { add($0.startDate) }
        return days
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 月カレンダーを常時表示する（折り畳みなし・スクロールしても固定）
            CycleCalendarView(
                selectedDate: $selectedDate,
                recordedDays: recordedDays,
                showsTodayButton: true
            )
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.background)

            // その日の予定（アプリ独自・ローカル保存）
            // 予定が少ない/無い日でもヘッダー位置が動かないよう上端に揃える
            schedulePanel
                .frame(maxHeight: .infinity, alignment: .top)

            // セクションボタン（縦長・横並び3つ。タップでシートが下から出る）
            // カレンダーの週数（5週/6週）で高さが変わっても位置がぶれないよう下端に固定
            sectionButtons
        }
        .background(DesignSystem.Colors.backgroundGradient)
        .sheet(item: $presentedSection) { kind in
            sectionSheet(kind)
        }
        .sheet(item: $scheduleEditTarget) { target in
            ScheduleEditView(
                store: scheduleStore,
                editing: target.event,
                defaultDate: selectedDate
            )
        }
    }

    // MARK: - 予定（アプリ独自）

    /// その日の予定パネル
    private var schedulePanel: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "calendar")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text("予定")
                    .font(DesignSystem.Fonts.sectionTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("\(dayEvents.count)")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(DesignSystem.Colors.accent.opacity(0.10)))
                Spacer()

                // 1日のタイムライン表示
                Button(action: { showingTimeline = true }) {
                    Image(systemName: "clock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("1日のタイムラインを表示")

                // 予定を追加
                Button(action: { scheduleEditTarget = .new }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("予定を追加")
            }

            scheduleContent
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.md)
        .sheet(isPresented: $showingTimeline) {
            DayTimelineView(store: scheduleStore, date: selectedDate)
        }
    }

    @ViewBuilder
    private var scheduleContent: some View {
        if dayEvents.isEmpty {
            Text("この日の予定はありません")
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .padding(.vertical, DesignSystem.Spacing.sm)
        } else {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(dayEvents) { event in
                        eventRow(event)
                    }
                }
            }
        }
    }

    /// 予定1件の行（タップで編集）
    private func eventRow(_ event: ScheduleEvent) -> some View {
        Button(action: { scheduleEditTarget = .edit(event) }) {
            HStack(spacing: DesignSystem.Spacing.md) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    Text(event.timeText)
                        .font(DesignSystem.Fonts.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(EventCardGlassStyle())
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
    }

    // MARK: - セクションタブ

    /// セクションの件数
    private func count(for kind: HomeSectionKind) -> Int {
        switch kind {
        case .journal: return dayJournals.count
        case .session: return daySessions.count + dayMeditations.count
        case .task: return dayTasks.count
        }
    }

    /// 縦長のセクションボタン（横並び3つ）。タップでシートを表示する
    private var sectionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ForEach(HomeSectionKind.allCases, id: \.self) { kind in
                Button(action: { presentedSection = kind }) {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: kind.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.accent)

                        Text(kind.title)
                            .font(DesignSystem.Fonts.label)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text("\(count(for: kind))")
                            .font(DesignSystem.Fonts.caption)
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(DesignSystem.Colors.accent.opacity(0.10)))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                }
                .buttonStyle(.plain)
                .modifier(SurfaceCardStyleLike())
                .accessibilityIdentifier("home_section_\(kind.title)")
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.md)
        // タブバー中央の大樹ロゴ（上に飛び出している）と重ならないよう下は広めに空ける
        .padding(.bottom, DesignSystem.Spacing.xxl + 3)
    }

    /// セクション内容のシート（下からせり上がる）
    private func sectionSheet(_ kind: HomeSectionKind) -> some View {
        VStack(spacing: 0) {
            // シートヘッダー
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: kind.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text(kind.title)
                    .font(DesignSystem.Fonts.sectionTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("\(count(for: kind))")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(DesignSystem.Colors.accent.opacity(0.10)))
                Spacer()
                Text(selectedDate.formatted(.dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP"))))
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.lg)

            // スワイプアクションを使うため List で表示する（各一覧画面と同じ構成）
            switch kind {
            case .journal:
                if dayJournals.isEmpty {
                    emptyList
                } else {
                    sheetList { journalRows }
                }
            case .session:
                // 履歴画面と同じタブ構成（セッション / 瞑想）
                sessionTabBar
                if sessionTab == 0 {
                    if daySessions.isEmpty {
                        emptyList
                    } else {
                        sheetList { sessionRows }
                    }
                } else {
                    if dayMeditations.isEmpty {
                        emptyList
                    } else {
                        sheetList { meditationRows }
                    }
                }
            case .task:
                if dayTasks.isEmpty {
                    emptyList
                } else {
                    sheetList { taskRows }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(DesignSystem.Colors.background)
        .sheet(item: $editingJournalEntry) { entry in
            JournalEditView(vm: journalViewModel, entry: entry)
                .softSheet()
        }
        .sheet(item: $editingTask) { task in
            TaskEditView(vm: taskViewModel, task: task)
        }
        .sheet(item: $previewingTask) { task in
            TaskPreviewView(task: task)
        }
        .sheet(item: $viewingSession) { session in
            SessionDetailView(session: session)
                .environmentObject(coachStore)
        }
    }

    private var emptyMessage: some View {
        Text("この日の記録はありません")
            .font(.subheadline)
            .foregroundStyle(DesignSystem.Colors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private var emptyList: some View {
        ScrollView {
            emptyMessage
                .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }

    /// シート内リストの共通スタイル
    private func sheetList<Rows: View>(@ViewBuilder rows: () -> Rows) -> some View {
        List {
            rows()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, DesignSystem.Spacing.lg, for: .scrollContent)
    }

    // MARK: - セッションシート内タブ（履歴画面と同じ構成）

    private var sessionTabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sessionTabButton(title: "セッション", tab: 0)
                sessionTabButton(title: "瞑想", tab: 1)
            }

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(sessionTab == 0 ? DesignSystem.Colors.accent : DesignSystem.Colors.grey)
                        .frame(width: geometry.size.width / 2, height: sessionTab == 0 ? 2 : 0.5)

                    Rectangle()
                        .fill(sessionTab == 1 ? DesignSystem.Colors.accent : DesignSystem.Colors.grey)
                        .frame(width: geometry.size.width / 2, height: sessionTab == 1 ? 2 : 0.5)
                }
            }
            .frame(height: 2)
        }
    }

    private func sessionTabButton(title: String, tab: Int) -> some View {
        Button(action: { sessionTab = tab }) {
            Text(title)
                .font(.system(size: DesignSystem.FontSize.body, weight: sessionTab == tab ? .semibold : .regular))
                .foregroundStyle(sessionTab == tab ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Rows

    private var journalRows: some View {
        ForEach(dayJournals) { entry in
            journalCard(entry)
                .customListRowStyle()
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        journalViewModel.deleteEntry(entry)
                    } label: {
                        Label("削除", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }

                    Button {
                        editingJournalEntry = entry
                    } label: {
                        Label("編集", systemImage: "pencil")
                            .labelStyle(.iconOnly)
                    }
                    .tint(DesignSystem.Colors.accent)
                }
        }
    }

    private var sessionRows: some View {
        ForEach(daySessions) { session in
            sessionCard(session)
                .customListRowStyle()
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        coachStore.deleteSession(session)
                    } label: {
                        Label("削除", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }

                    Button {
                        viewingSession = session
                    } label: {
                        Label("チェック", systemImage: "checkmark")
                            .labelStyle(.iconOnly)
                    }
                    .tint(DesignSystem.Colors.textSecondary)
                }
        }
    }

    /// 瞑想ログの行（履歴の瞑想タブと同じくスワイプは削除のみ）
    private var meditationRows: some View {
        ForEach(dayMeditations) { log in
            meditationCard(log)
                .customListRowStyle()
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        meditationStore.deleteLog(log)
                    } label: {
                        Label("削除", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                }
        }
    }

    private var taskRows: some View {
        ForEach(dayTasks) { task in
            taskCard(task)
                .customListRowStyle()
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        if isLiveTask(task) {
                            taskViewModel.deleteTask(task)
                        } else {
                            taskViewModel.deleteArchivedTask(task)
                        }
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

                    Button {
                        previewingTask = task
                    } label: {
                        Label("プレビュー", systemImage: "checkmark")
                            .labelStyle(.iconOnly)
                    }
                    .tint(DesignSystem.Colors.textSecondary)
                }
        }
    }

    private func isLiveTask(_ task: TaskItem) -> Bool {
        taskViewModel.tasks.contains { $0.id == task.id }
    }

    // MARK: - Cards

    private func journalCard(_ entry: JournalEntry) -> some View {
        HomeCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(entry.text)
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(3)
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(entry.date.timeHM)
                        .font(DesignSystem.Fonts.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    ForEach(entry.tags.prefix(2), id: \.self) { tag in
                        TagChip(text: tag)
                    }
                }
            }
        }
    }

    private func sessionCard(_ session: CoachSession) -> some View {
        HomeCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(session.summary ?? session.firstUserMessage ?? "セッション")
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(3)
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(session.createdAt.timeHM)
                        .font(DesignSystem.Fonts.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    if let emotion = session.emotionLabel, !emotion.isEmpty {
                        Text(emotion)
                            .font(DesignSystem.Fonts.caption)
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }
            }
        }
    }

    private func meditationCard(_ log: MeditationLog) -> some View {
        HomeCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("\(log.durationText)の瞑想")
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(log.date.timeHM)
                    .font(DesignSystem.Fonts.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func taskCard(_ task: TaskItem) -> some View {
        HomeCard {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(task.isCompleted ? DesignSystem.Colors.accent : DesignSystem.Colors.greyDark)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(task.title)
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                    if !task.previewText.isEmpty {
                        Text(task.previewText)
                            .font(DesignSystem.Fonts.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - セクション切り替え

/// ホームの3セクション種別
private enum HomeSectionKind: CaseIterable, Identifiable {
    case journal, session, task

    var id: Self { self }

    var title: String {
        switch self {
        case .journal: return "ジャーナル"
        case .session: return "セッション"
        case .task: return "タスク"
        }
    }

    var icon: String {
        switch self {
        case .journal: return "leaf"
        case .session: return "bubble.left.and.bubble.right"
        case .task: return "checklist"
        }
    }
}

/// セクションボタン用のカード風スタイル（surface+角丸。SurfaceCard と同トーン）
private struct SurfaceCardStyleLike: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.surfaceTinted.interactive(), in: .rect(cornerRadius: DesignSystem.Spacing.md))
        } else {
            content
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
        }
    }
}

/// 予定カード用の Liquid Glass 背景（角丸は小さめ）
private struct EventCardGlassStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.surfaceTinted.interactive(), in: .rect(cornerRadius: DesignSystem.Spacing.sm))
        } else {
            content
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm, style: .continuous))
        }
    }
}

/// ホームセクション内のカード（SurfaceCard の薄いラッパー）
private struct HomeCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        SurfaceCard {
            content
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(JournalViewModel())
        .environmentObject(CoachStore())
        .environmentObject(MeditationStore())
        .environmentObject(TaskViewModel())
}
