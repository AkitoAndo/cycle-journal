//
//  CoachHomeView.swift
//  CycleJournal
//

import SwiftUI

struct CoachHomeView: View {
    @EnvironmentObject var coachStore: CoachStore
    @EnvironmentObject var journalViewModel: JournalViewModel

    @State private var showingChat = false
    @State private var showingHistory = false
    @State private var showingDiaryPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // コーチのビジュアル
                    coachVisual

                    // 挨拶メッセージ
                    greetingSection

                    // アクションボタン
                    actionButtons

                    // 最近の会話
                    if !coachStore.recentSessions.isEmpty {
                        recentSessionsSection
                    }
                }
                .padding()
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Cycle")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .fullScreenCover(isPresented: $showingChat) {
                CoachChatView()
                    .environmentObject(coachStore)
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

    // MARK: - Components

    private var coachVisual: some View {
        IconCircle(icon: "tree", size: 120, color: DesignSystem.Colors.accent)
            .padding(.top, 20)
    }

    private var greetingSection: some View {
        VStack(spacing: 8) {
            Text(greetingMessage)
                .font(DesignSystem.Fonts.sectionTitle)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)

            Text("今日はどんな一日だった？")
                .font(DesignSystem.Fonts.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "話しかける", icon: "bubble.left", color: DesignSystem.Colors.accent, action: startNewChat)

            SecondaryButton(title: "日記から話す", icon: "book", color: DesignSystem.Colors.accent) {
                showingDiaryPicker = true
            }
        }
        .padding(.horizontal)
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "最近の会話")

            ForEach(coachStore.recentSessions) { session in
                SessionRowView(session: session)
                    .onTapGesture {
                        Task {
                            // サーバーにメッセージがある場合は詳細を取得
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
        .padding(.horizontal)
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
