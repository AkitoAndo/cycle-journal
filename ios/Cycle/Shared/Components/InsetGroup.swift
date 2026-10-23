//
//  InsetGroup.swift
//  Cycle
//
//  iOS 17 の設定アプリと同じ「見出し + 角丸でまとめたリスト」（U-04）。
//  ScrollView の中で使う軽い部品。List を使う画面は .insetGrouped を使う。
//

import SwiftUI

/// 見出し + 角丸でまとめたリスト
struct InsetGroup<Content: View>: View {
    var title: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let title {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .padding(.leading, DesignSystem.Spacing.xs)
            }
            VStack(spacing: 0) {
                content
            }
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
            // 塗りに頼らず、細い線で輪郭を出す（Claude アプリのカードと同じ考え方）
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous)
                    .stroke(DesignSystem.Colors.grey, lineWidth: 0.5)
            )
        }
    }
}

/// リストの区切り線（左は本文の位置から始める）
struct InsetRowDivider: View {
    var leadingInset: CGFloat = DesignSystem.Spacing.lg

    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.grey)
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
    }
}

/// 行末の「>」
struct InsetChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(DesignSystem.Colors.textTertiary)
    }
}

/// アイコン + タイトル（+ 右の補足）+「>」の、タップできる1行
struct InsetNavigationRow: View {
    let title: String
    let systemImage: String
    var detail: String?
    var detailColor: Color = DesignSystem.Colors.textSecondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .frame(width: 28, height: 28)
                Text(title)
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer(minLength: 0)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(detailColor)
                }
                InsetChevron()
            }
            .insetRow()
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// リスト1行分の余白（高さ44pt以上）
    func insetRow() -> some View {
        self
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
    }
}
