//
//  GlassHeaderModifier.swift
//  Cycle
//
//  ヘッダーにLiquid Glass効果を適用するViewModifier
//  iOS 26+: 半透明ブラー + glassEffect
//  iOS 25以下: ソリッド背景
//

import SwiftUI

/// カスタムヘッダー（JournalHeader, TaskHeader）用
/// `.background` をglassに差し替える
struct GlassHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(.ultraThinMaterial)
                .glassEffect(.regular, in: .rect(cornerRadius: 0))
        } else {
            content
                .background(DesignSystem.Colors.background)
        }
    }
}

/// アイコンボタン用 Liquid Glass
/// iOS 26+: 円形のglassEffectを適用
/// iOS 25以下: そのまま表示
struct GlassIconModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(12)
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
        }
    }
}

/// システムNavigationBar用（Coach, Settings）
/// iOS 26+ではナビバー背景を透過してLiquid Glass感を出す
struct GlassNavBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        } else {
            content
        }
    }
}
