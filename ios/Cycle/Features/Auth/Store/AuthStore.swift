//
//  AuthStore.swift
//  CycleJournal
//

import AuthenticationServices
import Foundation
import Security

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown
    case unauthenticated
    case authenticated(userId: String)

    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }
}

// MARK: - User Info

struct AuthUser: Codable, Equatable {
    let userId: String
    let appleUserId: String
    let email: String?
    let fullName: String?
    let createdAt: Date
}

// MARK: - Auth Store

@MainActor
class AuthStore: NSObject, ObservableObject {
    @Published var state: AuthState = .unknown
    @Published var currentUser: AuthUser?
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let authService = AuthService()
    private let keychainService = "com.cycle.journal.auth"
    private let tokenKey = "identityToken"
    private let userKey = "currentUser"

    override init() {
        super.init()
        Task {
            await checkAuthState()
        }
    }

    // MARK: - Public Methods

    /// Sign in with Appleを開始
    func signInWithApple() {
        isLoading = true
        error = nil

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    /// サインアウト
    func signOut() {
        deleteFromKeychain(key: tokenKey)
        deleteFromKeychain(key: userKey)
        APIClient.shared.setAuthToken(nil)
        currentUser = nil
        state = .unauthenticated
    }

    /// 認証状態を確認
    func checkAuthState() async {
        // 保存されているトークンを確認
        guard let token = loadFromKeychain(key: tokenKey) else {
            state = .unauthenticated
            return
        }

        // 保存されているユーザー情報を読み込み
        if let userData = loadDataFromKeychain(key: userKey),
           let user = try? JSONDecoder().decode(AuthUser.self, from: userData) {
            currentUser = user
            APIClient.shared.setAuthToken(token)
            state = .authenticated(userId: user.userId)

            // バックグラウンドでトークン検証（失敗してもローカルの状態は維持）
            Task {
                await validateToken(token)
            }
        } else {
            state = .unauthenticated
        }
    }

    // MARK: - Private Methods

    private func validateToken(_ token: String) async {
        do {
            let response = try await authService.verifyToken(token)

            // ユーザー情報を更新
            if let existingUser = currentUser {
                let updatedUser = AuthUser(
                    userId: response.userId,
                    appleUserId: response.appleUserId,
                    email: response.email ?? existingUser.email,
                    fullName: existingUser.fullName,
                    createdAt: existingUser.createdAt
                )
                currentUser = updatedUser
                saveUserToKeychain(updatedUser)
            }
        } catch {
            // トークンが無効な場合はサインアウト
            if case APIError.unauthorized = error {
                signOut()
            }
            print("Token validation failed: \(error)")
        }
    }

    private func handleSignInSuccess(credential: ASAuthorizationAppleIDCredential) async {
        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            self.error = "Identity Tokenの取得に失敗しました"
            self.isLoading = false
            return
        }

        do {
            // サーバーでトークンを検証
            let response = try await authService.verifyToken(identityToken)

            // ユーザー情報を作成
            let fullName: String? = {
                if let givenName = credential.fullName?.givenName,
                   let familyName = credential.fullName?.familyName {
                    return "\(familyName) \(givenName)"
                }
                return nil
            }()

            let user = AuthUser(
                userId: response.userId,
                appleUserId: response.appleUserId,
                email: response.email ?? credential.email,
                fullName: fullName,
                createdAt: Date()
            )

            // Keychainに保存
            saveToKeychain(key: tokenKey, value: identityToken)
            saveUserToKeychain(user)

            // APIClientにトークンを設定
            APIClient.shared.setAuthToken(identityToken)

            // 状態を更新
            currentUser = user
            state = .authenticated(userId: user.userId)
            isLoading = false

        } catch {
            self.error = error.localizedDescription
            self.state = .unauthenticated
            self.isLoading = false
        }
    }

    // MARK: - Keychain Operations

    private func saveToKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        saveDataToKeychain(key: key, data: data)
    }

    private func saveDataToKeychain(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]

        // 既存のアイテムを削除
        SecItemDelete(query as CFDictionary)

        // 新しいアイテムを追加
        var newQuery = query
        newQuery[kSecValueData as String] = data
        SecItemAdd(newQuery as CFDictionary, nil)
    }

    private func saveUserToKeychain(_ user: AuthUser) {
        if let data = try? JSONEncoder().encode(user) {
            saveDataToKeychain(key: userKey, data: data)
        }
    }

    private func loadFromKeychain(key: String) -> String? {
        guard let data = loadDataFromKeychain(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func loadDataFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthStore: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }

        Task { @MainActor in
            await handleSignInSuccess(credential: credential)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    // ユーザーがキャンセル - エラーを表示しない
                    break
                case .failed:
                    self.error = "認証に失敗しました"
                case .invalidResponse:
                    self.error = "無効な応答を受け取りました"
                case .notHandled:
                    self.error = "認証リクエストが処理されませんでした"
                case .notInteractive:
                    self.error = "認証に対話が必要です"
                case .unknown:
                    self.error = "不明なエラーが発生しました"
                @unknown default:
                    self.error = "エラーが発生しました"
                }
            } else {
                self.error = error.localizedDescription
            }
            self.isLoading = false
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthStore: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // iOS 15+ではシーンベースのウィンドウを使用
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
