//
//  CoachChatView.swift
//  CycleJournal
//

import SwiftUI
import Pow

struct CoachChatView: View {
    @EnvironmentObject var coachStore: CoachStore
    @EnvironmentObject var authStore: AuthStore
    @Environment(\.dismiss) var dismiss

    @State private var messageText = ""
    @State private var showingEndSessionAlert = false
    @State private var sendCount = 0
    /// 進行中の送信タスク。停止ボタンでキャンセルする
    @State private var sendTask: Task<Void, Never>?
    /// スクロール位置が最下部付近かどうか。
    /// ユーザーが上にスクロールして読み返している間は自動追従を止める
    @State private var isNearBottom = true
    @FocusState private var isTextFieldFocused: Bool

    /// 会話の書き出しを助ける提案。初回挨拶だけの状態で表示する
    private static let starterSuggestions = [
        "今日あったことを話したい",
        "ちょっとモヤモヤしている",
        "嬉しかったことがあった",
        "考えを整理したい",
    ]

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
                    // ストリーミング開始直後の空メッセージは表示しない
                    // （タイピングインジケーターが代わりに出る）
                    ForEach(Array(visibleMessages.enumerated()), id: \.element.id) { index, message in
                        messageBubble(message, showsTimestamp: shouldShowTimestamp(at: index))
                            .id(message.id)
                            .transition(
                                .scale(
                                    scale: 0.9,
                                    anchor: message.role == .user ? .bottomTrailing : .bottomLeading
                                )
                                .combined(with: .opacity)
                            )
                    }

                    if coachStore.isLoading {
                        typingIndicator
                            .id("loading")
                            .transition(.opacity)
                    }

                    if showsConversationStarters {
                        conversationStarters
                            .transition(.opacity.combined(with: .offset(y: 8)))
                    }

