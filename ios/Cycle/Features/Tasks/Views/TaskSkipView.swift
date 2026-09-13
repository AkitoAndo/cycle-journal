//
//  TaskSkipView.swift
//  Cycle
//
//  未完了タスクを見送る際に、任意の理由を記録するシート。
//

import SwiftUI

struct TaskSkipView: View {
    let task: TaskItem
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""

    private let reasonLimit = 100

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                taskSummary

                FormTextEditor(
                    label: "見送る理由（任意）",
                    text: $reason,
                    placeholder: "例：今日は優先度を下げることにした",
                    height: 110
                )
                .accessibilityIdentifier("task_skip_reason_input")

                Text("\(reason.count)/\(reasonLimit)")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer(minLength: 0)

                PrimaryButton("見送る", icon: "archivebox") {
                    onConfirm(reason)
                    dismiss()
                }
                .accessibilityIdentifier("task_skip_confirm")
            }
            .padding(DesignSystem.Spacing.xl)
            .background(DesignSystem.Colors.background)
            .navigationTitle("今回は見送る")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .onChange(of: reason) { _, newValue in
                if newValue.count > reasonLimit {
                    reason = String(newValue.prefix(reasonLimit))
                }
            }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    private var taskSummary: some View {
        SurfaceCard {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "circle")
                    .font(.system(size: DesignSystem.FontSize.title3))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(task.title)
                        .font(DesignSystem.Fonts.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("一覧から外して、今日の履歴に残します")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                Spacer()
            }
        }
    }
}
