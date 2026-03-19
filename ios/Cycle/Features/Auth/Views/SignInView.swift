//
//  SignInView.swift
//  CycleJournal
//

import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authStore: AuthStore

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // アプリロゴ
            appLogo

            // アプリ説明
            appDescription

            Spacer()

            // Sign in with Apple ボタン
            signInButton

            // エラー表示
            if let error = authStore.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // ローディング表示
            if authStore.isLoading {
                ProgressView()
                    .padding()
            }

            Spacer()
                .frame(height: 40)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Components

    private var appLogo: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "tree")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }

            Text("Cycle")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }

    private var appDescription: some View {
        VStack(spacing: 12) {
            Text("自分と向き合う日記アプリ")
                .font(.title3)
                .fontWeight(.medium)

            Text("日記を書き、振り返り、\n成長のサイクルを回そう")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var signInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { _ in
            // Delegateパターンで処理するため、ここでは何もしない
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .cornerRadius(8)
        .padding(.horizontal, 40)
        .onTapGesture {
            authStore.signInWithApple()
        }
        .disabled(authStore.isLoading)
        .opacity(authStore.isLoading ? 0.6 : 1.0)
    }
}

// MARK: - Custom Sign In Button (Alternative)

struct CustomSignInWithAppleButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.title3)
                Text("Appleでサインイン")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
            .cornerRadius(8)
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthStore())
}
