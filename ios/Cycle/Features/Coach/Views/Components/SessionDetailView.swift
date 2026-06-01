//
//  SessionDetailView.swift
//  CycleJournal
//

import SwiftUI

/// 過去の会話セッションを閲覧するビュー（読み取り専用）
struct SessionDetailView: View {
    @EnvironmentObject var coachStore: CoachStore
    @Environment(\.dismiss) var dismiss

    let session: CoachSession
    @State private var loadedSession: CoachSession?
    @State private var isLoading = false

    private var messages: [CoachMessage] {
        (loadedSession ?? session).messages
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if messages.isEmpty {
                    Spacer()
                    Text("メッセージがありません")
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Spacer()
                } else {
                    messageList
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle(session.summary ?? "会話")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
            .task {
                if messages.isEmpty, session.serverId != nil {
                    isLoading = true
                    loadedSession = await coachStore.fetchSessionDetail(session)
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                ForEach(messages) { message in
                    messageBubble(message)
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }

    // MARK: - Message Bubble

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private func messageBubble(_ message: CoachMessage) -> some View {
        HStack(alignment: .bottom, spacing: DesignSystem.Spacing.sm) {
            if message.role == .user {
                Spacer(minLength: 60)
            } else {
                coachAvatar
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: DesignSystem.Spacing.xs) {
                Text(message.content)
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(message.role == .user ? .white : DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, DesignSystem.Spacing.mlg)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(
                        message.role == .user
                            ? DesignSystem.Colors.accent
                            : DesignSystem.Colors.surface
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.lg, style: .continuous))

                Text(timeFormatter.string(from: message.createdAt))
                    .font(DesignSystem.Fonts.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            if message.role == .coach {
                Spacer(minLength: 60)
            }
        }
    }

    private var coachAvatar: some View {
        Image("CycleIcon")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 32, height: 32)
            .clipShape(Circle())
    }
}
