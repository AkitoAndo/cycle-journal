//
//  CoachHomeView.swift
//  CycleJournal
//

import SwiftUI

struct CoachHomeView: View {
    @EnvironmentObject var coachStore: CoachStore
    @EnvironmentObject var journalViewModel: JournalViewModel
    @EnvironmentObject var authStore: AuthStore

    @State private var showingChat = false
    @State private var showingHistory = false
    @State private var showingDiaryPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xxl) {
                    // コーチのビジュアル（アプリアイコン）
                    Image("CycleIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .padding(.top, DesignSystem.Spacing.xl)

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

                    // アクションボタン
                    VStack(spacing: DesignSystem.Spacing.md) {
                        PrimaryButton("話しかける", icon: "bubble.left") {
                            startNewChat()
                        }

                        SecondaryButton("日記から話す", icon: "book") {
                            showingDiaryPicker = true
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    // 最近の会話
                    if !coachStore.recentSessions.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            SectionLabel("最近の会話", icon: "clock")
                                .padding(.horizontal, DesignSystem.Spacing.lg)

                            VStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(coachStore.recentSessions) { session in
                                    SessionRowView(session: session)
                                        .onTapGesture {
                                            Task {
                                                if session.messages.isEmpty, session.serverId != nil {
                                                    if let fullSession = await coachStore.fetchSessionDetail(session) {
                                                        coachStore.currentSession = fullSession
                                                    } else {
                                                        coachStore.currentSession = session
                                                    }
                                                } else {
                                                    coachStore.currentSession = session
                                                }
                                                showingChat = true
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                    }
                }
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }
            }
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
}
