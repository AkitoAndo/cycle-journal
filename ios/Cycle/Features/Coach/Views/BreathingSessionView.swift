//
//  BreathingSessionView.swift
//  CycleJournal
//

import SwiftUI
import UIKit
import StoreKit

struct BreathingSessionView: View {
    @EnvironmentObject var meditationStore: MeditationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @State private var selectedDuration = 300
    @State private var isRunning = false
    @State private var isCompleted = false
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var startedAt: Date?
    @State private var timer: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let durationOptions = [60, 180, 300]
    private let timerInterval: TimeInterval = 0.1

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: DesignSystem.Spacing.xxl)

                if isCompleted {
                    completedView
                } else {
                    breathingView
                }

                Spacer(minLength: DesignSystem.Spacing.xxl)

                controls
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xxl * 2)
            }
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isRunning {
                        Button("閉じる") {
                            dismiss()
                        }
                        .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }
            }
            .onDisappear {
                stopTimer()
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onChange(of: isRunning) { _, running in
                UIApplication.shared.isIdleTimerDisabled = running
            }
            .interactiveDismissDisabled(isRunning)
        }
    }

    private var breathingView: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            ZStack {
                // 呼吸の広がりの目安となるガイドリング（内=通常時、外=吸い切り時）
                Circle()
                    .stroke(DesignSystem.Colors.accent.opacity(0.08), lineWidth: 1)
                    .frame(width: 230, height: 230)

                Circle()
                    .stroke(DesignSystem.Colors.accent.opacity(0.14), lineWidth: 1)
                    .frame(width: 170, height: 170)

                if isRunning {
                    // セッション中: 呼吸フェーズに合わせて拡縮
                    breathCircle(scale: circleScale, glow: (circleScale - 1.0) * 2)
                        .animation(.linear(duration: timerInterval), value: circleScale)
                } else if reduceMotion {
                    breathCircle(scale: 1.02, glow: 0.3)
                } else {
                    // 待機中: セッション画面と同じ正弦波駆動で
                    // ゆったりと満ち引きする（周期6.4秒）
                    TimelineView(.animation) { context in
                        let p = idleBreathPhase(at: context.date)
                        breathCircle(scale: 1.0 + 0.05 * p, glow: 0.2 + 0.4 * p)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("呼吸フェーズ")
            .accessibilityValue(
                isRunning
                    ? "\(currentPhase.accessibilityDescription)、残り\(remainingTimeString)"
                    : "瞑想時間の選択中"
            )

            VStack(spacing: DesignSystem.Spacing.sm) {
                // タイトル行はセッション前後で高さが変わらないよう固定
                Group {
                    if isRunning {
                        Text(currentPhase.title)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    } else {
                        Text("準備ができたら、はじめよう")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                .frame(height: 30)

                Text(remainingTimeString)
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                isRunning
                    ? "\(currentPhase.accessibilityDescription)、残り\(remainingTimeString)"
                    : "瞑想時間 \(remainingTimeString)"
            )
        }
    }

    // MARK: - 呼吸サークル

    /// 待機中の呼吸フェーズ（0〜1）。セッション画面のハローと同じテンポ
    private func idleBreathPhase(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate / 6.4
        return (sin(t * 2 * .pi - .pi / 2) + 1) / 2
    }

    /// 呼吸に合わせて拡縮する中央サークル + アイコン。
    /// 放射グラデーションで縁を柔らかくぼかし、拡張時はグロウで明るくなる
    private func breathCircle(scale: Double, glow: Double) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            DesignSystem.Colors.accent.opacity(0.16),
                            DesignSystem.Colors.accent.opacity(0.10),
                            DesignSystem.Colors.accent.opacity(0.02)
                        ],
                        center: .center,
                        startRadius: 24,
                        endRadius: 82
                    )
                )
                .frame(width: 156, height: 156)
                .scaleEffect(scale)

            Circle()
                .stroke(DesignSystem.Colors.accent.opacity(0.24), lineWidth: 1.5)
                .frame(width: 156, height: 156)
                .scaleEffect(scale)

            Image("CycleIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .opacity(0.94)
                // サークルより控えめに連動して奥行きを出す
                .scaleEffect(1.0 + (scale - 1.0) * 0.3)
                .shadow(
                    color: DesignSystem.Colors.accent.opacity(0.08 + 0.16 * min(max(glow, 0), 1)),
                    radius: 12
                )
        }
    }

    private var completedView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.accent)

            Text("\(completedDurationString)の瞑想を記録しました")
                .font(DesignSystem.Fonts.sectionTitle)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .onAppear { maybeRequestReview() }
    }

    /// セッション完了というポジティブな瞬間にだけ、控えめにレビューを依頼する。
    /// 2回目と10回目の完了時のみ（OS 側でも年3回までに制限される）
    private func maybeRequestReview() {
        guard !TestDataProvider.isUITesting else { return }

        let key = "breathingCompletedCount"
        let count = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(count, forKey: key)

        guard count == 2 || count == 10 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            requestReview()
        }
    }

    @ViewBuilder
    private var controls: some View {
        if isCompleted {
            PrimaryButton("完了") {
                dismiss()
            }
        } else {
            VStack(spacing: DesignSystem.Spacing.lg) {
                if !isRunning {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("セッション時間")
                                .font(DesignSystem.Fonts.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)

                            Spacer()

                            Text(durationLabel(for: selectedDuration))
                                .font(DesignSystem.Fonts.caption)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }

                        Picker("セッション時間", selection: $selectedDuration) {
                            ForEach(durationOptions, id: \.self) { duration in
                                Text(durationLabel(for: duration)).tag(duration)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if isRunning {
                    SecondaryButton("終わる") {
                        finishSession()
                    }
                } else {
                    PrimaryButton("はじめる") {
                        startSession()
                    }
                }
            }
        }
    }

    private var currentPhase: BreathingPhase {
        BreathingCycle.phase(at: elapsedSeconds)
    }

    private var circleScale: Double {
        BreathingCycle.circleScale(at: elapsedSeconds)
    }

    private var remainingSeconds: Int {
        max(Int(ceil(TimeInterval(selectedDuration) - elapsedSeconds)), 0)
    }

    private var remainingTimeString: String {
        formatDuration(remainingSeconds)
    }

    private var completedDurationString: String {
        formatDuration(max(Int(elapsedSeconds), 0))
    }

    private func startSession() {
        elapsedSeconds = 0
        startedAt = Date()
        isRunning = true
        isCompleted = false

        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            updateElapsedTime()
        }
    }

    private func updateElapsedTime() {
        refreshElapsedTime()

        if elapsedSeconds >= TimeInterval(selectedDuration) {
            hapticFeedback()
            finishSession()
        }
    }

    private func refreshElapsedTime() {
        guard let startedAt else { return }
        elapsedSeconds = min(Date().timeIntervalSince(startedAt), TimeInterval(selectedDuration))
    }

    private func finishSession() {
        refreshElapsedTime()
        stopTimer()

        let elapsed = elapsedSeconds > 0 ? max(Int(ceil(elapsedSeconds)), 1) : 0
        elapsedSeconds = TimeInterval(elapsed)
        if elapsed > 0 {
            meditationStore.addLog(duration: elapsed)
        }
        isCompleted = true
        isRunning = false
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func durationLabel(for seconds: Int) -> String {
        formatDuration(seconds)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if minutes > 0 && remainingSeconds > 0 {
            return "\(minutes):\(String(format: "%02d", remainingSeconds))"
        }
        if minutes > 0 {
            return "\(minutes)分"
        }
        return "\(remainingSeconds)秒"
    }

    private func hapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

#Preview {
    BreathingSessionView()
        .environmentObject(MeditationStore())
}
