//
//  Motion.swift
//  Cycle
//
//  アプリ全体で共有するモーション言語
//  - PressableButtonStyle: 押下時に沈み込むボタンスタイル
//  - staggeredAppear: リスト行などを下から順番にふわっと出現させる
//

import SwiftUI

/// 押下時にわずかに縮んで沈み込むボタンスタイル
///
/// 使用例:
/// ```swift
/// Button("保存") { save() }
///     .buttonStyle(PressableButtonStyle())
/// ```
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(DesignSystem.Timing.spring, value: configuration.isPressed)
    }
}

/// 出現時に下から順番にフェードインさせるモディファイア
///
/// リスト行に `index` を渡すと、行ごとに少しずつ遅延した
/// スプリングアニメーションで出現する。
private struct StaggeredAppear: ViewModifier {
    let index: Int
    /// 1行あたりの遅延。遅延の合計は maxStagger 行分で頭打ち
    var baseDelay: Double = 0.045
    private let maxStagger = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : (reduceMotion ? 0 : 14))
            .onAppear {
                guard !reduceMotion else {
                    shown = true
                    return
                }
                let delay = Double(min(index, maxStagger)) * baseDelay
                withAnimation(DesignSystem.Timing.spring.delay(delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    /// リスト行などを下から順番にふわっと出現させる
    ///
    /// 使用例:
    /// ```swift
    /// ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
    ///     Row(item: item).staggeredAppear(index: index)
    /// }
    /// ```
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}
