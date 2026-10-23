//
//  WeeklyTreeView.swift
//  Cycle
//
//  ホームの「今週の樹」。今週の記録（日記・対話・瞑想・完了したタスク）の数だけ葉がつく。
//  記録がない週も枯れた見た目にはせず、芽だけを出す（書かなかった週を責めない）。
//  葉は風に吹かれるようにゆっくり揺れる（視差効果を減らす設定のときと、タブが見えていないときは止める）。
//

import SwiftUI

struct WeeklyTreeView: View {
    /// 今週の記録数（葉の数。表示は最大 leafSpots.count 枚）
    let leafCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cycleTabIsActive) private var cycleTabIsActive

    /// 葉をつける位置と向き（100×100 の座標）。枝先から順に埋まる
    private static let leafSpots: [(point: CGPoint, angle: Double)] = [
        (CGPoint(x: 50, y: 20), -10), (CGPoint(x: 27, y: 52), -40), (CGPoint(x: 75, y: 47), 35),
        (CGPoint(x: 32, y: 32), -30), (CGPoint(x: 68, y: 28), 30), (CGPoint(x: 42, y: 24), -20),
        (CGPoint(x: 59, y: 22), 20), (CGPoint(x: 20, y: 46), -55), (CGPoint(x: 82, y: 41), 55),
        (CGPoint(x: 37, y: 44), 15), (CGPoint(x: 63, y: 40), -15), (CGPoint(x: 25, y: 38), -60),
        (CGPoint(x: 76, y: 34), 60), (CGPoint(x: 46, y: 14), -35), (CGPoint(x: 55, y: 13), 35),
        (CGPoint(x: 30, y: 59), -20), (CGPoint(x: 70, y: 55), 20), (CGPoint(x: 38, y: 17), -50),
        (CGPoint(x: 63, y: 15), 50), (CGPoint(x: 50, y: 31), 0), (CGPoint(x: 86, y: 50), 70),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || !cycleTabIsActive)) { timeline in
            Canvas { context, size in
                let scale = min(size.width, size.height) / 100
                context.translateBy(x: (size.width - 100 * scale) / 2, y: (size.height - 100 * scale) / 2)
                context.scaleBy(x: scale, y: scale)
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                drawGround(in: &context)
                drawTrunk(in: &context)
                drawLeaves(in: &context, time: time)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(leafCount == 0 ? "今週の樹。まだ芽の状態" : "今週の樹。葉が\(leafCount)枚")
    }

    // MARK: - Drawing

    private func drawGround(in context: inout GraphicsContext) {
        context.fill(
            Path(ellipseIn: CGRect(x: 18, y: 92, width: 64, height: 7)),
            with: .color(DesignSystem.Colors.leafLight.opacity(0.35))
        )
        var grass = Path()
        for x in [30.0, 36, 64, 70] {
            grass.move(to: CGPoint(x: x, y: 95))
            grass.addLine(to: CGPoint(x: x + (x < 50 ? -2 : 2), y: 90))
        }
        context.stroke(grass, with: .color(DesignSystem.Colors.leafLight), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
    }

    private func drawTrunk(in context: inout GraphicsContext) {
        // 根元が太く先が細い幹
        var trunk = Path()
        trunk.move(to: CGPoint(x: 44, y: 96))
        trunk.addQuadCurve(to: CGPoint(x: 48.5, y: 30), control: CGPoint(x: 48, y: 62))
        trunk.addLine(to: CGPoint(x: 51.5, y: 30))
        trunk.addQuadCurve(to: CGPoint(x: 56, y: 96), control: CGPoint(x: 52, y: 62))
        trunk.closeSubpath()
        context.fill(trunk, with: .color(DesignSystem.Colors.accent))

        let branches: [(from: CGPoint, control: CGPoint, to: CGPoint, width: CGFloat)] = [
            (CGPoint(x: 50, y: 72), CGPoint(x: 36, y: 66), CGPoint(x: 24, y: 52), 3.2),
            (CGPoint(x: 50, y: 66), CGPoint(x: 66, y: 60), CGPoint(x: 78, y: 46), 3.2),
            (CGPoint(x: 49, y: 52), CGPoint(x: 38, y: 46), CGPoint(x: 30, y: 33), 2.4),
            (CGPoint(x: 51, y: 48), CGPoint(x: 62, y: 42), CGPoint(x: 70, y: 28), 2.4),
            (CGPoint(x: 50, y: 32), CGPoint(x: 50, y: 26), CGPoint(x: 50, y: 18), 1.8),
        ]
        for branch in branches {
            var path = Path()
            path.move(to: branch.from)
            path.addQuadCurve(to: branch.to, control: branch.control)
            context.stroke(path, with: .color(DesignSystem.Colors.accent), style: StrokeStyle(lineWidth: branch.width, lineCap: .round))
        }
    }

    private func drawLeaves(in context: inout GraphicsContext, time: TimeInterval) {
        let visible = min(leafCount, Self.leafSpots.count)
        // 葉がついていない枝先には芽を出す（記録がない週も枯れて見えないように）
        let budSpots = Self.leafSpots.prefix(5)
        for (index, spot) in budSpots.enumerated() where index >= visible {
            drawLeaf(
                in: &context,
                at: spot.point,
                angle: spot.angle + sway(time, index: index),
                size: 0.5,
                color: DesignSystem.Colors.leafLight
            )
        }
        for index in 0..<visible {
            let spot = Self.leafSpots[index]
            drawLeaf(
                in: &context,
                at: spot.point,
                angle: spot.angle + sway(time, index: index),
                size: index.isMultiple(of: 4) ? 0.85 : 1,
                color: index.isMultiple(of: 3) ? DesignSystem.Colors.leafLight : DesignSystem.Colors.leaf
            )
        }
    }

    /// 葉ごとに少しずつずれた、ゆっくりした揺れ（度）
    private func sway(_ time: TimeInterval, index: Int) -> Double {
        sin(time * 1.4 + Double(index) * 0.9) * 5
    }

    /// 両端がとがった葉と葉脈。変形は Path 側にかけて、絶対座標で描く
    private func drawLeaf(in context: inout GraphicsContext, at point: CGPoint, angle: Double, size: CGFloat, color: Color) {
        let transform = CGAffineTransform(translationX: point.x, y: point.y)
            .rotated(by: angle * .pi / 180)
            .scaledBy(x: size, y: size)

        var shape = Path()
        shape.move(to: CGPoint(x: -8, y: 0))
        shape.addQuadCurve(to: CGPoint(x: 8, y: 0), control: CGPoint(x: 0, y: -7))
        shape.addQuadCurve(to: CGPoint(x: -8, y: 0), control: CGPoint(x: 0, y: 7))
        shape.closeSubpath()
        context.fill(shape.applying(transform), with: .color(color))

        var vein = Path()
        vein.move(to: CGPoint(x: -6, y: 0))
        vein.addLine(to: CGPoint(x: 6, y: 0))
        context.stroke(vein.applying(transform), with: .color(.white.opacity(0.35)), lineWidth: 0.6 * size)
    }
}

#Preview {
    HStack(spacing: 24) {
        WeeklyTreeView(leafCount: 0)
        WeeklyTreeView(leafCount: 6)
        WeeklyTreeView(leafCount: 21)
    }
    .frame(height: 140)
    .padding()
}
