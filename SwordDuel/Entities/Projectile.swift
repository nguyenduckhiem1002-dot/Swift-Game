import SpriteKit

final class Projectile: SKNode {
    let owner: Fighter
    let damage: Int
    let direction: CGFloat
    let rise: CGFloat
    var life: CGFloat = 2.2
    var didHit = false
    let visual: SKSpriteNode
    init(owner: Fighter, damage: Int, direction: CGFloat, rise: CGFloat = 0) {
        self.owner = owner; self.damage = damage; self.direction = direction; self.rise = rise
        let frames = SpriteSheet.shared.effect(named: SpriteSheet.shared.effectName("projectile", character: owner.data), count: 4, color: owner.data.accentColor)
        visual = SKSpriteNode(texture: frames.first)
        super.init()
        visual.size = CGSize(width: 42, height: 34)
        visual.xScale = direction
        addChild(visual)
        position = CGPoint(x: owner.position.x + direction * 25, y: owner.position.y + 32)
        if rise != 0 { visual.zRotation = atan2(rise, 180) * direction }
        visual.run(.repeatForever(.animate(with: frames, timePerFrame: 0.09)))
    }
    required init?(coder: NSCoder) { fatalError() }
    var hitbox: CGRect { CGRect(x: position.x - 16, y: position.y - 9, width: 32, height: 18) }
    func updateFixed(_ dt: CGFloat) {
        position.x += direction * 180 * dt
        position.y += rise * dt
        life -= dt
        if life <= 0 || position.x < -25 || position.x > 505 || position.y < 36 || position.y > 280 { removeFromParent() }
    }
}
