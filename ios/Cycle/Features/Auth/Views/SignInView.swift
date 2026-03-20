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

            // サインインボタン
            VStack(spacing: 12) {
                appleSignInButton
                googleSignInButton
            }

            // エラー表示
            if let error = authStore.error {
                Text(error)
                    .font(DesignSystem.Fonts.caption)
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
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Components

    private var appLogo: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.Colors.accentLight.opacity(0.5), DesignSystem.Colors.accentLight.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "tree")
                    .font(DesignSystem.Fonts.heroIcon)
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            Text("Cycle")
                .font(DesignSystem.Fonts.largeTitle)
                .fontWeight(.bold)
        }
    }

    private var appDescription: some View {
        VStack(spacing: 12) {
            Text("自分と向き合う日記アプリ")
                .font(DesignSystem.Fonts.sectionTitle)
                .fontWeight(.medium)

            Text("日記を書き、振り返り、\n成長のサイクルを回そう")
                .font(DesignSystem.Fonts.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var appleSignInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { _ in }
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

    private var googleSignInButton: some View {
        Button(action: { authStore.signInWithGoogle() }) {
            HStack(spacing: 8) {
                Image(systemName: "g.circle.fill")
                    .font(DesignSystem.Fonts.sectionTitle)
                Text("Googleでサインイン")
                    .font(DesignSystem.Fonts.button)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(red: 0.26, green: 0.52, blue: 0.96))
            .cornerRadius(8)
        }
        .padding(.horizontal, 40)
        .disabled(authStore.isLoading)
        .opacity(authStore.isLoading ? 0.6 : 1.0)
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthStore())
}
