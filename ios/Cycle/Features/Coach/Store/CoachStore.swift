//
//  CoachStore.swift
//  CycleJournal
//

import Combine
import Foundation

extension Notification.Name {
    static let navigateToCoachChat = Notification.Name("navigateToCoachChat")
}

class CoachStore: ObservableObject {
    @Published var sessions: [CoachSession] = []
    @Published var currentSession: CoachSession?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var lastAPIError: APIError?
    @Published var showReauthPrompt: Bool = false
    /// ContentView → CoachHomeView へチャット画面を開くよう通知するフラグ
    @Published var shouldOpenChat: Bool = false

    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "CoachSessions"
    private let coachService = CoachService()

    /// APIを使用するかどうか（falseの場合やトークン未設定時はモックを使用）
    var useAPI: Bool {
        APIClient.shared.getAuthToken() != nil
    }

    init() {
        loadSessions()
    }

    // MARK: - Persistence

    func loadSessions() {
        if let data = userDefaults.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([CoachSession].self, from: data) {
            sessions = decoded.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            userDefaults.set(encoded, forKey: sessionsKey)
        }
    }

    // MARK: - Session Management

    /// 新しいセッションを開始
    func startNewSession(withContext context: String? = nil) -> CoachSession {
        let session = CoachSession()
        currentSession = session
        sessions.insert(session, at: 0)
        saveSessions()
        return session
    }

    /// 現在のセッションを終了
    func endCurrentSession() {
        guard var session = currentSession else { return }
        session.isActive = false
        session.updatedAt = Date()

        // サマリーを生成（最初のユーザーメッセージを使用）
        if session.summary == nil {
            session.summary = session.firstUserMessage
        }

        updateSession(session)
        currentSession = nil
    }

