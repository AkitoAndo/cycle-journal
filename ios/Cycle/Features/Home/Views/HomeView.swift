//
//  HomeView.swift
//  Cycle
//
//  ホーム画面（2026-10 刷新）
//  「今日」を中心に、開いてすぐ書く・話すに入れる画面。
//  - 挨拶と、時間帯に合わせた今日の問いかけ（書く / 話す）
//  - 今日の予定（ある日だけ）と、今日の一歩（その日のタスク）
//  - 今週の樹と1週間の帯。タップで週のふりかえり（U-03）を始める
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var journalViewModel: JournalViewModel
    @EnvironmentObject private var coachStore: CoachStore
    @EnvironmentObject private var meditationStore: MeditationStore
    @EnvironmentObject private var taskViewModel: TaskViewModel

    /// アプリ独自の予定（ローカル保存）
    @StateObject private var scheduleStore = ScheduleStore()

    /// 予定の追加・編集シート（item で対象を確実に渡す）
    @State private var scheduleEditTarget: ScheduleEditTarget?
    /// 1日のタイムライン表示
    @State private var showingTimeline = false
    /// 日記の新規作成
    @State private var showingNewEntry = false
    /// 今週のふりかえりの開始前画面
    @State private var showingWeeklyReview = false
    /// タップで開くタスクのプレビュー
    @State private var previewingTask: TaskItem?

    private var calendar: Calendar { Calendar.current }
    private var week: WeeklyReviewWeek { WeeklyReviewWeek(containing: Date()) }

    // MARK: - 今日のデータ

    private var todayJournalCount: Int {
        journalViewModel.entries.filter { $0.deletedAt == nil && calendar.isDateInToday($0.date) }.count
    }

    private var todayEvents: [ScheduleEvent] {
        scheduleStore.events(on: Date())
    }

    /// 今日のタスク（未完了を先、完了を後）
    private var todayTasks: [TaskItem] {
        let tasks = taskViewModel.homeTasks(on: Date())
        return tasks.filter { !$0.isCompleted } + tasks.filter(\.isCompleted)
    }

    // MARK: - 今週の記録

    /// その日の記録数（日記・対話・瞑想・完了したタスク）
    private func recordCount(on day: Date) -> Int {
        let journals = journalViewModel.entries.filter { $0.deletedAt == nil && calendar.isDate($0.date, inSameDayAs: day) }.count
        // 開いただけで話していないセッションは数えない（同期で取得した履歴は要約の有無で判断）
        let sessions = coachStore.sessions.filter {
            calendar.isDate($0.createdAt, inSameDayAs: day)
                && ($0.messages.contains { $0.role == .user } || $0.summary != nil)
        }.count
        let meditations = meditationStore.logs.filter { calendar.isDate($0.date, inSameDayAs: day) }.count
        let steps = taskViewModel.homeTasks(on: day).filter(\.isCompleted).count
        return journals + sessions + meditations + steps
    }

    private var weekLeafCount: Int {
        week.days().reduce(0) { $0 + recordCount(on: $1) }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                header
                    .staggeredAppear(index: 0, group: "home")
                promptCard
                    .staggeredAppear(index: 1, group: "home")
                if !todayEvents.isEmpty {
                    scheduleSection
                        .staggeredAppear(index: 2, group: "home")
                }
                stepsSection
                    .staggeredAppear(index: 3, group: "home")
                weekCard
                    .staggeredAppear(index: 4, group: "home")
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
            // タブバー中央の大樹ロゴ（上に飛び出している）に隠れないよう下を空ける
            .padding(.bottom, DesignSystem.Spacing.xxl * 2)
        }
        .background(DesignSystem.Colors.backgroundGradient)
        .navigationBarHidden(true)
        .sheet(item: $scheduleEditTarget) { target in
            ScheduleEditView(
                store: scheduleStore,
                editing: target.event,
                defaultDate: Date()
            )
        }
        .sheet(isPresented: $showingTimeline) {
            DayTimelineView(store: scheduleStore, date: Date())
        }
        .sheet(isPresented: $showingNewEntry) {
            JournalNewEntryView(vm: journalViewModel)
                .softSheet()
        }
        .sheet(item: $previewingTask) { task in
            TaskPreviewView(task: task)
        }
        .sheet(isPresented: $showingWeeklyReview) {
            WeeklyReviewPrepView(week: week) { material in
                showingWeeklyReview = false
                // シートが閉じてからセッションタブへ移り、チャットを開く
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    Task {
                        await coachStore.startWeeklyReview(material: material)
                    }
                    NotificationCenter.default.post(name: .navigateToCoachChat, object: nil)
                }
            }
            .softSheet()
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(Date().formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ja_JP"))))
                    .font(DesignSystem.Fonts.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Text(greeting)
                    .font(DesignSystem.Fonts.largeTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            Spacer()
            menuButton
        }
    }

    private var menuButton: some View {
        Menu {
            Button(action: { scheduleEditTarget = .new }) {
                Label("予定を追加", systemImage: "calendar.badge.plus")
            }
            Button(action: { showingTimeline = true }) {
                Label("今日のタイムライン", systemImage: "clock")
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 21))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .modifier(GlassIconModifier())
        }
        .accessibilityLabel("メニュー")
        .accessibilityIdentifier("home_menu")
    }

    // MARK: - 今日の問いかけ

    /// 問いかけカードの色。ライト/ダークで同じ見た目にするため固定色にする
    private static let promptForeground = Color(red: 0.99, green: 0.97, blue: 0.93)
    private static let promptBackground = LinearGradient(
        colors: [Color(red: 0.55, green: 0.45, blue: 0.35), DesignSystem.Colors.brownDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(prompt)
                    .font(DesignSystem.Fonts.title2)
                    .foregroundStyle(Self.promptForeground)
                    .fixedSize(horizontal: false, vertical: true)
                if todayJournalCount > 0 {
                    Text("今日は\(todayJournalCount)つ書いています")
                        .font(DesignSystem.Fonts.subheadline)
                        .foregroundStyle(Self.promptForeground.opacity(0.8))
                }
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: { showingNewEntry = true }) {
                    Label("書く", systemImage: "pencil")
                        .font(DesignSystem.Fonts.button)
                        .foregroundStyle(DesignSystem.Colors.brownDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(Capsule().fill(Self.promptForeground))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("home_write_button")

                Button(action: startChat) {
                    Label("話す", systemImage: "bubble.left")
                        .font(DesignSystem.Fonts.button)
                        .foregroundStyle(Self.promptForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .overlay(Capsule().stroke(Self.promptForeground.opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("home_talk_button")
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.xxl, style: .continuous)
                .fill(Self.promptBackground)
        )
    }

    // MARK: - 今日の予定

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionTitle("今日の予定")
            VStack(spacing: 0) {
                ForEach(Array(todayEvents.enumerated()), id: \.element.id) { index, event in
                    if index > 0 { rowDivider }
                    Button(action: { scheduleEditTarget = .edit(event) }) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Text(event.timeText)
                                .font(DesignSystem.Fonts.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .frame(width: 72, alignment: .leading)
                            Text(event.title)
                                .font(DesignSystem.Fonts.body)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .modifier(HomeCardStyle())
        }
    }

    // MARK: - 今日の一歩

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionTitle("今日の一歩")
            if todayTasks.isEmpty {
                Text("今日のタスクはまだありません")
                    .font(DesignSystem.Fonts.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .padding(.vertical, DesignSystem.Spacing.xs)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(todayTasks.prefix(5).enumerated()), id: \.element.id) { index, task in
                        if index > 0 { rowDivider }
                        taskRow(task)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .modifier(HomeCardStyle())
            }
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(action: {
                withAnimation(DesignSystem.Timing.spring) {
                    taskViewModel.toggleCompletion(task)
                }
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(task.isCompleted ? DesignSystem.Colors.leaf : DesignSystem.Colors.greyDark)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "未完了に戻す" : "完了にする")

            Button(action: { previewingTask = task }) {
                HStack {
                    Text(task.title)
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(task.isCompleted ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textPrimary)
                        .strikethrough(task.isCompleted, color: DesignSystem.Colors.textTertiary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    // MARK: - 今週（樹と1週間の帯）

    private var weekCard: some View {
        let isReviewDay = week.isReviewDay(Date())
        return Button(action: { showingWeeklyReview = true }) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack(spacing: DesignSystem.Spacing.lg) {
                    WeeklyTreeView(leafCount: weekLeafCount)
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("今週の樹")
                            .font(DesignSystem.Fonts.label)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text(weekLeafCount == 0 ? "これから葉がついていきます" : "\(weekLeafCount)枚の葉がつきました")
                            .font(DesignSystem.Fonts.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    Spacer(minLength: 0)
                }

                HomeWeekStrip(days: week.days()) { recordCount(on: $0) > 0 }

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "leaf")
                        .font(.system(size: 14, weight: .semibold))
                    Text(isReviewDay ? "今週も、おつかれさま。少しだけふりかえってみる？" : "日曜の夜に、1週間をふりかえろう")
                        .font(DesignSystem.Fonts.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(isReviewDay ? DesignSystem.Colors.surface : DesignSystem.Colors.accent)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(
                    Capsule().fill(isReviewDay ? DesignSystem.Colors.accent : DesignSystem.Colors.accent.opacity(0.10))
                )
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(HomeCardStyle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .accessibilityIdentifier("home_weekly_review_card")
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(DesignSystem.Fonts.label)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(DesignSystem.Colors.grey.opacity(0.6))
            .frame(height: 0.5)
    }

    private var greeting: String {
        switch calendar.component(.hour, from: Date()) {
        case 5..<11: return "おはよう"
        case 11..<17: return "こんにちは"
        default: return "おつかれさま"
        }
    }

    /// 時間帯に合わせた今日の問いかけ
    private var prompt: String {
        switch calendar.component(.hour, from: Date()) {
        case 5..<11: return "今日は、どんな一日にしたい？"
        case 11..<17: return "いま、どんな気持ち？"
        default: return "今日は、どんな一日だった？"
        }
    }

    private func startChat() {
        _ = coachStore.startNewSession()
        NotificationCenter.default.post(name: .navigateToCoachChat, object: nil)
    }
}

/// ホームのカード（surface+大きめの角丸。iOS 26 以降は Liquid Glass）
private struct HomeCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.surfaceTinted.interactive(), in: .rect(cornerRadius: DesignSystem.Spacing.xl))
        } else {
            content
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.xl, style: .continuous))
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
