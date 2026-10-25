//
//  WeeklyTreeView.swift
//  Cycle
//
//  ホームの「今週の樹」。今週の記録（日記・対話・瞑想・完了した一歩）の数だけ葉がつく。
//  記録がない週も枯れた見た目にはせず、芽だけを出す（書かなかった週を責めない）。
//
//  描き方: 幹から枝が再帰的に分かれる（枝分かれするたびに細く・短くなる）本物の木の形。
//  枝先ごとに葉の「房」がつき、記録が増えると房が増える。葉は風でゆっくり揺れる
//  （「視差効果を減らす」がオンのとき、ホームが見えていないときは止める）。
//  幹・枝の形は決まった乱数（seed 固定）で生成するので、毎回同じ木になる。
//

import SwiftUI

struct WeeklyTreeView: View {
    /// 今週の記録数（葉の房の数。表示は最大 Tree.tips.count）
    let leafCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cycleTabIsActive) private var cycleTabIsActive

    /// 木の形（一度だけ生成して使い回す）
    private static let tree = Tree.generate()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || !cycleTabIsActive)) { timeline in
            Canvas { context, size in
                let scale = min(size.width, size.height) / 100
                context.translateBy(x: (size.width - 100 * scale) / 2, y: (size.height - 100 * scale) / 2)
                context.scaleBy(x: scale, y: scale)
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                drawGround(in: &context)
                drawBranches(in: &context)
                drawFoliage(in: &context, time: time)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(leafCount == 0 ? "今週の樹。まだ芽の状態" : "今週の樹。葉が\(leafCount)枚")
    }

    // MARK: - 地面

    /// 地面は薄い影だけ（草は葉と見分けにくいので描かない）
    private func drawGround(in context: inout GraphicsContext) {
        context.fill(
            Path(ellipseIn: CGRect(x: 14, y: 91, width: 72, height: 8)),
            with: .color(DesignSystem.Colors.leafLight.opacity(0.30))
        )
    }

    // MARK: - 幹と枝

    private func drawBranches(in context: inout GraphicsContext) {
        // 太い順に描くと、細い枝が幹の上に乗って継ぎ目が自然になる
        for segment in Self.tree.segments.sorted(by: { $0.startWidth > $1.startWidth }) {
            context.fill(segment.path, with: .color(DesignSystem.Colors.accent))
        }
        // 幹の根元の張り出し（根）。幹の下端より上から始めて段差が出ないようにする
        var roots = Path()
        roots.move(to: CGPoint(x: 41, y: 94))
        roots.addQuadCurve(to: CGPoint(x: 46.5, y: 82), control: CGPoint(x: 45.5, y: 91))
        roots.addLine(to: CGPoint(x: 53.5, y: 82))
        roots.addQuadCurve(to: CGPoint(x: 59, y: 94), control: CGPoint(x: 54.5, y: 91))
        roots.closeSubpath()
        context.fill(roots, with: .color(DesignSystem.Colors.accent))
    }

    // MARK: - 葉

    private func drawFoliage(in context: inout GraphicsContext, time: TimeInterval) {
        let tips = Self.tree.tips
        let visible = min(leafCount, tips.count)

        // 葉のない枝先には芽（記録がない週も枯れて見えない）
        for (index, tip) in tips.enumerated() where index >= visible && index < 6 {
            drawLeaf(in: &context, at: tip.point, angle: tip.angle + sway(time, index), size: 0.45, color: DesignSystem.Colors.leafLight)
        }

        // 枝先ごとに葉の房（3〜4枚、少しずつ向きと大きさを変える）
        for index in 0..<visible {
            let tip = tips[index]
            let s = sway(time, index)
            let cluster: [(dx: CGFloat, dy: CGFloat, angle: Double, size: CGFloat, light: Bool)] = [
                (0, 0, 0, 1.0, false),
                (-3, 1, -48, 0.85, true),
                (3, 1, 48, 0.85, false),
                (0, -3, 92, 0.75, true),
            ]
            for (i, leaf) in cluster.enumerated() where i < 3 + (index % 2) {
                drawLeaf(
                    in: &context,
                    at: CGPoint(x: tip.point.x + leaf.dx, y: tip.point.y + leaf.dy),
                    angle: tip.angle + leaf.angle + s,
                    size: leaf.size,
                    color: leaf.light ? DesignSystem.Colors.leafLight : DesignSystem.Colors.leaf
                )
            }
        }
    }

    /// 枝先ごとに少しずつずれた、ゆっくりした揺れ（度）
    private func sway(_ time: TimeInterval, _ index: Int) -> Double {
        sin(time * 1.3 + Double(index) * 0.8) * 4
    }

    /// 両端がとがった葉と葉脈。変形は Path 側にかけて絶対座標で描く
    private func drawLeaf(in context: inout GraphicsContext, at point: CGPoint, angle: Double, size: CGFloat, color: Color) {
        let transform = CGAffineTransform(translationX: point.x, y: point.y)
            .rotated(by: angle * .pi / 180)
            .scaledBy(x: size, y: size)

        var shape = Path()
        shape.move(to: CGPoint(x: -4, y: 0))
        shape.addQuadCurve(to: CGPoint(x: 4, y: 0), control: CGPoint(x: 0, y: -3.6))
        shape.addQuadCurve(to: CGPoint(x: -4, y: 0), control: CGPoint(x: 0, y: 3.6))
        shape.closeSubpath()
        context.fill(shape.applying(transform), with: .color(color))

        var vein = Path()
        vein.move(to: CGPoint(x: -3, y: 0))
        vein.addLine(to: CGPoint(x: 3, y: 0))
        context.stroke(vein.applying(transform), with: .color(.white.opacity(0.35)), lineWidth: 0.4 * size)
    }
}

