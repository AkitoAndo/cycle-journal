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
/// iOS 26+: 円形のglassEffectを適用（縁の陰影はガラスの仕様）
/// iOS 25以下: フラットな surface 円
struct GlassIconModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                // SFシンボルごとの字形サイズ差で円の大きさが変わらないよう
                // 固定枠に揃える（全ヘッダーボタン共通で直径45pt）
                .frame(width: 25, height: 25)
                .padding(10)
                .glassEffect(.surfaceTinted.interactive(), in: .circle)
        } else {
            content
                .frame(width: 25, height: 25)
                .padding(10)
                .background(Circle().fill(DesignSystem.Colors.surface))
        }
    }
}

/// List（insetGrouped）の行背景用 Liquid Glass
/// iOS 26+: surfaceTinted ガラス。行ごとに敷かれ、セクションの角丸でクリップされる
/// iOS 25以下: ソリッドな surface 色
struct GlassListRowBackground: View {
    var body: some View {
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.surfaceTinted, in: .rect(cornerRadius: 0))
        } else {
            DesignSystem.Colors.surface
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
