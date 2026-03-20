//
//  IconCircle.swift
//  Cycle
//
//  円形アイコン表示
//  iOS 26+: Liquid Glass 背景
//  iOS 17-25: グラデーション背景
//

import SwiftUI

/// 円形アイコン
///
/// 使用例:
/// ```swift
/// IconCircle(icon: "tree", size: 120, color: .green)
/// IconCircle(icon: "person.circle.fill", size: 40, color: .blue)
/// ```
struct IconCircle: View {
    let icon: String
    var size: CGFloat = 80
    var iconScale: CGFloat = 0.42
    var color: Color = DesignSystem.Colors.accent

    var body: some View {
        ZStack {
            if #available(iOS 26.0, *) {
                Circle()
                    .fill(.clear)
                    .frame(width: size, height: size)
                    .glassEffect(.regular, in: .circle)
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size, height: size)
            }

            Image(systemName: icon)
                .font(.system(size: size * iconScale))
                .foregroundStyle(color)
        }
    }
}
