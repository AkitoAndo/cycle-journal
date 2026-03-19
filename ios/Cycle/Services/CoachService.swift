//
//  CoachService.swift
//  CycleJournal
//

import Foundation

class CoachService {
    private let apiClient = APIClient.shared

    // MARK: - Coach Chat

    /// コーチにメッセージを送信
    func sendMessage(
        message: String,
        sessionId: String? = nil,
        diaryContent: String? = nil,
        cycleElement: String? = nil
    ) async throws -> CoachResponseData {
        let request = CoachRequest(
            message: message,
            sessionId: sessionId,
            diaryContent: diaryContent,
            context: cycleElement != nil ? CoachContext(cycleElement: cycleElement) : nil
        )

        let response: APIResponse<CoachResponseData> = try await apiClient.post(
            path: "/coach",
            body: request,
            requiresAuth: false // TODO: トークン更新機能実装後にtrueに変更
        )

        return response.data
    }

    // MARK: - Sessions

    /// セッション一覧を取得
    func getSessions(limit: Int = 20, offset: Int = 0) async throws -> SessionListData {
        let queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        let response: APIResponse<SessionListData> = try await apiClient.get(
            path: "/sessions",
            queryItems: queryItems,
            requiresAuth: false // TODO: 認証実装後にtrueに変更
        )

        return response.data
    }

    /// セッションを作成
    func createSession(
        title: String? = nil,
        diaryContent: String? = nil,
        cycleElement: String? = nil
    ) async throws -> SessionData {
        let request = CreateSessionRequest(
            title: title,
            diaryContent: diaryContent,
            cycleElement: cycleElement
        )

        let response: APIResponse<SessionData> = try await apiClient.post(
            path: "/sessions",
            body: request,
            requiresAuth: false // TODO: 認証実装後にtrueに変更
        )

        return response.data
    }

    /// セッション詳細を取得
    func getSession(sessionId: String) async throws -> SessionDetailData {
        let response: APIResponse<SessionDetailData> = try await apiClient.get(
            path: "/sessions/\(sessionId)",
            requiresAuth: false // TODO: 認証実装後にtrueに変更
        )

        return response.data
    }
}
