//
//  CoachStore.swift
//  CycleJournal
//

import Foundation

class CoachStore: ObservableObject {
    @Published var sessions: [CoachSession] = []
    @Published var currentSession: CoachSession?
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "CoachSessions"
    private let coachService = CoachService()

    /// APIを使用するかどうか（falseの場合はモックを使用）
    var useAPI: Bool = true

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

    // MARK: - API Integration

    /// コーチに問いかける（API呼び出し）
    func sendMessage(_ content: String) async {
        addUserMessage(content)

        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            if useAPI {
                // API呼び出し
                let response = try await coachService.sendMessage(
                    message: content,
                    sessionId: currentSession?.id.uuidString
                )

                let metadata = MessageMetadata(
                    cycleElement: response.metadata?.cycleElement,
                    emotionDetected: response.metadata?.detectedEmotion,
                    suggestedAction: nil
                )

                await MainActor.run {
                    addCoachMessage(response.message, metadata: metadata)
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
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    /// 日記を元にセッションを開始
    @MainActor
    func startSessionWithDiary(_ diaryContent: String) async {
        // 先にローディング状態にしてからセッションを作成
        isLoading = true
        error = nil

        let session = startNewSession(withContext: diaryContent)
        currentSession = session

        do {
            if useAPI {
                // API呼び出し - 日記内容を含めて最初のメッセージを送信
                let initialUserMessage = "この日記について話したいです"
                addUserMessage(initialUserMessage)

                let response = try await coachService.sendMessage(
                    message: initialUserMessage,
                    sessionId: session.id.uuidString,
                    diaryContent: diaryContent
                )

                let metadata = MessageMetadata(
                    cycleElement: response.metadata?.cycleElement,
                    emotionDetected: response.metadata?.detectedEmotion,
                    suggestedAction: nil
                )

                addCoachMessage(response.message, metadata: metadata)
                isLoading = false
            } else {
                // モックレスポンス
                let initialMessage = "日記を読ませてもらったよ。\n\n「\(diaryContent.prefix(50))...」\n\nこの中で、特に心に残っている部分はどこかな？"

                try await Task.sleep(nanoseconds: 500_000_000)

                addCoachMessage(initialMessage)
                isLoading = false
            }
        } catch {
            // エラー時はモックレスポンスを返す
            let initialMessage = "日記を読ませてもらったよ。\n\n「\(diaryContent.prefix(50))...」\n\nこの中で、特に心に残っている部分はどこかな？"

            self.error = error.localizedDescription
            addCoachMessage(initialMessage)
            isLoading = false
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