                    // 最下部マーカー。画面外に出たら「読み返し中」とみなして
                    // 自動追従を止める
                    Color.clear
                        .frame(height: 1)
                        .onAppear { isNearBottom = true }
                        .onDisappear { isNearBottom = false }
                }
                .padding(DesignSystem.Spacing.lg)
                .animation(DesignSystem.Timing.spring, value: visibleMessages.count)
                .animation(DesignSystem.Timing.spring, value: showsConversationStarters)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .bottomTrailing) {
                if !isNearBottom {
                    scrollToBottomButton(proxy: proxy)
                }
            }
            // 自分の送信では必ず最下部へ
            .onChange(of: sendCount) { _, _ in
                scrollToBottom(proxy: proxy, force: true)
            }
            .onChange(of: currentMessages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            // ストリーミングで最後のメッセージが伸びている間もスクロールを追従させる
            .onChange(of: currentMessages.last?.content) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: coachStore.isLoading) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            // キーボードが開いたら最新メッセージまでスクロール
            .onChange(of: isTextFieldFocused) { _, focused in
                if focused {
                    scrollToBottom(proxy: proxy)
                }
            }
        }
    }

    /// 読み返し中に新着へ戻るためのフローティングボタン
    private func scrollToBottomButton(proxy: ScrollViewProxy) -> some View {
        Button {
            scrollToBottom(proxy: proxy, force: true)
        } label: {
            Image(systemName: "arrow.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 36, height: 36)
                .background(DesignSystem.Colors.surface)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(DesignSystem.Colors.grey.opacity(0.5), lineWidth: 0.5)
                )
                .shadow(color: DesignSystem.Colors.brownDark.opacity(0.18), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.9))
        .padding(.trailing, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.md)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
        .accessibilityLabel("最新のメッセージへ")
    }

    // MARK: - Conversation Starters

    /// 初回挨拶だけの状態（ユーザーがまだ発言していない）かどうか
    private var showsConversationStarters: Bool {
        !coachStore.isLoading && !visibleMessages.contains { $0.role == .user }
    }

    private var conversationStarters: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(Self.starterSuggestions, id: \.self) { starter in
                Button {
                    sendCount += 1
                    isTextFieldFocused = false
                    sendTask = Task { await coachStore.sendMessage(starter) }
                } label: {
                    Text(starter)
                        .font(DesignSystem.Fonts.subheadline)
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .padding(.horizontal, DesignSystem.Spacing.mlg)
                        .padding(.vertical, DesignSystem.Spacing.sm + 2)
                        .background(DesignSystem.Colors.accent.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(DesignSystem.Colors.accent.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 40) // コーチの吹き出しに揃える
        .padding(.top, DesignSystem.Spacing.sm)
    }

    private func scrollToBottom(proxy: ScrollViewProxy, force: Bool = false) {
        // 読み返し中（最下部から離れている）は自動追従しない。
        // 自分の送信や「最新へ」ボタンでは force で必ず移動する
        guard force || isNearBottom else { return }

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

    /// 連続するメッセージのタイムスタンプは集約する。
    /// 話者が変わる直前・3分以上空く直前・最後のメッセージにだけ表示する
    private func shouldShowTimestamp(at index: Int) -> Bool {
        let messages = visibleMessages
        guard index < messages.count - 1 else { return true }
        let current = messages[index]
        let next = messages[index + 1]
        return next.role != current.role
            || next.createdAt.timeIntervalSince(current.createdAt) >= 180
    }

    private func messageBubble(_ message: CoachMessage, showsTimestamp: Bool = true) -> some View {
        HStack(alignment: .bottom, spacing: DesignSystem.Spacing.sm) {
            if message.role == .user {
                Spacer(minLength: 60)
            } else {
                coachAvatar
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: DesignSystem.Spacing.xs) {
                Text(message.content)
                    .font(DesignSystem.Fonts.body)
                    .lineSpacing(3)
                    .foregroundStyle(message.role == .user ? .white : DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, DesignSystem.Spacing.mlg)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background {
                        if message.role == .user {
                            DesignSystem.Colors.accentGradient
                        } else {
                            DesignSystem.Colors.surface
                        }
                    }
                    .clipShape(bubbleShape(isUser: message.role == .user))
                    .shadow(
                        color: DesignSystem.Colors.brownDark.opacity(message.role == .user ? 0.15 : 0.05),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("コピー", systemImage: "doc.on.doc")
                        }
                    }

                if showsTimestamp {
                    Text(timeFormatter.string(from: message.createdAt))
                        .font(DesignSystem.Fonts.caption2)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }

            if message.role == .coach {
                Spacer(minLength: 60)
            }
        }
    }

    /// 発話者側の下角だけ小さくした「しっぽ」付きの吹き出し形状
    private func bubbleShape(isUser: Bool) -> UnevenRoundedRectangle {
        let radius: CGFloat = 18
        let tail: CGFloat = 6
        return UnevenRoundedRectangle(
            topLeadingRadius: radius,
            bottomLeadingRadius: isUser ? radius : tail,
            bottomTrailingRadius: isUser ? tail : radius,
            topTrailingRadius: radius,
            style: .continuous
        )
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
                        .offset(y: typingDotOffset(for: index))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface)
            .clipShape(bubbleShape(isUser: false))

            Spacer(minLength: 60)
        }
        .onAppear { startTypingAnimation() }
        .onDisappear { stopTypingAnimation() }
    }

    @State private var typingPhase: Int = 0
    @State private var typingTimer: Timer?

    private func typingDotOpacity(for index: Int) -> Double {
        let phase = (typingPhase + index) % 3
        switch phase {
        case 0: return 1.0
        case 1: return 0.5
        default: return 0.3
        }
    }

    private func typingDotOffset(for index: Int) -> CGFloat {
        (typingPhase + index) % 3 == 0 ? -3 : 0
    }

    private func startTypingAnimation() {
        stopTypingAnimation()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(DesignSystem.Timing.spring) {
                typingPhase = (typingPhase + 1) % 3
            }
        }
    }

    private func stopTypingAnimation() {
        typingTimer?.invalidate()
        typingTimer = nil
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
                    .overlay(
                        // フォーカス時にアクセント色のリングを表示
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.xxl, style: .continuous)
                            .stroke(
                                DesignSystem.Colors.accent.opacity(isTextFieldFocused ? 0.45 : 0),
                                lineWidth: 1.5
                            )
                    )
                    .animation(DesignSystem.Timing.fastEasing, value: isTextFieldFocused)
                    .onSubmit {
                        sendMessage()
                    }

                if coachStore.isLoading {
                    // 生成中は停止ボタンに切り替える
                    Button {
                        sendTask?.cancel()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.9))
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .accessibilityLabel("生成を停止")
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(canSend ? DesignSystem.Colors.accent : DesignSystem.Colors.greyDark)
                            .scaleEffect(canSend ? 1.0 : 0.92)
                            .animation(DesignSystem.Timing.spring, value: canSend)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.9))
                    .disabled(!canSend)
                    .changeEffect(.feedback(hapticImpact: .light), value: sendCount)
                    .accessibilityLabel("送信")
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.background)
            .animation(DesignSystem.Timing.fastEasing, value: coachStore.isLoading)
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

    /// 表示対象のメッセージ。ストリーミング開始直後の空のコーチメッセージは
    /// タイピングインジケーターで代替するため除外する
    private var visibleMessages: [CoachMessage] {
        currentMessages.filter { !($0.role == .coach && $0.content.isEmpty) }
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !coachStore.isLoading
    }

    private func sendMessage() {
        guard canSend else { return }

        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        isTextFieldFocused = false
        sendCount += 1

        sendTask = Task {
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
