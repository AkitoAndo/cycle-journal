//
//  OnboardingPaywallView.swift
//  CycleJournal
//
//  Issue #37 C-1: オンボーディング最終ステップとして Paywall を提示するラッパー.
//

import SwiftUI

struct OnboardingPaywallView: View {
    @EnvironmentObject private var flow: OnboardingFlow

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PaywallView()
            // オンボーディング中は閉じるボタンを出さず、購入完了 or
            // ユーザーが明示的にスキップしたときのみ advance する
            Button("スキップ") { flow.advance() }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(16)
        }
    }
}
