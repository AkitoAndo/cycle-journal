//
//  TagManagementView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/13.
//

import SwiftUI

struct TagManagementView: View {
    @ObservedObject var vm: JournalViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newTagText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var editingTag: String? = nil
    @State private var editingTagText: String = ""
    @State private var isReorderMode = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Input area
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "tag")
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    TextField("新しいタグを追加", text: $newTagText)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .focused($isInputFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addTag()
                        }
                        .tint(DesignSystem.Colors.accent)

                    if !newTagText.isEmpty {
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: DesignSystem.FontSize.title3))
                                .foregroundStyle(DesignSystem.Colors.accent)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.md)

                Divider()
                    .background(DesignSystem.Colors.grey)
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                // Tags list
                if vm.allTags.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(vm.allTags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                    .font(DesignSystem.Fonts.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Spacer()
                            }
                            .padding(DesignSystem.Spacing.lg)
                            .background(DesignSystem.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
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
                                    vm.removeTag(tag)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                        .labelStyle(.iconOnly)
                                }

                                Button {
                                    editingTag = tag
                                    editingTagText = tag
                                } label: {
                                    Label("編集", systemImage: "pencil")
                                        .labelStyle(.iconOnly)
                                }
                                .tint(DesignSystem.Colors.accent)
                            }
                        }
                        .onMove { source, destination in
                            vm.moveTags(from: source, to: destination)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(DesignSystem.Colors.background)
                    .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("タグ管理")
            .navigationBarTitleDisplayMode(.inline)
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
            .alert("タグを編集", isPresented: Binding(
                get: { editingTag != nil },
                set: { if !$0 { editingTag = nil } }
            )) {
                TextField("タグ名", text: $editingTagText)
                Button("保存") {
                    if let old = editingTag {
                        vm.renameTag(old, to: editingTagText)
                    }
                    editingTag = nil
                }
                Button("キャンセル", role: .cancel) {
                    editingTag = nil
                }
            }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    private var emptyStateView: some View {
        EmptyStateView(icon: "tag", title: "タグがまだありません", subtitle: "タグを追加して日記を整理しましょう")
    }

    private func addTag() {
        vm.addTag(newTagText)
        newTagText = ""
        isInputFocused = false
    }

    private func deleteTag(_ tag: String) {
        vm.removeTag(tag)
    }
}
