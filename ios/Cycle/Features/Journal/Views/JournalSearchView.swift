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

    // テキスト検索の結果
    private var textSearchResults: [JournalEntry] {
        vm.entries.filter { $0.deletedAt == nil && $0.text.localizedCaseInsensitiveContains(vm.searchText) }
                  .sorted { $0.date > $1.date }
    }

    // タグ検索の結果
    private var tagSearchResults: [JournalEntry] {
        vm.entries.filter { entry in
            entry.deletedAt == nil && vm.selectedSearchTags.contains { tag in
                entry.tags.contains(tag)
            }
        }
        .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // タブ選択
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Button(action: {
                            vm.searchViewTab = 0
                        }) {
                            Text("検索")
                                .font(.system(size: DesignSystem.FontSize.body, weight: vm.searchViewTab == 0 ? .semibold : .regular))
                                .foregroundStyle(vm.searchViewTab == 0 ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                        }

                        Button(action: {
                            vm.searchViewTab = 1
                        }) {
                            Text("タグ")
                                .font(.system(size: DesignSystem.FontSize.body, weight: vm.searchViewTab == 1 ? .semibold : .regular))
                                .foregroundStyle(vm.searchViewTab == 1 ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                        }
                    }

                    // アンダーライン
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(vm.searchViewTab == 0 ? DesignSystem.Colors.accent : DesignSystem.Colors.grey)
                                .frame(width: geometry.size.width / 2, height: vm.searchViewTab == 0 ? 2 : 0.5)

                            Rectangle()
                                .fill(vm.searchViewTab == 1 ? DesignSystem.Colors.accent : DesignSystem.Colors.grey)
                                .frame(width: geometry.size.width / 2, height: vm.searchViewTab == 1 ? 2 : 0.5)
                        }
                    }
                    .frame(height: 2)
                }
                .background(DesignSystem.Colors.background)

                VStack(spacing: DesignSystem.Spacing.md) {
                    if vm.searchViewTab == 0 {
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
                    }

                    if vm.searchViewTab == 1 && !vm.allTags.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("タグで絞り込み")
                                .font(DesignSystem.Fonts.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    ForEach(vm.allTags, id: \.self) { tag in
                                        Button(action: {
                                            toggleSearchTag(tag)
                                        }) {
                                            Text(tag)
                                                .font(DesignSystem.Fonts.caption)
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

                if vm.searchViewTab == 0 {
                    searchTabContent
                } else {
                    if !vm.selectedSearchTags.isEmpty {
                        HStack {
                            Text("\(tagSearchResults.count)件の結果")
                                .font(DesignSystem.Fonts.body)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.top, DesignSystem.Spacing.xs)
                        .padding(.bottom, DesignSystem.Spacing.sm)

                        entryList(entries: tagSearchResults, showEmptyMessage: "該当するエントリがありません")
                    } else {
                        VStack {
                            Spacer()
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                Image(systemName: "tag")
                                    .font(DesignSystem.Fonts.largeTitle)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                Text("タグを選択してください")
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DesignSystem.Colors.background)
                    }
                }
            }
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        clearSearch()
                        dismiss()
                    }
                }
            }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    private func toggleSearchTag(_ tag: String) {
        if vm.selectedSearchTags.contains(tag) {
            vm.selectedSearchTags.removeAll { $0 == tag }
        } else {
            vm.selectedSearchTags.append(tag)
        }

        // 触覚フィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    private func clearSearch() {
        vm.searchText = ""
        vm.selectedSearchTags = []
        vm.isSearching = false
        vm.searchViewTab = 0
    }

    private var searchTabContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text(self.vm.searchText.isEmpty ? "\(self.vm.allEntries.count)件のエントリ" : "\(self.textSearchResults.count)件の結果")
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.xs)
            .padding(.bottom, DesignSystem.Spacing.sm)

            self.entryList(entries: self.vm.searchText.isEmpty ? self.vm.allEntries : self.textSearchResults, showEmptyMessage: "該当するエントリがありません")
        }
    }

    @ViewBuilder
    private func entryList(entries: [JournalEntry], showEmptyMessage: String) -> some View {
        List {
            if entries.isEmpty {
                EmptyStateView(icon: "magnifyingglass", title: "見つかりませんでした")
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text(entry.text)
                                .font(DesignSystem.Fonts.body)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .lineSpacing(4)

                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Text(entry.date, format: .dateTime.year().month().day())
                                    .font(DesignSystem.Fonts.caption)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                                Text(entry.date.timeHM)
                                    .font(DesignSystem.Fonts.caption)
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
