//
//  OnboardingNotificationPermissionView.swift
//  CycleJournal
//
//  Issue #37 C-2: 最初のジャーナル保存直後の "value moment" で通知 opt-in を行う pre-permission シート.
//

import SwiftUI

struct OnboardingNotificationPermissionView: View {
    @EnvironmentObject private var flow: OnboardingFlow
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 16) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("そっと背中を押させてください")
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("毎朝、今日のジャーナルを書くきっかけと、AI コーチからの問いかけをお届けします。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await requestPermission() }
                } label: {
                    HStack {
                        if isRequesting { ProgressView().tint(.white).padding(.trailing, 8) }
                        Text("通知を受け取る")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isRequesting)

                Button("あとで設定する") { flow.advance() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }

    private func requestPermission() async {
        isRequesting = true
        defer { isRequesting = false }
        _ = await NotificationManager.shared.requestPermission()
        flow.advance()
    }
}
