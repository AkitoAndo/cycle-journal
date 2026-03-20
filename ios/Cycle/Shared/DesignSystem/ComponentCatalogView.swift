//
//  ComponentCatalogView.swift
//  Cycle
//
//  Storybook的なカタログビューア
//  Settings画面などから開いてコンポーネントを一覧・確認できる
//

import SwiftUI

struct ComponentCatalogView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.isPresented) var isPresented
    @State private var selectedCategory: CatalogCategory? = nil
    @State private var searchText = ""

    private var filteredItems: [CatalogItem] {
        var items = CatalogRegistry.items
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        return items
    }

    private var groupedItems: [(CatalogCategory, [CatalogItem])] {
        let grouped = Dictionary(grouping: filteredItems) { $0.category }
        return CatalogCategory.allCases
            .compactMap { category in
                guard let items = grouped[category], !items.isEmpty else { return nil }
                return (category, items)
            }
    }

    var body: some View {
        NavigationStack {
            List {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(nil, "All")
                        ForEach(CatalogCategory.allCases, id: \.self) { category in
                            categoryChip(category, category.rawValue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)

                // Component List
                ForEach(groupedItems, id: \.0) { category, items in
                    Section {
                        ForEach(items) { item in
                            NavigationLink {
                                ComponentDetailView(item: item)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(DesignSystem.Colors.accent)
                                        .frame(width: 28, height: 28)
                                        .background(DesignSystem.Colors.accentLight.opacity(0.3))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.system(size: 15, weight: .medium))
                                        Text(item.description)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 11))
                            Text(category.rawValue)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "コンポーネントを検索")
            .navigationTitle("Component Catalog")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if isPresented {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") { dismiss() }
                    }
                }
            }
        }
    }

    private func categoryChip(_ category: CatalogCategory?, _ title: String) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.greyLight)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Component Detail View

struct ComponentDetailView: View {
    let item: CatalogItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: item.category.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(item.category.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Text(item.name)
                        .font(.system(size: 24, weight: .bold))

                    Text(item.description)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Divider()

                // Props Table
                if !item.props.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROPS")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(item.props) { prop in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(prop.name)
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(DesignSystem.Colors.accent)
                                        Text(prop.type)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        if prop.required {
                                            Text("required")
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(DesignSystem.Colors.brown.opacity(0.7))
                                                .clipShape(Capsule())
                                        }
                                    }

                                    if !prop.description.isEmpty {
                                        Text(prop.description)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }

                                    if let defaultValue = prop.defaultValue {
                                        HStack(spacing: 4) {
                                            Text("default:")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.tertiary)
                                            Text(defaultValue)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)

                                if prop.id != item.props.last?.id {
                                    Divider().padding(.leading, 14)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(DesignSystem.Colors.grey, lineWidth: 0.5)
                        )
                        .padding(.horizontal)
                    }

                    Divider()
                }

                // Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("PREVIEW")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    item.preview
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignSystem.Colors.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(DesignSystem.Colors.grey, lineWidth: 0.5)
                        )
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    ComponentCatalogView()
}
