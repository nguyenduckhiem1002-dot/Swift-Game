import SpriteKit

enum HitboxSystem {
    /// Segment versus expanded target (Minkowski sum): catches fast projectiles
    /// without the false diagonal hits produced by a swept bounding rectangle.
    static func contactTime(from start: CGPoint, to end: CGPoint, halfSize: CGSize, target: CGRect) -> CGFloat? {
        let box = target.insetBy(dx: -halfSize.width, dy: -halfSize.height)
        var enter: CGFloat = 0, leave: CGFloat = 1
        for (origin, delta, low, high) in [(start.x, end.x - start.x, box.minX, box.maxX),
                                          (start.y, end.y - start.y, box.minY, box.maxY)] {
            if abs(delta) < 0.00001 {
                if origin < low || origin > high { return nil }
            } else {
                let a = (low - origin) / delta, b = (high - origin) / delta
                enter = max(enter, min(a, b)); leave = min(leave, max(a, b))
                if enter > leave { return nil }
            }
        }
        return enter
    }
    static func intersects(_ a: CGRect?, _ b: CGRect) -> Bool { a?.intersects(b) == true }
    static func debugRect(_ rect: CGRect, color: SKColor) -> SKShapeNode {
        let node = SKShapeNode(rect: rect)
        node.fillColor = color.withAlphaComponent(0.15)
        node.strokeColor = color
        node.lineWidth = 1
        node.zPosition = 100
        return node
    }
}
