//
//  CoachHomeView.swift
//  CycleJournal
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cycleTabIsActive) private var cycleTabIsActive

    var body: some View {
        VStack(spacing: 0) {
                sessionHeader
                Spacer()

                Button(action: { showingBreathing = true }) {
                    ZStack {
                        // 呼吸に合わせて広がるハロー。正弦波駆動の連続アニメーションで
                        // 折り返しの止まりがなく、常に滑らかに満ち引きする
                        TimelineView(.animation(paused: !shouldAnimateBreathing)) { context in
                            breathingVisual(
                                phase: shouldAnimateBreathing
                                    ? breathPhase(at: context.date)
                                    : 0.5
                            )
                        }
                    }
                    // ハローの見た目いっぱいまでタップ可能にする
                    .frame(width: 200, height: 200)
                    .contentShape(Circle())
                }
                .buttonStyle(PressableButtonStyle(scale: 0.94))
                .accessibilityLabel("呼吸セッションを始める")
                .accessibilityIdentifier("coach_breathing_button")
                .staggeredAppear(index: 0, group: "coach_home")

                Text("タップして、呼吸を整える")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.top, DesignSystem.Spacing.md)
                    .staggeredAppear(index: 1, group: "coach_home")

                Spacer().frame(height: DesignSystem.Spacing.xl)

                // 挨拶メッセージ
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text(greetingMessage)
                        .font(DesignSystem.Fonts.sectionTitle)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("今日はどんな一日だった？")
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .staggeredAppear(index: 2, group: "coach_home")

                Spacer()

                // アクションボタン
                VStack(spacing: DesignSystem.Spacing.lg) {
                    PrimaryButton("話しかける", icon: "bubble.left") {
                        startNewChat()
                    }

                    SecondaryButton("日記から話す", icon: "book") {
                        showingDiaryPicker = true
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xxl * 2)
                .staggeredAppear(index: 3, group: "coach_home")
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
    }

    // MARK: - 呼吸ハロー

    private var shouldAnimateBreathing: Bool {
        cycleTabIsActive
            && !reduceMotion
            && !showingChat
            && !showingHistory
            && !showingDiaryPicker
            && !showingBreathing
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

    // MARK: - Header

    private var sessionHeader: some View {
        HStack(alignment: .center) {
            Text("セッション")
                .font(DesignSystem.Fonts.screenTitle)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            Button(action: { showingHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    // ジャーナル/タスクのヘッダーボタンとサイズを統一
                    .font(.system(size: 21))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .modifier(GlassIconModifier())
            }
            .accessibilityLabel("セッション履歴")
            .accessibilityIdentifier("coach_history_button")
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.background)
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
