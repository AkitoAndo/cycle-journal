//
//  CoachHomeView.swift
//  CycleJournal
//

import SwiftUI

struct CoachHomeView: View {
    @EnvironmentObject var coachStore: CoachStore
    @EnvironmentObject var diaryStore: DiaryStore

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
                DiaryPickerView(onSelect: { diary in
                    // 日記内容を保持してからシートを閉じる
                    let diaryContent = diary.content
                    showingDiaryPicker = false

                    // シートが閉じた後にチャットを開始
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        Task {
                            await coachStore.startSessionWithDiary(diaryContent)
                        }
                        showingChat = true
                    }
                })
                .environmentObject(diaryStore)
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
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }
        }
        .padding(.top, 20)
    }

    private var greetingSection: some View {
        VStack(spacing: 8) {
            Text(greetingMessage)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)

            Text("今日はどんな一日だった？")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 話しかけるボタン
            Button(action: startNewChat) {
                HStack {
                    Image(systemName: "bubble.left")
                    Text("話しかける")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }

            // 日記から話すボタン
            Button(action: { showingDiaryPicker = true }) {
                HStack {
                    Image(systemName: "book")
                    Text("日記から話す")
                }
                .font(.headline)
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
                .font(.headline)
                .foregroundColor(.secondary)

            ForEach(coachStore.recentSessions) { session in
                SessionRowView(session: session)
                    .onTapGesture {
                        coachStore.currentSession = session
                        showingChat = true
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

// MARK: - Session Row View

struct SessionRowView: View {
    let session: CoachSession

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: session.createdAt))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(session.summary ?? session.firstUserMessage ?? "会話")
                    .font(.body)
                    .lineLimit(1)

                if let emotion = session.emotionLabel {
                    Text(emotion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Diary Picker View

struct DiaryPickerView: View {
    @EnvironmentObject var diaryStore: DiaryStore
    @Environment(\.dismiss) var dismiss

    let onSelect: (DiaryEntry) -> Void

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E) HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                ForEach(diaryStore.entries.prefix(20)) { entry in
                    Button(action: { onSelect(entry) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dateFormatter.string(from: entry.createdAt))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(entry.content)
                                .font(.body)
                                .lineLimit(2)
                                .foregroundColor(.primary)

                            if !entry.tags.isEmpty {
                                HStack {
                                    ForEach(entry.tags.prefix(3), id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue)
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("日記を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Session History View

struct SessionHistoryView: View {
    @EnvironmentObject var coachStore: CoachStore
    @Environment(\.dismiss) var dismiss

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                if coachStore.sessions.isEmpty {
                    ContentUnavailableView(
                        "会話履歴がありません",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("コーチと会話を始めると、ここに履歴が表示されます")
                    )
                } else {
                    ForEach(coachStore.sessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dateFormatter.string(from: session.createdAt))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(session.summary ?? session.firstUserMessage ?? "会話")
                                .font(.body)
                                .lineLimit(2)

                            if let emotion = session.emotionLabel {
                                Text(emotion)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteSessions)
                }
            }
            .navigationTitle("会話履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = coachStore.sessions[index]
            coachStore.deleteSession(session)
        }
    }
}

#Preview {
    CoachHomeView()
        .environmentObject(CoachStore())
        .environmentObject(DiaryStore())
}
