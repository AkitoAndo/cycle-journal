//
//  WeeklyTreeView.swift
//  Cycle
//
//  ホームの「今週の樹」。今週の記録（日記・対話・瞑想・完了したタスク）の数だけ葉がつく。
//  記録がない週も枯れた見た目にはせず、芽だけを出す（書かなかった週を責めない）。
//

import SwiftUI

struct WeeklyTreeView: View {
    /// 今週の記録数（葉の数。表示は最大 leafSpots.count 枚）
    let leafCount: Int

    /// 葉をつける位置（100×100 の座標）。先頭から順に埋まる
    private static let leafSpots: [CGPoint] = [
        CGPoint(x: 50, y: 30), CGPoint(x: 30, y: 50), CGPoint(x: 72, y: 44),
        CGPoint(x: 38, y: 38), CGPoint(x: 62, y: 34), CGPoint(x: 24, y: 62),
        CGPoint(x: 78, y: 58), CGPoint(x: 44, y: 22), CGPoint(x: 58, y: 22),
        CGPoint(x: 34, y: 28), CGPoint(x: 68, y: 26), CGPoint(x: 52, y: 46),
    ]

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            context.scaleBy(x: scale, y: scale)

            // 地面
            context.fill(
                Path(ellipseIn: CGRect(x: 22, y: 92, width: 56, height: 6)),
                with: .color(DesignSystem.Colors.grey)
            )

            // 幹と枝
            var trunk = Path()
            trunk.move(to: CGPoint(x: 50, y: 95))
            trunk.addLine(to: CGPoint(x: 50, y: 36))
            trunk.move(to: CGPoint(x: 50, y: 70))
            trunk.addQuadCurve(to: CGPoint(x: 28, y: 52), control: CGPoint(x: 36, y: 66))
            trunk.move(to: CGPoint(x: 50, y: 62))
            trunk.addQuadCurve(to: CGPoint(x: 74, y: 46), control: CGPoint(x: 66, y: 58))
            context.stroke(
                trunk,
                with: .color(DesignSystem.Colors.accent),
                style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
            )

            let visible = min(leafCount, Self.leafSpots.count)
            if visible == 0 {
                // 記録がない週は芽だけ
                drawLeaf(in: &context, at: CGPoint(x: 50, y: 32), angle: -30, color: DesignSystem.Colors.leafLight, size: 0.8)
            } else {
                for (index, spot) in Self.leafSpots.prefix(visible).enumerated() {
                    drawLeaf(
                        in: &context,
                        at: spot,
                        angle: index.isMultiple(of: 2) ? -32 : 28,
                        color: index.isMultiple(of: 3) ? DesignSystem.Colors.leafLight : DesignSystem.Colors.leaf,
                        size: 1
                    )
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(leafCount == 0 ? "今週の樹。まだ芽の状態" : "今週の樹。葉が\(leafCount)枚")
    }

    private func drawLeaf(in context: inout GraphicsContext, at point: CGPoint, angle: Double, color: Color, size: CGFloat) {
        var leaf = context
        leaf.translateBy(x: point.x, y: point.y)
        leaf.rotate(by: .degrees(angle))
        leaf.fill(
            Path(ellipseIn: CGRect(x: -8 * size, y: -5 * size, width: 16 * size, height: 10 * size)),
            with: .color(color)
        )
    }
}

#Preview {
    HStack(spacing: 24) {
        WeeklyTreeView(leafCount: 0)
        WeeklyTreeView(leafCount: 5)
        WeeklyTreeView(leafCount: 12)
    }
    .frame(height: 80)
    .padding()
}
