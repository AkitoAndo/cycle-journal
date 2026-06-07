//
//  CoachService.swift
//  CycleJournal
//

import Foundation

enum CoachStreamEvent {
    case session(String)
    case chunk(String)
    case error(String)
    case done
}

class CoachService {
    private let apiClient = APIClient.shared

    // MARK: - Coach Chat

    /// コーチにメッセージを送信 (legacy 同期版)
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
            requiresAuth: true
        )

        return response.data
    }

    /// `/coach/stream` の SSE を AsyncThrowingStream で配信する
    func sendMessageStream(
        message: String,
        sessionId: String? = nil,
        diaryContent: String? = nil,
        cycleElement: String? = nil
    ) -> AsyncThrowingStream<CoachStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = CoachRequest(
                        message: message,
                        sessionId: sessionId,
                        diaryContent: diaryContent,
                        context: cycleElement != nil ? CoachContext(cycleElement: cycleElement) : nil
                    )
                    let urlRequest = try apiClient.makeStreamingPostRequest(
                        path: "/coach/stream",
                        body: request
                    )
                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                        if http.statusCode == 401 {
                            continuation.finish(throwing: APIError.unauthorized)
                        } else {
                            continuation.finish(throwing: APIError.httpError(
                                statusCode: http.statusCode,
                                message: nil
                            ))
                        }
                        return
                    }

                    var currentEvent: String? = nil
                    var dataLines: [String] = []
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if line.isEmpty {
                            if let event = Self.makeEvent(name: currentEvent, dataLines: dataLines) {
                                continuation.yield(event)
                                if case .done = event {
                                    continuation.finish()
                                    return
                                }
                            }
                            currentEvent = nil
                            dataLines.removeAll(keepingCapacity: true)
                        } else if line.hasPrefix("event:") {
                            currentEvent = String(line.dropFirst(6)).trimmingCharacters(
                                in: .whitespaces
                            )
                        } else if line.hasPrefix("data:") {
                            dataLines.append(
                                String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            )
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func makeEvent(name: String?, dataLines: [String]) -> CoachStreamEvent? {
        let data = dataLines.joined(separator: "\n")
        guard let jsonData = data.data(using: .utf8) else { return nil }
        let dict = (try? JSONSerialization.jsonObject(with: jsonData)) as? [String: Any]
        switch name {
        case "session":
            if let sid = dict?["session_id"] as? String { return .session(sid) }
        case "error":
            return .error((dict?["reason"] as? String) ?? "unknown")
        case "done":
            return .done
        case nil:
            if let chunk = dict?["chunk"] as? String { return .chunk(chunk) }
        default:
            break
        }
        return nil
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
            requiresAuth: true
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
            requiresAuth: true
        )

        return response.data
    }

    /// セッション詳細を取得
    func getSession(sessionId: String) async throws -> SessionDetailData {
        let response: APIResponse<SessionDetailData> = try await apiClient.get(
            path: "/sessions/\(sessionId)",
            requiresAuth: true
        )

        return response.data
    }
}
