import SpriteKit

final class EffectNode: SKSpriteNode {
    convenience init(name: String, frames: Int, color: SKColor, size: CGSize, frameTime: TimeInterval = 0.07) {
        let textures = SpriteSheet.shared.effect(named: name, count: frames, size: 96, color: color)
        self.init(texture: textures.first, color: .clear, size: size)
        texture?.filteringMode = .nearest
        run(.sequence([.animate(with: textures, timePerFrame: frameTime), .removeFromParent()]))
    }
}
