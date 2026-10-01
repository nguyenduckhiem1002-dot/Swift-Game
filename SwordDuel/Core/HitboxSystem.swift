import SpriteKit

enum HitboxSystem {
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
