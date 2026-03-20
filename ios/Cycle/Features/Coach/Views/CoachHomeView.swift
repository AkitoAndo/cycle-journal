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
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Cycle")
            .navigationBarTitleDisplayMode(.inline)
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
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "tree")
                    .font(DesignSystem.Fonts.heroIcon)
                    .foregroundColor(.green)
            }
        }
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
            Button(action: startNewChat) {
                HStack {
                    Image(systemName: "bubble.left")
                    Text("話しかける")
                }
                .font(DesignSystem.Fonts.button)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }

            Button(action: { showingDiaryPicker = true }) {
                HStack {
                    Image(systemName: "book")
                    Text("日記から話す")
                }
                .font(DesignSystem.Fonts.button)
                .foregroundColor(.green)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal)
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近の会話")
                .font(DesignSystem.Fonts.button)
                .foregroundColor(.secondary)

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
