//
//  CoachChatView.swift
//  CycleJournal
//

import SwiftUI

struct CoachChatView: View {
    @EnvironmentObject var coachStore: CoachStore
    @Environment(\.dismiss) var dismiss

    @State private var messageText = ""
    @State private var showingEndSessionAlert = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // メッセージリスト
                messageList

                // 入力エリア
                inputArea
            }
            .navigationTitle("Cycle との会話")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("終了") {
                        showingEndSessionAlert = true
                    }
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
            .onAppear {
                // 新しいセッションで初期メッセージを送信
                // ただし、ローディング中（日記から開始など）の場合は待つ
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
                LazyVStack(spacing: 12) {
                    ForEach(currentMessages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    // ローディング表示
                    if coachStore.isLoading {
                        TypingIndicatorView()
                            .id("loading")
                    }
                }
                .padding()
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
            withAnimation(.easeOut(duration: 0.2)) {
                if coachStore.isLoading {
                    proxy.scrollTo("loading", anchor: .bottom)
                } else if let lastMessage = currentMessages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                TextField("メッセージを入力...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .onSubmit {
                        sendMessage()
                    }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(canSend ? .green : .gray)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
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
        // 初期メッセージを送信
        let initialMessage = "こんにちは。今日はどんなことを話したい？\n\n何か心に浮かんでいることがあれば、教えてね。"

        await MainActor.run {
            coachStore.addCoachMessage(initialMessage)
        }
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: CoachMessage

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 60)
            } else {
                // コーチアバター
                Image(systemName: "tree")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                    .frame(width: 32, height: 32)
                    .background(Color.green.opacity(0.2))
                    .clipShape(Circle())
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // メッセージバブル
                Text(message.content)
                    .font(.body)
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user ? Color.blue : Color(.systemGray5)
                    )
                    .cornerRadius(18)

                // タイムスタンプ
                Text(timeFormatter.string(from: message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .coach {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // コーチアバター
            Image(systemName: "tree")
                .font(.system(size: 20))
                .foregroundColor(.green)
                .frame(width: 32, height: 32)
                .background(Color.green.opacity(0.2))
                .clipShape(Circle())

            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .offset(y: animationOffset(for: index))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .cornerRadius(18)

            Spacer(minLength: 60)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true)
            ) {
                animationOffset = -5
            }
        }
    }

    private func animationOffset(for index: Int) -> CGFloat {
        let delay = Double(index) * 0.15
        return animationOffset * cos(delay * .pi)
    }
}

#Preview {
    CoachChatView()
        .environmentObject(CoachStore())
}
