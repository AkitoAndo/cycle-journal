//
//  APIE2ETests.swift
//  CycleTests
//
//  E2E tests against the real Cloud Run API.
//  These tests hit the live dev server and verify real responses.
//

import Testing
import Foundation
@testable import Cycle

// MARK: - Health E2E

struct HealthE2ETests {
    @Test func healthEndpointReturns200() async throws {
        let response: HealthData = try await APIClient.shared.get(
            path: "/health",
            requiresAuth: false
        )
        #expect(response.status == "healthy")
        #expect(response.stage == "dev")
        #expect(!response.timestamp.isEmpty)
    }
}

// MARK: - Auth E2E

struct AuthE2ETests {
    @Test func verifyWithEmptyTokenReturnsError() async {
        do {
            let _: APIResponse<AuthVerifyResponse> = try await APIClient.shared.post(
                path: "/auth/verify",
                body: AuthVerifyRequest(identityToken: ""),
                requiresAuth: false
            )
            Issue.record("空トークンでエラーが返るべき")
        } catch let error as APIError {
            // 400 or 422 expected
            switch error {
            case .validationError:
                break // OK
            case .httpError(let statusCode, _):
                #expect(statusCode == 400 || statusCode == 422)
            default:
                Issue.record("予期しないエラー種別: \(error)")
            }
        } catch {
            Issue.record("予期しないエラー: \(error)")
        }
    }

    @Test func verifyWithInvalidTokenReturns401() async {
        do {
            let _: APIResponse<AuthVerifyResponse> = try await APIClient.shared.post(
                path: "/auth/verify",
                body: AuthVerifyRequest(identityToken: "invalid.jwt.token"),
                requiresAuth: false
            )
            Issue.record("不正トークンでエラーが返るべき")
        } catch let error as APIError {
            switch error {
            case .httpError(let statusCode, _):
                #expect(statusCode == 401)
            case .unauthorized:
                break // OK
            default:
                Issue.record("予期しないエラー種別: \(error)")
            }
        } catch {
            Issue.record("予期しないエラー: \(error)")
        }
    }
}

// MARK: - Coach E2E (requires auth)

struct CoachE2ETests {
    @Test func coachWithoutAuthReturns401() async {
        // Clear any existing token
        APIClient.shared.setAuthToken(nil)

        do {
            let _: APIResponse<CoachResponseData> = try await APIClient.shared.post(
                path: "/coach",
                body: CoachRequest(
                    message: "テスト",
                    sessionId: nil,
                    diaryContent: nil,
                    context: nil
                ),
                requiresAuth: true
            )
            Issue.record("認証なしでエラーが返るべき")
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                break // OK
            case .httpError(let statusCode, _):
                #expect(statusCode == 401)
            default:
                Issue.record("予期しないエラー種別: \(error)")
            }
        } catch {
            Issue.record("予期しないエラー: \(error)")
        }
    }
}

// MARK: - Sessions E2E (requires auth)

struct SessionsE2ETests {
    @Test func listSessionsWithoutAuthReturns401() async {
        APIClient.shared.setAuthToken(nil)

        do {
            let _: APIResponse<SessionListData> = try await APIClient.shared.get(
                path: "/sessions",
                requiresAuth: true
            )
            Issue.record("認証なしでエラーが返るべき")
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                break // OK
            case .httpError(let statusCode, _):
                #expect(statusCode == 401)
            default:
                Issue.record("予期しないエラー種別: \(error)")
            }
        } catch {
            Issue.record("予期しないエラー: \(error)")
        }
    }
}

// MARK: - Tasks E2E (requires auth)

struct TasksE2ETests {
    @Test func listTasksWithoutAuthReturns401() async {
        APIClient.shared.setAuthToken(nil)

        do {
            let _: APIResponse<TaskListData> = try await APIClient.shared.get(
                path: "/tasks",
                requiresAuth: true
            )
            Issue.record("認証なしでエラーが返るべき")
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                break // OK
            case .httpError(let statusCode, _):
                #expect(statusCode == 401)
            default:
                Issue.record("予期しないエラー種別: \(error)")
            }
        } catch {
            Issue.record("予期しないエラー: \(error)")
        }
    }
}

// MARK: - Users E2E (requires auth)

struct UsersE2ETests {
    @Test func getMeWithoutAuthReturns401() async {
        APIClient.shared.setAuthToken(nil)

        do {
            let _: APIResponse<UserData> = try await APIClient.shared.get(
                path: "/users/me",
                requiresAuth: true
            )
            Issue.record("認証なしでエラーが返るべき")
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                break // OK
            case .httpError(let statusCode, _):
                #expect(statusCode == 401)
            default:
                Issue.record("予期しないエラー種別: \(error)")
            }
        } catch {
            Issue.record("予期しないエラー: \(error)")
        }
    }
}
