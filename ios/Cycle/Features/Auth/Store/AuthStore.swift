//
//  AuthStore.swift
//  CycleJournal
//

import AuthenticationServices
import Combine
import Foundation
import GoogleSignIn
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

// MARK: - Auth Provider

enum AuthProvider: String, Codable {
    case apple
    case google
}

// MARK: - User Info

struct AuthUser: Codable, Equatable {
    let userId: String
    let appleUserId: String?
    let googleUserId: String?
    let email: String?
    let fullName: String?
    let createdAt: Date
    let provider: AuthProvider

    // 後方互換: appleUserId は以前は非Optional
    init(userId: String, appleUserId: String? = nil, googleUserId: String? = nil, email: String?, fullName: String?, createdAt: Date, provider: AuthProvider = .apple) {
        self.userId = userId
        self.appleUserId = appleUserId
        self.googleUserId = googleUserId
        self.email = email
        self.fullName = fullName
        self.createdAt = createdAt
        self.provider = provider
    }
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

    /// Google Sign-Inを開始
    func signInWithGoogle() {
        isLoading = true
        error = nil

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = scene.windows.first?.rootViewController else {
            self.error = "画面の取得に失敗しました"
            self.isLoading = false
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    // キャンセルの場合はエラーを表示しない
                    if (error as NSError).code == GIDSignInError.canceled.rawValue {
                        self.isLoading = false
                        return
                    }
                    self.error = error.localizedDescription
                    self.isLoading = false
                    return
                }

                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.error = "Google ID Tokenの取得に失敗しました"
                    self.isLoading = false
                    return
                }

                let fullName = user.profile?.name
                let email = user.profile?.email

                await self.handleGoogleSignIn(idToken: idToken, fullName: fullName, email: email)
            }
        }
    }

    /// Google Sign-Inの結果を処理（Google Sign-In SDKのコールバックから呼ぶ）
    func handleGoogleSignIn(idToken: String, fullName: String?, email: String?) async {
        isLoading = true
        error = nil

        do {
            let response = try await authService.verifyGoogleToken(idToken)

            let user = AuthUser(
                userId: response.userId,
                googleUserId: response.googleUserId,
                email: response.email ?? email,
                fullName: fullName,
                createdAt: Date(),
                provider: .google
            )

            saveToKeychain(key: tokenKey, value: idToken)
            saveUserToKeychain(user)
            APIClient.shared.setAuthToken(idToken)

            currentUser = user
            state = .authenticated(userId: user.userId)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            self.state = .unauthenticated
            self.isLoading = false
        }
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
        guard let token = loadFromKeychain(key: tokenKey) else {
            state = .unauthenticated
            return
        }

        if let userData = loadDataFromKeychain(key: userKey),
           let user = try? JSONDecoder().decode(AuthUser.self, from: userData) {
            currentUser = user
            APIClient.shared.setAuthToken(token)
            state = .authenticated(userId: user.userId)

            Task {
                await validateToken(token, provider: user.provider)
            }
        } else {
            state = .unauthenticated
        }
    }

    // MARK: - Private Methods

    private func validateToken(_ token: String, provider: AuthProvider = .apple) async {
        do {
            let response: AuthVerifyResponse
            switch provider {
            case .apple:
                response = try await authService.verifyToken(token)
            case .google:
                response = try await authService.verifyGoogleToken(token)
            }

            if let existingUser = currentUser {
                let updatedUser = AuthUser(
                    userId: response.userId,
                    appleUserId: response.appleUserId,
                    googleUserId: response.googleUserId,
                    email: response.email ?? existingUser.email,
                    fullName: existingUser.fullName,
                    createdAt: existingUser.createdAt,
                    provider: provider
                )
                currentUser = updatedUser
                saveUserToKeychain(updatedUser)
            }
        } catch {
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
            let response = try await authService.verifyToken(identityToken)

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
                createdAt: Date(),
                provider: .apple
            )

            saveToKeychain(key: tokenKey, value: identityToken)
            saveUserToKeychain(user)
            APIClient.shared.setAuthToken(identityToken)

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

        SecItemDelete(query as CFDictionary)

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
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
