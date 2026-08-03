//
//  SurfaceCard.swift
//  Cycle
//
//  カード型コンテナ
//  全OS共通: surface背景 + 角丸 + ボーダー + シャドウ
//  （Liquid Glass 版は preferLiquidGlass で無効化中）
//

import SwiftUI

/// カード型の汎用コンテナ
///
/// 使用例:
/// ```swift
/// SurfaceCard {
///     Text("カード内のコンテンツ")
/// }
/// ```
struct SurfaceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(SurfaceCardStyle())
    }
}

private struct SurfaceCardStyle: ViewModifier {
    /// [0710] 素の Liquid Glass はカード上端にハイライト線が出て surface 色とも
    /// ずれて見えるため、surface 色を tint して色を安定させたガラスを使う。
    /// 問題が再発する場合は false にすると surface スタイルに戻る。
    private static let preferLiquidGlass = true

    func body(content: Content) -> some View {
        if Self.preferLiquidGlass, #available(iOS 26.0, *) {
            content
                .glassEffect(.surfaceTinted.interactive(), in: .rect(cornerRadius: DesignSystem.Spacing.md))
        } else {
            content
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
                .overlay(
                    // 上端を白く、下端をグレーにしたヘアラインで立体感を出す
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.hairlineHighlight,
                                    DesignSystem.Colors.grey.opacity(0.6)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                // 近接シャドウ（輪郭）と拡散シャドウ（浮遊感）の2層
                .shadow(
                    color: DesignSystem.Colors.brownDark.opacity(0.06),
                    radius: 1.5,
                    x: 0,
                    y: 1
                )
                .shadow(
                    color: DesignSystem.Colors.brownDark.opacity(0.07),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        }
    }
}
