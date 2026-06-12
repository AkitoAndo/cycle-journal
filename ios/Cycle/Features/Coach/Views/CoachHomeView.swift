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
    @State private var isBreathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
                sessionHeader
                Spacer()

                Button(action: { showingBreathing = true }) {
                    Image("CycleIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .background {
                            // 呼吸に合わせて広がる淡いハロー
                            Circle()
                                .fill(DesignSystem.Colors.accent.opacity(0.12))
                                .scaleEffect(isBreathing ? 1.35 : 1.05)
                            Circle()
                                .fill(DesignSystem.Colors.accent.opacity(0.08))
                                .scaleEffect(isBreathing ? 1.6 : 1.1)
                        }
                        .scaleEffect(isBreathing ? 1.04 : 1.0)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.94))
                .accessibilityLabel("呼吸セッションを始める")
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                        isBreathing = true
                    }
                }
                .staggeredAppear(index: 0)

                Text("タップして、呼吸を整える")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.top, DesignSystem.Spacing.md)
                    .staggeredAppear(index: 1)

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
                .staggeredAppear(index: 2)

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
                .staggeredAppear(index: 3)
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

    // MARK: - Header

    private var sessionHeader: some View {
        HStack(alignment: .center) {
            Text("セッション")
                .font(DesignSystem.Fonts.screenTitle)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            Button(action: { showingHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 22))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .modifier(GlassIconModifier())
            }
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
