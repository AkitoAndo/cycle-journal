//
//  CoachHomeView.swift
//  CycleJournal
//
//  コーチタブ（U-04 実装単位3で iOS 17 の形に）。
//  - 大きなタイトル「コーチ」、右上に履歴
//  - 呼吸に合わせて広がる大樹ロゴ（タップで呼吸セッション）
//  - 「話しかける」の大きなボタンと、日記から話す / 1週間をふりかえる のリスト
//

import SwiftUI

struct CoachHomeView: View {
    @EnvironmentObject var coachStore: CoachStore
    @EnvironmentObject var journalViewModel: JournalViewModel
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var meditationStore: MeditationStore

    @State private var showingChat = false
    @State private var showingHistory = false
    @State private var showingDiaryPicker = false
    @State private var showingBreathing = false
    @State private var showingWeeklyReview = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cycleTabIsActive) private var cycleTabIsActive

    private var week: WeeklyReviewWeek { WeeklyReviewWeek(containing: Date()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                    .staggeredAppear(index: 0, group: "coach_home")
                hero
                    .staggeredAppear(index: 1, group: "coach_home")
                talkButton
                    .staggeredAppear(index: 2, group: "coach_home")
                otherWays
                    .staggeredAppear(index: 3, group: "coach_home")
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.top, DesignSystem.Spacing.sm)
            // タブバーに隠れないよう下を空ける
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .background(DesignSystem.Colors.backgroundGradient)
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingChat) {
            CoachChatView()
                .environmentObject(coachStore)
                .environmentObject(authStore)
        }
        .onReceive(coachStore.$shouldOpenChat) { shouldOpen in
            if shouldOpen {
                showingChat = true
                coachStore.shouldOpenChat = false
            }
        }
        .sheet(isPresented: $showingHistory) {
            SessionHistoryView()
                .environmentObject(coachStore)
                .environmentObject(meditationStore)
                .softSheet()
        }
        .sheet(isPresented: $showingBreathing) {
            BreathingSessionView()
                .environmentObject(meditationStore)
                .softSheet()
        }
        .sheet(isPresented: $showingDiaryPicker) {
            DiaryPickerView(onSelect: { entry in
                let diaryContent = entry.text
                showingDiaryPicker = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    Task {
                        await coachStore.startSessionWithDiary(diaryContent)
                    }
                    showingChat = true
                }
            })
            .environmentObject(journalViewModel)
            .softSheet()
        }
        .sheet(isPresented: $showingWeeklyReview) {
            WeeklyReviewPrepView(week: week) { material in
                showingWeeklyReview = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    Task {
                        await coachStore.startWeeklyReview(material: material)
                    }
                    showingChat = true
                }
            }
            .softSheet()
        }
    }

    // MARK: - ヘッダー（大きなタイトル）

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("コーチ")
                .font(.largeTitle.bold())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Spacer()
            Button(action: { showingHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 22))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("履歴")
            .accessibilityIdentifier("coach_history_button")
        }
    }

    // MARK: - 呼吸ハローと問いかけ

    private var hero: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button(action: { showingBreathing = true }) {
                // 呼吸に合わせて広がるハロー。正弦波駆動の連続アニメーションで
                // 折り返しの止まりがなく、常に滑らかに満ち引きする
                TimelineView(.animation(paused: !shouldAnimateBreathing)) { context in
                    breathingVisual(
                        phase: shouldAnimateBreathing
                            ? breathPhase(at: context.date)
                            : 0.5
                    )
                }
                // ハローの見た目いっぱいまでタップ可能にする
                .frame(width: 200, height: 200)
                .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle(scale: 0.94))
            .accessibilityLabel("呼吸セッションを始める")
            .accessibilityIdentifier("coach_breathing_button")

            Text("タップして、呼吸を整える")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(greetingMessage)
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("今日はどんな一日だった？")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
    }

    private var shouldAnimateBreathing: Bool {
        cycleTabIsActive
            && !reduceMotion
            && !showingChat
            && !showingHistory
            && !showingDiaryPicker
            && !showingBreathing
            && !showingWeeklyReview
    }

    /// 1呼吸（吸って吐く）の周期（秒）。ゆったりした腹式呼吸のテンポ
    private var breathPeriod: Double { 6.4 }

    /// 時刻から呼吸フェーズを算出（0=吐き切り 〜 1=吸い切り、正弦波で滑らかに往復）
    private func breathPhase(at date: Date, lag: Double = 0) -> Double {
        let t = date.timeIntervalSinceReferenceDate / breathPeriod - lag
        return (sin(t * 2 * .pi - .pi / 2) + 1) / 2
    }

    /// ハロー + アイコン一式（phase: 0〜1）
    private func breathingVisual(phase p: Double) -> some View {
        ZStack {
            // 外側ほど淡く・わずかに遅れて追従する三重のハロー（波紋のような奥行き）
            haloRing(phase: p * 0.92, growth: 0.75, maxOpacity: 0.10)
            haloRing(phase: p * 0.96, growth: 0.55, maxOpacity: 0.16)
            haloRing(phase: p,        growth: 0.35, maxOpacity: 0.22)

            Image("CycleIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .scaleEffect(1.0 + 0.05 * p)
                // 吸うときにふわっと明るくなるグロウ
                .shadow(
                    color: DesignSystem.Colors.accent.opacity(0.10 + 0.18 * p),
                    radius: 10 + 10 * p
                )
        }
    }

    /// ハロー1枚。放射グラデーションで縁を柔らかくぼかし、
    /// 広がるほど淡くなることで自然な減衰を表現する
    private func haloRing(phase p: Double, growth: CGFloat, maxOpacity: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        DesignSystem.Colors.accent.opacity(maxOpacity),
                        DesignSystem.Colors.accent.opacity(maxOpacity * 0.55),
                        DesignSystem.Colors.accent.opacity(0)
                    ],
                    center: .center,
                    startRadius: 28,
                    endRadius: 74
                )
            )
            .frame(width: 120, height: 120)
            .scaleEffect(1.04 + growth * CGFloat(p))
            .opacity(0.55 + 0.45 * (1 - p))
    }

    // MARK: - 話しかける

    /// この画面でいちばん目立つ1つのボタン
    private var talkButton: some View {
        Button(action: startNewChat) {
            Label("話しかける", systemImage: "bubble.left")
                .font(.headline)
                .foregroundStyle(Self.talkForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.mlg)
                .background(Capsule().fill(DesignSystem.Colors.accent))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("coach_talk_button")
    }

    /// 茶色のボタンの上の文字色（ライト/ダークで同じ見た目にするため固定色）
    private static let talkForeground = Color(red: 0.99, green: 0.97, blue: 0.93)

    // MARK: - ほかの話し方

    private var otherWays: some View {
        let isReviewDay = week.isReviewDay(Date())
        return InsetGroup {
            InsetNavigationRow(title: "日記から話す", systemImage: "book") {
                showingDiaryPicker = true
            }
            InsetRowDivider(leadingInset: 56)
            InsetNavigationRow(
                title: "1週間をふりかえる",
                systemImage: "leaf",
                detail: isReviewDay ? "今日" : "日曜の夜",
                detailColor: isReviewDay ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary
            ) {
                showingWeeklyReview = true
            }
        }
    }

    // MARK: - Helpers

    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "おはよう"
        case 12..<17:
            return "こんにちは"
        default:
            return "おつかれさま"
        }
    }

    private func startNewChat() {
        _ = coachStore.startNewSession()
        showingChat = true
    }
}

#Preview {
    CoachHomeView()
        .environmentObject(CoachStore())
        .environmentObject(JournalViewModel())
        .environmentObject(MeditationStore())
}
