//
//  TaskTemplatePickerView.swift
//  Cycle
//
//  新規タスク画面の「テンプレートを使用する」から開くテンプレート選択シート。
//  行のタップでテンプレートの内容をフォームに反映して閉じる。
//  下部の「今の内容を登録」で現在のフォーム内容をテンプレートとして保存できる。
//

import SwiftUI

struct TaskTemplatePickerView: View {
    @ObservedObject var vm: TaskViewModel
    @Environment(\.dismiss) private var dismiss

    /// 「今の内容を登録」が押せるか（タイトル入力済みか）
    let canRegister: Bool
    /// テンプレートをフォームに反映する
    let onApply: (TaskTemplate) -> Void
    /// 現在のフォーム内容をテンプレートとして登録する
    let onRegister: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if vm.templates.isEmpty {
                    emptyStateView
                } else {
                    templateList
                }

                registerButton
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("テンプレート")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(DesignSystem.Colors.background)
    }

    private var templateList: some View {
        List {
            ForEach(vm.templates) { template in
                Button {
                    onApply(template)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(template.title)
                                .font(DesignSystem.Fonts.body)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            if !template.previewText.isEmpty {
                                Text(template.previewText)
                                    .font(DesignSystem.Fonts.caption)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .modifier(TemplatePickerCardStyle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(
                    top: DesignSystem.Spacing.xs,
                    leading: DesignSystem.Spacing.lg,
                    bottom: DesignSystem.Spacing.xs,
                    trailing: DesignSystem.Spacing.lg
                ))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Colors.background)
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            EmptyStateView(
                icon: "square.on.square",
                title: "テンプレートがまだありません",
                subtitle: "「今の内容を登録」またはタスクリストのテンプレート管理から登録できます"
            )
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var registerButton: some View {
        Button {
            onRegister()
        } label: {
            Label("今の内容を登録", systemImage: "plus.circle")
                .font(DesignSystem.Fonts.body)
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.lg)
                .modifier(TemplatePickerCardStyle())
        }
        .buttonStyle(.plain)
        .tint(DesignSystem.Colors.accent)
        .foregroundStyle(canRegister
            ? DesignSystem.Colors.accent
            : DesignSystem.Colors.textSecondary)
        .disabled(!canRegister)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
    }
}

private struct TemplatePickerCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.surfaceTinted.interactive(), in: .rect(cornerRadius: DesignSystem.Spacing.md))
        } else {
            content
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
        }
    }
}
