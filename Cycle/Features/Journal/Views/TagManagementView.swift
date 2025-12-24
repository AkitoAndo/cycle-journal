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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Input area
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "tag")
                        .font(.system(size: DesignSystem.FontSize.body))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    TextField("新しいタグを追加", text: $newTagText)
                        .textFieldStyle(.plain)
                        .font(.system(size: DesignSystem.FontSize.body))
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
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(vm.allTags, id: \.self) { tag in
                                HStack {
                                    Text(tag)
                                        .font(.system(size: DesignSystem.FontSize.body))
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                                    Spacer()

                                    Button(action: {
                                        deleteTag(tag)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: DesignSystem.FontSize.title3))
                                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    }
                                }
                                .padding(DesignSystem.Spacing.lg)
                                .background(DesignSystem.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                    }
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("タグ管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "tag")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("タグがまだありません")
                    .font(.system(size: DesignSystem.FontSize.headline))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("上の入力欄から新しいタグを追加できます")
                    .font(.system(size: DesignSystem.FontSize.body))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
