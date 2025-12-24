//
//  JournalSearchView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import SwiftUI

struct JournalSearchView: View {
    @ObservedObject var vm: JournalViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        TextField("テキストで検索", text: $vm.searchText)
                            .textFieldStyle(.plain)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .tint(DesignSystem.Colors.accent)
                        if !vm.searchText.isEmpty {
                            Button(action: { vm.searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md))

                    if !vm.allTags.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("タグで絞り込み")
                                .font(.system(size: DesignSystem.FontSize.caption))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    ForEach(vm.allTags, id: \.self) { tag in
                                        Button(action: {
                                            toggleSearchTag(tag)
                                        }) {
                                            Text(tag)
                                                .font(.system(size: DesignSystem.FontSize.caption))
                                                .padding(.horizontal, DesignSystem.Spacing.md)
                                                .padding(.vertical, DesignSystem.Spacing.xs + 2)
                                                .background(vm.selectedSearchTags.contains(tag) ? DesignSystem.Colors.accent : DesignSystem.Colors.greyLight)
                                                .foregroundStyle(vm.selectedSearchTags.contains(tag) ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.background)

                if !vm.searchText.isEmpty || !vm.selectedSearchTags.isEmpty {
                    HStack {
                        Text("\(vm.searchResults.count)件の結果")
                            .font(.system(size: DesignSystem.FontSize.body))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.xs)
                    .padding(.bottom, DesignSystem.Spacing.sm)
                }

                if vm.searchText.isEmpty && vm.selectedSearchTags.isEmpty {
                    VStack {
                        Spacer()
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: DesignSystem.FontSize.largeTitle))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                            Text("テキストやタグで検索")
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.Colors.background)
                } else {
                    List {
                        if vm.searchResults.isEmpty {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: DesignSystem.FontSize.largeTitle))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                Text("該当するエントリがありません")
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            Section {
                                ForEach(vm.searchResults) { entry in
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                        Text(entry.text)
                                            .font(.system(size: DesignSystem.FontSize.body))
                                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                                            .lineSpacing(4)

                                        HStack(spacing: DesignSystem.Spacing.sm) {
                                            Text(entry.date, format: .dateTime.year().month().day())
                                                .font(.system(size: DesignSystem.FontSize.caption))
                                                .foregroundStyle(DesignSystem.Colors.textSecondary)

                                            Text(entry.date.timeHM)
                                                .font(.system(size: DesignSystem.FontSize.caption))
                                                .foregroundStyle(DesignSystem.Colors.textSecondary)

                                            if !entry.tags.isEmpty {
                                                ForEach(entry.tags, id: \.self) { tag in
                                                    TagChip(text: tag)
                                                }
                                            }
                                        }
                                    }
                                    .padding(DesignSystem.Spacing.lg)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(DesignSystem.Colors.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous)
                                            .stroke(DesignSystem.Colors.grey.opacity(0.6), lineWidth: 0.5)
                                    )
                                    .shadow(
                                        color: DesignSystem.Colors.brownDark.opacity(0.08),
                                        radius: 4,
                                        x: 0,
                                        y: 2
                                    )
                                    .listRowInsets(
                                        EdgeInsets(
                                            top: DesignSystem.Spacing.xs,
                                            leading: DesignSystem.Spacing.lg,
                                            bottom: DesignSystem.Spacing.xs,
                                            trailing: DesignSystem.Spacing.lg
                                        )
                                    )
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(DesignSystem.Colors.background)
                }
            }
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        clearSearch()
                        dismiss()
                    }
                }
            }
        }
    }

    private func toggleSearchTag(_ tag: String) {
        withAnimation(DesignSystem.Timing.easing) {
            if vm.selectedSearchTags.contains(tag) {
                vm.selectedSearchTags.removeAll { $0 == tag }
            } else {
                vm.selectedSearchTags.append(tag)
            }
        }

        // 触覚フィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    private func clearSearch() {
        vm.searchText = ""
        vm.selectedSearchTags = []
        vm.isSearching = false
    }
}
