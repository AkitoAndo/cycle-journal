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
    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"
    private let legacyTokenKey = "identityToken"
    private let userKey = "currentUser"

    override init() {
        super.init()
        APIClient.shared.setTokenRefresher { [weak self] in
            try await self?.refreshAccessToken() ?? ""
        }
        Task {
            await checkAuthState()
        }
    }

    // MARK: - Public Methods

    /// Sign in with Appleを開始（自前で ASAuthorizationController を立てる経路）
    /// SettingsView の Button から呼ばれる。SignInView は SignInWithAppleButton 経由で
    /// `handleAppleAuthorization(_:)` を使う。
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

    /// `SignInWithAppleButton` の onCompletion から呼ぶ。
    /// 成功時は credential を取り出して既存の sign-in 成功処理に流す。
    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        error = nil

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                self.error = "認証情報の取得に失敗しました"
                self.isLoading = false
                return
            }
            await handleSignInSuccess(credential: credential)

        case .failure(let error):
            applyAuthorizationError(error)
            self.isLoading = false
        }
    }

    private func applyAuthorizationError(_ error: Error) {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                return
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
            default:
                self.error = "エラーが発生しました"
            }
        } else {
            self.error = error.localizedDescription
        }
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

    /// Google Sign-Inの結果を処理
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

            persistSession(user: user, accessToken: response.accessToken, refreshToken: response.refreshToken)

            currentUser = user
            state = .authenticated(userId: user.userId)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            self.state = .unauthenticated
            self.isLoading = false
        }
    }

    /// サインアウト: サーバーrefresh token無効化 + ローカル削除 + Google SDK sign out
    func signOut() {
        if let refreshToken = loadFromKeychain(key: refreshTokenKey) {
            Task {
                try? await authService.logout(refreshToken: refreshToken)
            }
        }
        GIDSignIn.sharedInstance.signOut()
        clearLocalAuth()
    }

    /// アカウントを完全に削除する。
    /// サーバ側で Apple revoke + Firestore データ全削除を行ったのち、ローカルもクリアする。
    /// 失敗時は `error` をセットして isLoading を戻すだけで、認証状態は維持する。
    func deleteAccount() async {
        isLoading = true
        error = nil

        do {
            try await authService.deleteAccount()
        } catch {
            self.error = "アカウントの削除に失敗しました: \(error.localizedDescription)"
            self.isLoading = false
            return
        }

        GIDSignIn.sharedInstance.signOut()
        clearLocalAuth()
        isLoading = false
    }

    /// 認証状態を確認
    func checkAuthState() async {
        #if DEBUG
        if CommandLine.arguments.contains("--uitesting") {
            // 過去の実サインインで残った Keychain 資格情報を無視し、
            // 常に決定的なモック認証状態にする。
            // ネットワークは APIClient 側がオフライン化するため、
            // ここでは API トークンを設定しない（useAPI を false に保ち、
            // コーチがモック応答を返すようにする）。
            currentUser = AuthUser(
                userId: "ui-test-user",
                appleUserId: nil,
                googleUserId: nil,
                email: "uitest@example.com",
                fullName: nil,
                createdAt: Date(),
                provider: .apple
            )
            state = .authenticated(userId: "ui-test-user")
            return
        }

        // [0710] サインイン一時バイパス（DEBUGのみ）。モック認証で直接メイン画面へ。
        // API は APIClient.debugAuthBypass により全て offline 扱いになるため、
        // サーバー依存機能（コーチ実応答・同期）はモック/オフライン動作。
        // 元に戻すときは APIClient.debugAuthBypass を false にする。
        if APIClient.debugAuthBypass {
            currentUser = AuthUser(
                userId: "debug-user",
                appleUserId: nil,
                googleUserId: nil,
                email: "debug@example.com",
                fullName: nil,
                createdAt: Date(),
                provider: .apple
            )
            state = .authenticated(userId: "debug-user")
            return
        }
        #endif

        // 旧バージョンからアップデートしたユーザー: identityToken のみ → 再サインイン要求
        if loadFromKeychain(key: accessTokenKey) == nil, loadFromKeychain(key: legacyTokenKey) != nil {
            clearLocalAuth()
            return
        }

        guard let accessToken = loadFromKeychain(key: accessTokenKey) else {
            state = .unauthenticated
            return
        }

        guard let userData = loadDataFromKeychain(key: userKey),
              let user = try? JSONDecoder().decode(AuthUser.self, from: userData) else {
            clearLocalAuth()
            return
        }

        currentUser = user
        APIClient.shared.setAuthToken(accessToken)
        Task { await SubscriptionService().registerStoredAPNsDeviceTokenIfAvailable() }
        state = .authenticated(userId: user.userId)
    }

    // MARK: - Token Refresh

    /// Refresh tokenで新しいアクセストークンを取得。
    /// APIClientから呼ばれる。失敗時はサインアウト状態に遷移して例外を投げる。
    func refreshAccessToken() async throws -> String {
        guard let refreshToken = loadFromKeychain(key: refreshTokenKey) else {
            clearLocalAuth()
            throw APIError.unauthorized
        }

        do {
            let response = try await authService.refresh(refreshToken: refreshToken)
            saveToKeychain(key: accessTokenKey, value: response.accessToken)
            saveToKeychain(key: refreshTokenKey, value: response.refreshToken)
            APIClient.shared.setAuthToken(response.accessToken)
            return response.accessToken
        } catch {
            clearLocalAuth()
            throw error
        }
    }

    // MARK: - Private Methods

    private func persistSession(user: AuthUser, accessToken: String, refreshToken: String) {
        saveToKeychain(key: accessTokenKey, value: accessToken)
        saveToKeychain(key: refreshTokenKey, value: refreshToken)
        saveUserToKeychain(user)
        deleteFromKeychain(key: legacyTokenKey)
        APIClient.shared.setAuthToken(accessToken)
        Task { await SubscriptionService().registerStoredAPNsDeviceTokenIfAvailable() }
    }

    private func clearLocalAuth() {
        deleteFromKeychain(key: accessTokenKey)
        deleteFromKeychain(key: refreshTokenKey)
        deleteFromKeychain(key: legacyTokenKey)
        deleteFromKeychain(key: userKey)
        APIClient.shared.setAuthToken(nil)
        currentUser = nil
        state = .unauthenticated
    }

    private func handleSignInSuccess(credential: ASAuthorizationAppleIDCredential) async {
        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            self.error = "Identity Tokenの取得に失敗しました"
            self.isLoading = false
            return
        }

        // authorization_code はアカウント削除時の Apple revoke に必要なのでサーバへ送る。
        let authorizationCode = credential.authorizationCode
            .flatMap { String(data: $0, encoding: .utf8) }

        do {
            let response = try await authService.verifyToken(
                identityToken,
                authorizationCode: authorizationCode
            )

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

            persistSession(user: user, accessToken: response.accessToken, refreshToken: response.refreshToken)

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
            self.applyAuthorizationError(error)
            self.isLoading = false
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthStore: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // システムはメインスレッドで呼び出すため MainActor として扱ってよい
        MainActor.assumeIsolated {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first else {
                return UIWindow()
            }
            return window
        }
    }
}
