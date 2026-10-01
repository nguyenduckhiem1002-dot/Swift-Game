import SpriteKit

final class Fighter: SKNode {
    let data: CharacterData
    let isPlayer: Bool
    let sprite = SKSpriteNode()
    private var animation: AnimationController!
    var state: FighterState = .idle
    var hp = 100
    var energy = 0
    var wins = 0
    var velocity = CGVector.zero
    var facing: CGFloat = 1 { didSet { sprite.xScale = facing } }
    var leftHeld = false
    var rightHeld = false
    var blockHeld = false
    var onGround = true
    var invulnerable = false
    var stun: CGFloat = 0
    var cooldowns: [String: CGFloat] = [:]
    private(set) var moveTime: CGFloat = 0
    private(set) var attackSerial = 0
    private(set) var emitted = false
    private(set) var landed = false
    private var comboStage = 0
    private var comboWindow: CGFloat = 0
    private var attackQueued = false
    private var hurtTime: CGFloat = 0

    init(data: CharacterData, isPlayer: Bool) {
        self.data = data; self.isPlayer = isPlayer
        super.init()
        sprite.size = CGSize(width: 64, height: 64)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        addChild(sprite)
        animation = AnimationController(sprite: sprite, character: data)
    }
    required init?(coder: NSCoder) { fatalError() }
    var currentFrame: Int { animation.frame }
    var currentMove: String? { if case .attacking(let name) = state { return name }; return nil }
    var hurtbox: CGRect { CGRect(x: position.x - 12, y: position.y + 5, width: 24, height: 48) }
    func hitbox(for move: String) -> CGRect? {
        guard let info = data.moves[move], (info.activeStart...info.activeEnd).contains(currentFrame) else { return nil }
        return info.hitbox.rect(origin: position, facing: facing)
    }
    func reset(at x: CGFloat, facing: CGFloat) {
        position = CGPoint(x: x, y: 42)
        self.facing = facing
        hp = 100; energy = 0; velocity = .zero; onGround = true
        stun = 0; cooldowns.removeAll(); comboStage = 0; comboWindow = 0
        invulnerable = false; attackQueued = false; state = .idle; animation.set("idle")
    }
    func jump() {
        guard onGround, !state.locksMovement, !blockHeld else { return }
        velocity.dy = 185; onGround = false; state = .jump; animation.set("jump")
    }
    func attack() {
        if case .attacking(let move) = state, move.hasPrefix("attack") {
            attackQueued = true; return
        }
        guard !state.locksMovement, !blockHeld else { return }
        comboStage = comboWindow > 0 ? (comboStage % 3) + 1 : 1
        startMove("attack\(comboStage)")
    }
    @discardableResult func use(_ move: String) -> Bool {
        guard !state.locksMovement, !blockHeld, let info = data.moves[move], energy >= info.energyCost, (cooldowns[move] ?? 0) <= 0 else { return false }
        energy -= info.energyCost
        cooldowns[move] = info.cooldown
        comboStage = 0; comboWindow = 0
        startMove(move)
        return true
    }
    private func startMove(_ name: String) {
        state = .attacking(name); animation.set(name); moveTime = 0
        attackSerial += 1; emitted = false; landed = false
    }
    func victoryPose() { state = .win; animation.set("win"); velocity = .zero }
    func markEmitted() { emitted = true }
    func markLanded() { landed = true }
    func takeHit(damage: Int, knockback: CGFloat, unblockable: Bool) -> Int {
        guard hp > 0, !invulnerable else { return 0 }
        let guarded = blockHeld && onGround && !state.locksMovement && !unblockable
        let dealt = guarded ? max(1, Int(ceil(Double(damage) * 0.2))) : damage
        hp = max(0, hp - dealt)
        energy = min(100, energy + 5)
        velocity.dx = knockback
        if hp == 0 {
            state = .ko; animation.set("ko")
        } else if !guarded {
            state = .hurt; animation.set("hurt"); hurtTime = 0.26; stun = 0.24
        }
        return dealt
    }
    func updateFixed(_ dt: CGFloat) {
        if stun > 0 { stun = max(0, stun - dt) }
        if comboWindow > 0 { comboWindow = max(0, comboWindow - dt) }
        for (key, value) in cooldowns { cooldowns[key] = max(0, value - dt) }
        if case .hurt = state {
            hurtTime -= dt
            if hurtTime <= 0 { state = .idle; animation.set("idle") }
        }
        if case .attacking(let move) = state {
            moveTime += dt
            if move == "skill2" && moveTime < 0.32 {
                invulnerable = true
                velocity.dx = facing * 250
            } else { invulnerable = false }
        }
        if !state.locksMovement {
            if blockHeld && onGround { state = .block; animation.set("crouch_block"); velocity.dx = 0 }
            else {
                let axis: CGFloat = (rightHeld ? 1 : 0) - (leftHeld ? 1 : 0)
                velocity.dx = axis * 83
                if !onGround { state = .jump; animation.set("jump") }
                else if axis != 0 { state = .walk; animation.set("walk") }
                else { state = .idle; animation.set("idle") }
            }
        }
        if !onGround {
            velocity.dy -= 440 * dt
            position.y += velocity.dy * dt
            if position.y <= 42 { position.y = 42; velocity.dy = 0; onGround = true }
        }
        position.x = min(454, max(26, position.x + velocity.dx * dt))
        if state == .hurt || state == .ko { velocity.dx *= 0.84 }
        let finished = animation.update(dt)
        if finished, case .attacking(let move) = state {
            invulnerable = false
            if move.hasPrefix("attack") {
                comboWindow = 0.5
                if attackQueued && comboStage < 3 {
                    attackQueued = false; comboStage += 1; startMove("attack\(comboStage)"); return
                }
            }
            attackQueued = false
            state = .idle; animation.set("idle")
        }
    }
}
