//
//  TaskTemplateManagementView.swift
//  Cycle
//
//  タスクテンプレートの管理画面（ジャーナルのタグ管理 TagManagementView と同じ仕様）
//  - 右下のプラスボタン（FAB）で追加（タスク一覧と同様）
//  - 追加・編集はタスクの入力欄と同じフォーム（TaskTemplateEditView）
//  - スワイプで削除・編集
//  - ツールバーの「並び替え」でドラッグ並び替え
//

import SwiftUI

struct TaskTemplateManagementView: View {
    @ObservedObject var vm: TaskViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingTemplate = false
    @State private var editingTemplate: TaskTemplate? = nil
    @State private var isReorderMode = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // Templates list
                if vm.templates.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(vm.templates) { template in
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
                            .modifier(TemplateManagementCardStyle())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(
                                top: DesignSystem.Spacing.xs,
                                leading: DesignSystem.Spacing.lg,
                                bottom: DesignSystem.Spacing.xs,
                                trailing: DesignSystem.Spacing.lg
                            ))
                            .moveDisabled(!isReorderMode)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    vm.removeTemplate(template)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                        .labelStyle(.iconOnly)
                                }

                                Button {
                                    editingTemplate = template
                                } label: {
                                    Label("編集", systemImage: "pencil")
                                        .labelStyle(.iconOnly)
                                }
                                .tint(DesignSystem.Colors.accent)
                            }
                        }
                        .onMove { source, destination in
                            vm.moveTemplates(from: source, to: destination)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(DesignSystem.Colors.background)
                    .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
                }

                // 右下のプラスボタン（タスク一覧の FAB と同様）
                FloatingActionButton(icon: "plus") {
                    isAddingTemplate = true
                }
                .padding(.trailing, DesignSystem.Spacing.xl + 2)
                .padding(.bottom, DesignSystem.Spacing.xl - 2)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("テンプレート管理")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isReorderMode ? "完了" : "並び替え") {
                        withAnimation {
                            isReorderMode.toggle()
                        }
                    }
                }
            }
            .sheet(isPresented: $isAddingTemplate) {
                TaskTemplateEditView(vm: vm)
            }
            .sheet(item: $editingTemplate) { template in
                TaskTemplateEditView(vm: vm, template: template)
            }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "square.on.square",
            title: "テンプレートがまだありません",
            subtitle: "よく使うタスクを登録しましょう"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

private struct TemplateManagementCardStyle: ViewModifier {
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