// MARK: - 木の形

/// 再帰的に枝分かれさせて作る木の形
private struct Tree {
    struct Segment {
        let path: Path
        let startWidth: CGFloat
    }
    struct Tip {
        let point: CGPoint
        let angle: Double
    }

    let segments: [Segment]
    /// 枝先（葉をつける位置）。見栄えの順（上・外側から）に並べ替え済み
    let tips: [Tip]

    static func generate() -> Tree {
        var rng = SeededGenerator(seed: 0x5EED_7EE)
        var segments: [Segment] = []
        var tips: [Tip] = []

        func grow(from start: CGPoint, angle: Double, length: CGFloat, width: CGFloat, depth: Int) {
            let rad = angle * .pi / 180
            let end = CGPoint(x: start.x + cos(rad) * length, y: start.y + sin(rad) * length)
            // 少し曲がる枝（制御点を横にずらす）
            let bend = CGFloat(rng.next(in: -0.25...0.25)) * length
            let control = CGPoint(
                x: (start.x + end.x) / 2 - sin(rad) * bend,
                y: (start.y + end.y) / 2 + cos(rad) * bend
            )
            let endWidth = depth == 0 ? width * 0.35 : max(width * 0.6, 0.9)
            segments.append(Segment(path: taperedPath(from: start, control: control, to: end, startWidth: width, endWidth: endWidth), startWidth: width))

            if depth == 0 {
                tips.append(Tip(point: end, angle: angle + 90))
                return
            }
            // 2〜3本に分かれる。上へ向かう力（-90度へ少し戻す）を入れて自然な樹形にする
            let count = depth >= 3 ? 3 : 2
            let spread = depth >= 3 ? 38.0 : 30.0
            for i in 0..<count {
                let t = count == 1 ? 0 : Double(i) / Double(count - 1) - 0.5
                var childAngle = angle + t * spread * 2 + rng.next(in: -8...8)
                childAngle += (-90 - childAngle) * 0.15
                let childLength = length * CGFloat(rng.next(in: 0.72...0.84))
                grow(from: end, angle: childAngle, length: childLength, width: endWidth, depth: depth - 1)
            }
        }

        // 幹: 根元 (50, 90) から真上へ
        grow(from: CGPoint(x: 50, y: 92), angle: -90 + rng.next(in: -3...3), length: 24, width: 7, depth: 4)

        // 葉の房が一か所に固まらないよう、枝先の順番を決まった乱数で混ぜる
        // （左右を交互に取ると、少ない房でも木全体に散らばる）
        var left = tips.filter { $0.point.x < 50 }.shuffled(using: &rng)
        var right = tips.filter { $0.point.x >= 50 }.shuffled(using: &rng)
        var ordered: [Tip] = []
        while !left.isEmpty || !right.isEmpty {
            if let tip = left.popLast() { ordered.append(tip) }
            if let tip = right.popLast() { ordered.append(tip) }
        }
        return Tree(segments: segments, tips: ordered)
    }

    /// 根元が太く先が細い枝の輪郭（曲線の左右に幅をつけて閉じる）
    private static func taperedPath(from start: CGPoint, control: CGPoint, to end: CGPoint, startWidth: CGFloat, endWidth: CGFloat) -> Path {
        func offset(_ p: CGPoint, toward q: CGPoint, by w: CGFloat) -> (CGPoint, CGPoint) {
            let dx = q.x - p.x, dy = q.y - p.y
            let len = max(sqrt(dx * dx + dy * dy), 0.001)
            let nx = -dy / len * w / 2, ny = dx / len * w / 2
            return (CGPoint(x: p.x + nx, y: p.y + ny), CGPoint(x: p.x - nx, y: p.y - ny))
        }
        let (s1, s2) = offset(start, toward: control, by: startWidth)
        let (e1, e2) = offset(end, toward: control, by: endWidth)
        let (c1, c2) = offset(control, toward: end, by: (startWidth + endWidth) / 2)
        var path = Path()
        path.move(to: s1)
        path.addQuadCurve(to: e2, control: c1)
        path.addLine(to: e1)
        path.addQuadCurve(to: s2, control: c2)
        path.closeSubpath()
        return path
    }
}

/// 決まった並びの乱数（毎回同じ木を描くため）
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func next(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
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
