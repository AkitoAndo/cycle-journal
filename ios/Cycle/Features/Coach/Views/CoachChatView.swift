//
//  CoachChatView.swift
//  CycleJournal
//

import SwiftUI

struct CoachChatView: View {
    @EnvironmentObject var coachStore: CoachStore
    @EnvironmentObject var authStore: AuthStore
    @Environment(\.dismiss) var dismiss

    @State private var messageText = ""
    @State private var showingEndSessionAlert = false
    @FocusState private var isTextFieldFocused: Bool

    private var isLoggedIn: Bool {
        authStore.state.isAuthenticated
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NetworkStatusBanner()

                if !isLoggedIn {
                    offlineBanner
                }

                if let error = coachStore.lastAPIError, coachStore.error != nil {
                    ErrorBannerView(
                        message: error.errorDescription ?? "エラーが発生しました",
                        isRetryable: error.isRetryable,
                        onRetry: {
                            coachStore.clearError()
                            if let lastUserMessage = coachStore.currentSession?.messages.last(where: { $0.role == .user })?.content {
                                Task { await coachStore.sendMessage(lastUserMessage) }
                            }
                        },
                        onDismiss: { coachStore.clearError() }
                    )
                }

                messageList
                inputArea
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Cycle との会話")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("終了") {
                        showingEndSessionAlert = true
                    }
                    .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
            .alert("会話を終了しますか？", isPresented: $showingEndSessionAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("終了", role: .destructive) {
                    coachStore.endCurrentSession()
                    dismiss()
                }
            } message: {
                Text("この会話は履歴に保存されます")
            }
            .alert("再ログインが必要です", isPresented: $coachStore.showReauthPrompt) {
                Button("OK") {
                    coachStore.showReauthPrompt = false
                }
            } message: {
                Text("セッションの有効期限が切れました。設定画面からサインインし直してください。")
            }
            .onAppear {
                if let session = coachStore.currentSession,
                   session.messages.isEmpty,
                   !coachStore.isLoading {
                    Task {
                        await sendInitialCoachMessage()
                    }
                }
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(currentMessages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    if coachStore.isLoading {
                        typingIndicator
                            .id("loading")
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .onChange(of: currentMessages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: coachStore.isLoading) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(DesignSystem.Timing.easing) {
                if coachStore.isLoading {
                    proxy.scrollTo("loading", anchor: .bottom)
                } else if let lastMessage = currentMessages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
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

    // MARK: - Coach Avatar

    private var coachAvatar: some View {
        Image("CycleIcon")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 32, height: 32)
            .clipShape(Circle())
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(alignment: .bottom, spacing: DesignSystem.Spacing.sm) {
            coachAvatar

            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(DesignSystem.Colors.textTertiary)
                        .frame(width: 8, height: 8)
                        .opacity(typingDotOpacity(for: index))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.lg, style: .continuous))

            Spacer(minLength: 60)
        }
        .onAppear { startTypingAnimation() }
    }

    @State private var typingPhase: Int = 0

    private func typingDotOpacity(for index: Int) -> Double {
        let phase = (typingPhase + index) % 3
        switch phase {
        case 0: return 1.0
        case 1: return 0.5
        default: return 0.3
        }
    }

    private func startTypingAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(DesignSystem.Timing.fastEasing) {
                typingPhase = (typingPhase + 1) % 3
            }
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
                .foregroundStyle(DesignSystem.Colors.grey)

            HStack(spacing: DesignSystem.Spacing.md) {
                TextField("メッセージを入力...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isTextFieldFocused)
                    .font(DesignSystem.Fonts.body)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.xxl, style: .continuous))
                    .onSubmit {
                        sendMessage()
                    }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? DesignSystem.Colors.accent : DesignSystem.Colors.greyDark)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.background)
        }
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "info.circle")
                .font(DesignSystem.Fonts.caption)
            Text("オフラインモード — 設定からサインインするとAIコーチが応答します")
                .font(DesignSystem.Fonts.caption)
        }
        .foregroundStyle(DesignSystem.Colors.textSecondary)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.surface)
    }

    // MARK: - Helpers

    private var currentMessages: [CoachMessage] {
        coachStore.currentSession?.messages ?? []
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !coachStore.isLoading
    }

    private func sendMessage() {
        guard canSend else { return }

        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        isTextFieldFocused = false

        Task {
            await coachStore.sendMessage(text)
        }
    }

    private func sendInitialCoachMessage() async {
        let initialMessage = "こんにちは。今日はどんなことを話したい？\n\n何か心に浮かんでいることがあれば、教えてね。"

        await MainActor.run {
            coachStore.addCoachMessage(initialMessage)
        }
    }
}

#Preview {
    CoachChatView()
        .environmentObject(CoachStore())
}
