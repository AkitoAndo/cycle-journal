//
//  HomeView.swift
//  Cycle
//
//  ホーム画面（2026-10 刷新）
//  「今日」を中心に、開いてすぐ書く・話すに入れる画面。
//  見た目は iOS 17 の標準アプリに合わせる（大きなタイトル・角丸でまとめたリスト・標準の文字）。
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
    /// 今日のタスクの新規作成
    @State private var showingNewTask = false
    /// 今週のふりかえりの開始前画面
    @State private var showingWeeklyReview = false
    /// タップで開くタスクのプレビュー
    @State private var previewingTask: TaskItem?
    /// マイページ（タブから外し、右上のアイコンから開く。U-04）
    @State private var showingMyPage = false

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
            VStack(alignment: .leading, spacing: 28) {
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
                weekSection
                    .staggeredAppear(index: 4, group: "home")
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.top, DesignSystem.Spacing.sm)
            // タブバー中央の大樹ロゴ（上に飛び出している）に隠れないよう下を空ける
            .padding(.bottom, 88)
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
        .sheet(isPresented: $showingNewTask) {
            TaskNewEntryView(vm: taskViewModel, date: Date())
                .softSheet()
        }
        .sheet(item: $previewingTask) { task in
            TaskPreviewView(task: task)
        }
        .sheet(isPresented: $showingMyPage) {
            MyPageView(showsCloseButton: true)
                .softSheet()
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

    // MARK: - ヘッダー（大きなタイトル）

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            // 見出しは今日の日付（挨拶は出さない）。大きく「10月24日」、下に小さく曜日
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.month().day().locale(Locale(identifier: "ja_JP"))))
                    .font(.largeTitle.bold())
                    .fontDesign(.serif)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(Date().formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "ja_JP"))))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            Spacer()
            HStack(spacing: 0) {
                menuButton
                myPageButton
            }
        }
    }

    private var myPageButton: some View {
        Button(action: { showingMyPage = true }) {
            Image(systemName: "person.circle")
                .font(.system(size: 22))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("マイページ")
        .accessibilityIdentifier("home_mypage_button")
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
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 22))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("メニュー")
        .accessibilityIdentifier("home_menu")
    }

    // MARK: - 今日の問いかけ

    /// 茶色のボタンの上の文字色（ライト/ダークで同じ見た目にするため固定色）
    private static let onAccent = Color(red: 0.99, green: 0.97, blue: 0.93)

    /// 今日の問いかけ。カードに入れず、セリフ体の文字と2つのボタンをそのまま置く
    /// （茶の塗りは「書く」ひとつだけ）
    private var promptCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(prompt)
                    .font(.title.weight(.semibold))
                    .fontDesign(.serif)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if todayJournalCount > 0 {
                    Text("今日は\(todayJournalCount)つ書いています")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: { showingNewEntry = true }) {
                    Label("書く", systemImage: "square.and.pencil")
                        .font(.headline)
                        .foregroundStyle(Self.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(Capsule().fill(DesignSystem.Colors.accent))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("home_write_button")

                Button(action: startChat) {
                    Label("話す", systemImage: "bubble.left")
                        .font(.headline)
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .overlay(Capsule().stroke(DesignSystem.Colors.accent.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("home_talk_button")
            }
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }

    // MARK: - 今日の予定

    private var scheduleSection: some View {
        HomeSection("今日の予定") {
            ForEach(Array(todayEvents.enumerated()), id: \.element.id) { index, event in
                if index > 0 { HomeRowDivider(leadingInset: DesignSystem.Spacing.lg) }
                Button(action: { scheduleEditTarget = .edit(event) }) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Text(event.timeText)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .frame(width: 84, alignment: .leading)
                        Text(event.title)
                            .font(.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        HomeChevron()
                    }
                    .homeRow()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 今日の一歩

    private var stepsSection: some View {
        HomeSection("今日の一歩") {
            ForEach(Array(todayTasks.prefix(5).enumerated()), id: \.element.id) { index, task in
                if index > 0 { HomeRowDivider(leadingInset: 50) }
                taskRow(task)
            }
            if !todayTasks.isEmpty { HomeRowDivider(leadingInset: 50) }
            // リマインダーAppと同じく、リストの最後から追加できる
            Button(action: { showingNewTask = true }) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(DesignSystem.Colors.accent)
                    Text(todayTasks.isEmpty ? "今日の一歩を追加" : "一歩を追加")
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.accent)
                    Spacer(minLength: 0)
                }
                .homeRow()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home_add_step_button")
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
                        .font(.body)
                        .foregroundStyle(task.isCompleted ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textPrimary)
                        .strikethrough(task.isCompleted, color: DesignSystem.Colors.textTertiary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    HomeChevron()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .homeRow()
    }

    // MARK: - 今週（樹と1週間の帯）

    private var weekSection: some View {
        let isReviewDay = week.isReviewDay(Date())
        return HomeSection("今週") {
            VStack(spacing: DesignSystem.Spacing.lg) {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    WeeklyTreeView(leafCount: weekLeafCount)
                        .frame(height: 130)
                    Text(weekLeafCount == 0 ? "これから葉がついていきます" : "今週、\(weekLeafCount)枚の葉がつきました")
                        .font(.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    // 何が葉になるかの説明は、まだ葉がない週だけ出す（1枚ついたら役目を終える）
                    if weekLeafCount == 0 {
                        Text("日記・対話・瞑想・完了した一歩が葉になります")
                            .font(.footnote)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                HomeWeekStrip(days: week.days()) { recordCount(on: $0) > 0 }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.lg)

            HomeRowDivider(leadingInset: DesignSystem.Spacing.lg)

            Button(action: { showingWeeklyReview = true }) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Text("1週間をふりかえる")
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.accent)
                    Spacer(minLength: 0)
                    Text(isReviewDay ? "今日" : "日曜の夜")
                        .font(.subheadline)
                        .foregroundStyle(isReviewDay ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                    HomeChevron()
                }
                .homeRow()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home_weekly_review_card")
        }
    }

    // MARK: - Helpers

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

// MARK: - iOS 17 風のリスト部品

/// 見出し + 角丸でまとめたリスト（設定アプリの inset grouped と同じ形）
private struct HomeSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(.leading, DesignSystem.Spacing.xs)
            VStack(spacing: 0) {
                content
            }
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
            // 塗りに頼らず、細い線で輪郭を出す（Claude アプリのカードと同じ考え方）
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous)
                    .stroke(DesignSystem.Colors.grey, lineWidth: 0.5)
            )
        }
    }
}

/// リストの区切り線（左は本文の位置から始める）
private struct HomeRowDivider: View {
    let leadingInset: CGFloat

    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.grey)
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
    }
}

/// 行末の「>」
private struct HomeChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(DesignSystem.Colors.textTertiary)
    }
}

private extension View {
    /// リスト1行分の余白（高さ44pt以上）
    func homeRow() -> some View {
        self
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
    }
}

#Preview {
    HomeView()
        .environmentObject(JournalViewModel())
        .environmentObject(CoachStore())
        .environmentObject(MeditationStore())
        .environmentObject(TaskViewModel())
}