    /// セッションを更新
    func updateSession(_ session: CoachSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            sessions.sort { $0.updatedAt > $1.updatedAt }
            saveSessions()
        }
    }

    /// セッションを削除
    func deleteSession(_ session: CoachSession) {
        sessions.removeAll { $0.id == session.id }
        if currentSession?.id == session.id {
            currentSession = nil
        }
        saveSessions()
    }

    // MARK: - Message Management

    /// ユーザーメッセージを追加
    func addUserMessage(_ content: String) {
        guard var session = currentSession else { return }

        let message = CoachMessage(role: .user, content: content)
        session.messages.append(message)
        session.updatedAt = Date()
        currentSession = session
        updateSession(session)
    }

    /// コーチメッセージを追加
    func addCoachMessage(_ content: String, metadata: MessageMetadata? = nil) {
        guard var session = currentSession else { return }

        let message = CoachMessage(role: .coach, content: content, metadata: metadata)
        session.messages.append(message)
        session.updatedAt = Date()

        // 感情ラベルを更新
        if let emotion = metadata?.emotionDetected {
            session.emotionLabel = emotion
        }

        currentSession = session
        updateSession(session)
    }

    /// streaming 開始時に空のコーチメッセージを挿入する
    private func addEmptyCoachMessage() {
        guard var session = currentSession else { return }
        session.messages.append(CoachMessage(role: .coach, content: ""))
        session.updatedAt = Date()
        currentSession = session
    }

    /// streaming 中、最後のコーチメッセージの content を差し替える
    private func setLastCoachMessageContent(_ content: String) {
        guard var session = currentSession,
              let last = session.messages.last,
              last.role == .coach
        else { return }
        session.messages[session.messages.count - 1].content = content
        session.updatedAt = Date()
        currentSession = session
    }

    /// streaming が失敗した（または1文字も届かなかった）場合に、
    /// 空のままのコーチメッセージを会話から取り除く
    private func removeLastCoachMessageIfEmpty() {
        guard var session = currentSession,
              let last = session.messages.last,
              last.role == .coach,
              last.content.isEmpty
        else { return }
        session.messages.removeLast()
        session.updatedAt = Date()
        currentSession = session
        updateSession(session)
    }

    // MARK: - API Integration

    /// コーチに問いかける（API呼び出し、SSE streaming）
    func sendMessage(_ content: String) async {
        addUserMessage(content)

        await MainActor.run {
            isLoading = true
            error = nil
            lastAPIError = nil
        }

        do {
            if useAPI {
                try await streamCoachResponse(
                    message: content,
                    sessionId: currentSession?.serverId ?? currentSession?.id.uuidString
                )
                await MainActor.run {
                    isLoading = false
                }
            } else {
                // モックレスポンス（フォールバック）
                try await Task.sleep(nanoseconds: 1_000_000_000)

                let mockResponse = generateMockResponse(for: content)
                await MainActor.run {
                    addCoachMessage(mockResponse.content, metadata: mockResponse.metadata)
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run { handleCoachRequestFailure(error) }
        }
    }

    /// SSE 経由でコーチ応答を受信し、最後のコーチ吹き出しを逐次更新する
    private func streamCoachResponse(
        message: String,
        sessionId: String?,
        diaryContent: String? = nil
    ) async throws {
        await MainActor.run { addEmptyCoachMessage() }

        let stream = coachService.sendMessageStream(
            message: message,
            sessionId: sessionId,
            diaryContent: diaryContent
        )

        var accumulated = ""
        var receivedError: String?
        for try await event in stream {
            switch event {
            case .session(let sid):
                await MainActor.run {
                    if currentSession?.serverId == nil {
                        currentSession?.serverId = sid
                        if let current = currentSession { updateSession(current) }
                    }
                }
            case .chunk(let text):
                accumulated += text
                await MainActor.run { setLastCoachMessageContent(accumulated) }
            case .error(let reason):
                receivedError = reason
            case .done:
                break
            }
        }

        await MainActor.run {
            // 1文字も届かずに終わった場合は空の吹き出しを残さない
            if accumulated.isEmpty {
                removeLastCoachMessageIfEmpty()
                if receivedError == nil {
                    self.error = "コーチからの応答を受け取れませんでした。もう一度お試しください。"
                }
            }
            if let session = currentSession { updateSession(session) }
            if let reason = receivedError {
                self.error = "コーチ応答が中断されました (\(reason))"
            }
        }
    }

    @MainActor
    private func handleCoachRequestFailure(_ error: Error) {
        let isUserCancelled = error is CancellationError || (error as? URLError)?.code == .cancelled

        // 失敗時は空のままのコーチ吹き出しを会話から取り除く
        removeLastCoachMessageIfEmpty()
        if isUserCancelled {
            // ユーザーによる停止: 途中までの応答は残し、エラーにはしない
            if let session = currentSession { updateSession(session) }
        } else {
            let apiError = (error as? APIError) ?? .networkError(error)
            self.lastAPIError = apiError
            self.error = apiError.errorDescription
            if apiError.requiresReauth {
                self.showReauthPrompt = true
            }
        }
        isLoading = false
    }

    /// エラーを消去
    func clearError() {
        error = nil
        lastAPIError = nil
    }

    /// 日記を元にセッションを開始
    @MainActor
    func startSessionWithDiary(_ diaryContent: String) async {
        // 先にローディング状態にしてからセッションを作成
        isLoading = true
        error = nil
        lastAPIError = nil

        let session = startNewSession(withContext: diaryContent)
        currentSession = session

        do {
            if useAPI {
                // API呼び出し - 日記内容を含めて最初のメッセージをSSEで送信
                let initialUserMessage = "この日記について話したいです"
                addUserMessage(initialUserMessage)

                try await streamCoachResponse(
                    message: initialUserMessage,
                    sessionId: session.serverId ?? session.id.uuidString,
                    diaryContent: diaryContent
                )

                isLoading = false
            } else {
                // モックレスポンス
                let initialMessage = "日記を読ませてもらったよ。\n\n「\(diaryContent.prefix(50))...」\n\nこの中で、特に心に残っている部分はどこかな？"

                try await Task.sleep(nanoseconds: 500_000_000)

                addCoachMessage(initialMessage)
                isLoading = false
            }
        } catch {
            handleCoachRequestFailure(error)
        }
    }

    // MARK: - Mock Response Generator

    private func generateMockResponse(for input: String) -> (content: String, metadata: MessageMetadata?) {
        // モック用の応答パターン
        let responses: [(String, MessageMetadata?)] = [
            ("その気持ちの奥に、大切にしているものはあるかな？", MessageMetadata(cycleElement: "Root", emotionDetected: nil, suggestedAction: nil)),
            ("そう感じているんだね。もう少し詳しく教えてくれる？", MessageMetadata(cycleElement: "Water", emotionDetected: nil, suggestedAction: nil)),
            ("その体験から、どんなことに気づいた？", MessageMetadata(cycleElement: "Fruit", emotionDetected: nil, suggestedAction: nil)),
            ("次にもう一度試すとしたら、どこを少し変えてみたい？", MessageMetadata(cycleElement: "Trunk", emotionDetected: nil, suggestedAction: nil)),
        ]

        let index = abs(input.hashValue) % responses.count
        return responses[index]
    }

    // MARK: - Server Sync

    /// 自動同期の最小間隔。履歴シートを開くたびに `.task` が発火するため、
    /// これがないと毎回サーバを叩いてしまう
    private static let serverSyncMinInterval: TimeInterval = 300
    private var lastSessionsSyncAt: Date?

    /// サーバーからセッション履歴を取得してマージ
    /// - Parameter force: true なら鮮度チェックを無視して必ず同期する
    ///   （Pull-to-refresh などユーザーの明示操作用）
    func fetchServerSessions(force: Bool = false) async {
        #if DEBUG
        if CommandLine.arguments.contains("--uitesting") {
            return // UI テスト時はネットワーク同期しない（auth 状態を壊さないため）
        }
        #endif

        // 直近に同期済みなら自動同期はスキップ（サーバ負荷とバッテリーの節約）
        if !force,
           let last = lastSessionsSyncAt,
           Date().timeIntervalSince(last) < Self.serverSyncMinInterval {
            return
        }

        await MainActor.run {
            isLoading = true
        }

        do {
            let serverList = try await coachService.getSessions(limit: 50)

            await MainActor.run {
                // サーバーにしか存在しないセッションをローカルに追加
                let localServerIds = Set(sessions.compactMap { $0.serverId })
                let newSessions = serverList.sessions
                    .filter { !localServerIds.contains($0.sessionId) }
                    .map { CoachSession.from($0) }

                if !newSessions.isEmpty {
                    sessions.append(contentsOf: newSessions)
                    sessions.sort { $0.updatedAt > $1.updatedAt }
                    saveSessions()
                }
                lastSessionsSyncAt = Date()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                let apiError = (error as? APIError) ?? .networkError(error)
                self.lastAPIError = apiError
                self.error = apiError.errorDescription
                if apiError.requiresReauth {
                    self.showReauthPrompt = true
                }
                isLoading = false
            }
        }
    }

    /// サーバーからセッション詳細（メッセージ付き）を取得
    func fetchSessionDetail(_ session: CoachSession) async -> CoachSession? {
        guard let serverId = session.serverId else { return nil }

        do {
            let detail = try await coachService.getSession(sessionId: serverId)
            let fullSession = CoachSession.from(detail)

            await MainActor.run {
                // ローカルのセッションを更新
                if let index = sessions.firstIndex(where: { $0.serverId == serverId }) {
                    sessions[index].messages = fullSession.messages
                    sessions[index].updatedAt = fullSession.updatedAt
                    saveSessions()
                }
            }

            return fullSession
        } catch {
            await MainActor.run {
                let apiError = (error as? APIError) ?? .networkError(error)
                self.lastAPIError = apiError
                self.error = apiError.errorDescription
            }
            return nil
        }
    }

    // MARK: - Computed Properties

    /// アクティブなセッションがあるか
    var hasActiveSession: Bool {
        currentSession != nil
    }

    /// 最近のセッション（最大5件）
    var recentSessions: [CoachSession] {
        Array(sessions.filter { !$0.isActive }.prefix(5))
    }
}
