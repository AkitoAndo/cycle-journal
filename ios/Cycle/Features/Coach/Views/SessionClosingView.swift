//
//  SessionClosingView.swift
//  Cycle
//
//  対話の終わりに出す「まとめ」画面（U-03 対話→一歩 / C-10 まとめ画面）。
//  本人の言葉で「今回の気づき」と「次の一歩」を残し、一歩は「今日の一歩に追加」でタスクになる。
//  どちらも空のまま「終える」でもよい（立ち止まる選択）。評価や達成の演出はしない。
//

import SwiftUI

struct SessionClosingView: View {
    @EnvironmentObject private var coachStore: CoachStore
    @EnvironmentObject private var taskViewModel: TaskViewModel
    @Environment(\.dismiss) private var dismiss

    /// まとめを書き終えて対話を閉じるとき（親が対話画面を閉じる）
    let onFinish: () -> Void

    @State private var insight = ""
    @State private var nextStep = ""
    @State private var addAsStep = true
    @FocusState private var focused: Field?

    private enum Field { case insight, nextStep }

    private var trimmedStep: String {
        nextStep.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("ここまで話したことを、ひとことで残しておこう。\n書かなくても大丈夫。")
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    field(
                        title: "今回の気づき",
                        placeholder: "例: 急がなくても、ちゃんと進んでいた",
                        text: $insight,
                        field: .insight
                    )

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        field(
                            title: "次の一歩",
                            placeholder: "例: 明日の朝、5分だけ書く",
                            text: $nextStep,
                            field: .nextStep
                        )
                        Text("ひとつだけ。小さく、すぐできることを。")
                            .font(.footnote)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)

                        if !trimmedStep.isEmpty {
                            Toggle(isOn: $addAsStep) {
                                Label("今日の一歩に追加", systemImage: "leaf")
                                    .font(.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                            }
                            .tint(DesignSystem.Colors.accent)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous)
                                    .stroke(DesignSystem.Colors.grey, lineWidth: 0.5)
                            )
                            .padding(.top, DesignSystem.Spacing.xs)
                            .accessibilityIdentifier("closing_add_step_toggle")
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DesignSystem.Colors.background)
            .safeAreaInset(edge: .bottom) {
                Button(action: finish) {
                    Text(finishTitle)
                        .font(.headline)
                        .foregroundStyle(Self.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.mlg)
                        .background(Capsule().fill(DesignSystem.Colors.accent))
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.background)
                .accessibilityIdentifier("closing_finish_button")
            }
            .navigationTitle("対話を終える")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("戻る") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    /// 茶色のボタンの上の文字色（ライト/ダークで同じ見た目にするため固定色）
    private static let onAccent = Color(red: 0.99, green: 0.97, blue: 0.93)

    private var finishTitle: String {
        !trimmedStep.isEmpty && addAsStep ? "一歩を追加して終える" : "対話を終える"
    }

    private func field(title: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            TextField(placeholder, text: text, axis: .vertical)
                .font(.body)
                .lineLimit(2...4)
                .focused($focused, equals: field)
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous)
                        .stroke(DesignSystem.Colors.grey, lineWidth: 0.5)
                )
                .accessibilityIdentifier(field == .insight ? "closing_insight_field" : "closing_next_step_field")
        }
    }

    private func finish() {
        guard let session = coachStore.currentSession else {
            onFinish()
            return
        }
        let sessionId = session.id
        coachStore.endCurrentSession(insight: insight, nextStep: nextStep)
        if !trimmedStep.isEmpty, addAsStep,
           let taskId = taskViewModel.addStep(from: sessionId, title: trimmedStep) {
            coachStore.markNextStepAdded(sessionId: sessionId, taskId: taskId)
        }
        onFinish()
    }
}

#Preview {
    SessionClosingView(onFinish: {})
        .environmentObject(CoachStore())
        .environmentObject(TaskViewModel())
}
