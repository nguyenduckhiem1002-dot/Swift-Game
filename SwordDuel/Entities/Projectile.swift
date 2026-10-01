import SpriteKit

final class Projectile: SKNode {
    private(set) var owner: Fighter
    let damage: Int
    private(set) var direction: CGFloat
    let rise: CGFloat
    /// On-hit effect and tier II enhancement, captured when the projectile is fired.
    let effect: HitEffect?
    let enhanced: Bool
    var life: CGFloat = 2.2
    /// Set each step by the arena: tailwind 1.3, headwind and sandstorm slower.
    var speedScale: CGFloat = 1
    var pushScale: CGFloat = 1
    var arenaWidth: CGFloat = 480
    var didHit = false
    let visual: SKSpriteNode
    init(owner: Fighter, damage: Int, direction: CGFloat, rise: CGFloat = 0, effect: HitEffect? = nil, enhanced: Bool = false) {
        self.owner = owner; self.damage = damage; self.direction = direction; self.rise = rise
        self.effect = effect; self.enhanced = enhanced
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
    /// Umbrella counters and reflect buffs send the projectile back at its thrower.
    func reflect(to newOwner: Fighter) {
        owner = newOwner; direction = -direction; life = 2.2
        visual.xScale = direction; visual.zRotation = -visual.zRotation
    }
    var hitbox: CGRect { CGRect(x: position.x - 16, y: position.y - 9, width: 32, height: 18) }
    func updateFixed(_ dt: CGFloat) {
        position.x += direction * 180 * speedScale * dt
        position.y += rise * dt
        life -= dt
        if life <= 0 || position.x < -25 || position.x > arenaWidth + 25 || position.y < 36 || position.y > 280 { removeFromParent() }
    }
}
