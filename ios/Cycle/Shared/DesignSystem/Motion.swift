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

/// グループごとに「このセッションで出現アニメーションを再生済みか」を覚えておく。
/// タブを切り替えるたびにビューが作り直されても、再訪時はアニメーションを
/// 再生せず即時表示にするために使う。
@MainActor
private enum StaggerSessionMemory {
    private static var playedGroups = Set<String>()

    static func hasPlayed(_ group: String) -> Bool {
        playedGroups.contains(group)
    }

    static func markPlayed(_ group: String) {
        playedGroups.insert(group)
    }
}

/// 出現時に下から順番にフェードインさせるモディファイア
///
/// リスト行に `index` を渡すと、行ごとに少しずつ遅延した
/// スプリングアニメーションで出現する。
private struct StaggeredAppear: ViewModifier {
    let index: Int
    /// 同じ group は1セッションに1回だけ再生する（nil なら毎回再生）
    var group: String?
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
                if reduceMotion {
                    shown = true
                    return
                }
                if let group = group, StaggerSessionMemory.hasPlayed(group) {
                    shown = true
                    return
                }
                let delay = Double(min(index, maxStagger)) * baseDelay
                withAnimation(DesignSystem.Timing.spring.delay(delay)) {
                    shown = true
                }
                if let group = group {
                    StaggerSessionMemory.markPlayed(group)
                }
            }
    }
}

extension View {
    /// リスト行などを下から順番にふわっと出現させる
    ///
    /// `group` を渡すと、同じ group の出現アニメーションは1セッションに
    /// 1回だけ再生される（タブ再訪時の再発火を防ぐ）。
    ///
    /// 使用例:
    /// ```swift
    /// ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
    ///     Row(item: item).staggeredAppear(index: index, group: "journal_list")
    /// }
    /// ```
    func staggeredAppear(index: Int, group: String? = nil) -> some View {
        modifier(StaggeredAppear(index: index, group: group))
    }
}
