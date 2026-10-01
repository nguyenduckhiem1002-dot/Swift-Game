import SpriteKit

/// Timed self-effects from SK3 and awakened ULTs.
enum Buff: String {
    case guardian     // -50% incoming damage, no knockback
    case frenzy       // +25% speed, +15% damage, 20% lifesteal
    case glide        // one extra air jump and slow falling
    case vanish       // untargetable by projectiles; grants empower
    case empower      // next landed hit +50%
    case meditate     // heal and cleanse on completion; any hit interrupts
    case clone        // shadow echo repeats landed melee hits; grants empower
    case summon       // phantom ally strikes three times
    case reflect      // projectiles bounce back
    case superArmor   // hits do not stagger or push
    case giant        // awakened beast form
}

final class Fighter: SKNode {
    static let awakenedDuration: CGFloat = 12
    let data: CharacterData
    let isPlayer: Bool
    let sprite = SKSpriteNode()
    /// Demon clone silhouette and herder phantom; both mirror the fighter's current frame.
    let echo = SKSpriteNode()
    let phantom = SKSpriteNode()
    private let aura = SKShapeNode(ellipseOf: CGSize(width: 46, height: 70))
    private var animation: AnimationController!
    var state: FighterState = .idle
    var hp = 100
    var energy = 0
    var wins = 0
    var velocity = CGVector.zero
    var facing: CGFloat = 1 { didSet { applyScale() } }
    var leftHeld = false
    var rightHeld = false
    var blockHeld = false
    var onGround = true
    var invulnerable = false
    var stun: CGFloat = 0
    var cooldowns: [String: CGFloat] = [:]
    /// Map modifiers: underwater and astral arenas lower gravity or slow movement.
    var gravityScale: CGFloat = 1
    var moveScale: CGFloat = 1
    var animationScale: CGFloat = 1
    /// Walking limits; wide arenas raise the right one and stage zones move both.
    var arenaMinX: CGFloat = 26
    var arenaMaxX: CGFloat = 454
    /// One-way platforms; the floor at y = 42 is always solid.
    weak var terrain: TerrainSurface?
    /// Awakening meter 0–100. Reaching 100 starts a 12s awakened state, once per round.
    private(set) var awakening: CGFloat = 0
    private(set) var awakenedTime: CGFloat = 0
    private(set) var awakenedThisRound = false
    private(set) var awakenedUltReady = false
    private(set) var buffs: [Buff: CGFloat] = [:]
    private(set) var lastHitGuarded = false
    private(set) var slowTime: CGFloat = 0
    private var burnTicks = 0
    private var burnDamage = 0
    private var burnClock: CGFloat = 0
    private var airJumps = 0
    private var visualScale: CGFloat = 1 { didSet { applyScale() } }
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
        sprite.size = CGSize(width: data.spriteSize, height: data.spriteSize)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        aura.position = CGPoint(x: 0, y: 30); aura.zPosition = -2; aura.lineWidth = 2
        aura.strokeColor = data.accentColor; aura.fillColor = data.accentColor.withAlphaComponent(0.18)
        aura.isHidden = true; addChild(aura)
        echo.zPosition = -1; echo.isHidden = true; echo.color = data.accentColor; echo.colorBlendFactor = 0.7; addChild(echo)
        phantom.zPosition = 1; phantom.isHidden = true; phantom.color = data.accentColor; phantom.colorBlendFactor = 0.6; addChild(phantom)
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

    // MARK: Awakening

    var isAwakened: Bool { awakenedTime > 0 }
    /// 0: none, I (>=30): SK3, II (>=60): enhanced SK1/SK2, III: awakened.
    var awakeningTier: Int { isAwakened ? 3 : awakening >= 60 ? 2 : awakening >= 30 ? 1 : 0 }
    /// HUD fraction: the meter while charging, remaining awakened time while awakened.
    var awakeningFraction: CGFloat { isAwakened ? awakenedTime / Self.awakenedDuration : awakening / 100 }
    /// Returns true when this gain starts the awakened state.
    @discardableResult func gainAwakening(_ amount: CGFloat) -> Bool {
        guard hp > 0, !isAwakened, amount > 0 else { return false }
        awakening = min(100, awakening + amount)
        guard awakening >= 100 else { return false }
        if awakenedThisRound { awakening = 99; return false }
        awakenedThisRound = true; awakenedUltReady = true; awakenedTime = Self.awakenedDuration
        return true
    }
    /// The first ULT during an awakening is the awakened version.
    func consumeAwakenedUlt() -> Bool {
        guard isAwakened, awakenedUltReady, data.moves["ultAwakened"] != nil else { return false }
        awakenedUltReady = false
        return true
    }
    /// Stage zones each allow one new awakening; a 1v1 round allows one in total.
    func allowNewAwakening() { if !isAwakened { awakenedThisRound = false } }
    func gainEnergy(_ amount: Int) { energy = min(100, energy + amount * (isAwakened ? 2 : 1)) }

    // MARK: Buffs and effects

    func has(_ buff: Buff) -> Bool { (buffs[buff] ?? 0) > 0 }
    func apply(_ buff: Buff, for seconds: CGFloat) {
        buffs[buff] = max(buffs[buff] ?? 0, seconds)
        switch buff {
        case .glide: airJumps = 1
        case .vanish, .clone: buffs[.empower] = max(buffs[.empower] ?? 0, 5)
        case .summon:
            phantom.texture = SpriteSheet.shared.frames(character: data, animation: "idle").first
            phantom.size = CGSize(width: data.spriteSize * 0.55, height: data.spriteSize * 0.55)
            phantom.anchorPoint = CGPoint(x: 0.5, y: 0)
            phantom.removeAllActions(); phantom.position = CGPoint(x: -24 * facing, y: 30)
            phantom.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.5), .moveBy(x: 0, y: -4, duration: 0.5)])), withKey: "bob")
        case .giant: visualScale = 1.35
        default: break
        }
    }
    func removeBuff(_ buff: Buff) { buffs[buff] = nil; buffEnded(buff) }
    /// Takes the empower bonus if present; called once a hit actually lands.
    func consumeEmpower() -> Bool { guard has(.empower) else { return false }; buffs[.empower] = nil; return true }
    /// Outgoing damage multiplier for regular hits (ULT hits use their fixed spec damage).
    func damageMultiplier(enhanced: Bool) -> CGFloat {
        var value: CGFloat = 1
        if isAwakened { value *= 1.2 }
        if enhanced { value *= 1.2 }
        if has(.frenzy) { value *= 1.15 }
        return value
    }
    var isReflecting: Bool {
        if has(.reflect) { return true }
        guard let move = currentMove, let info = data.moves[move], info.reflect == true else { return false }
        return moveTime < (info.dashTime ?? 0.32)
    }
    func heal(_ amount: Int) { if hp > 0 { hp = min(100, hp + amount) } }
    func applyEffect(_ effect: HitEffect) {
        guard hp > 0 else { return }
        if let slow = effect.slow { slowTime = max(slowTime, slow) }
        if let stun = effect.stun, state == .hurt { hurtTime = max(hurtTime, stun) }
        if let burn = effect.burn, burn > 0 { burnTicks = 3; burnDamage = max(1, burn / 3); burnClock = 0.5 }
    }
    func cleanse() { slowTime = 0; burnTicks = 0 }
    /// Small terrain damage (poison mist) that does not stagger.
    func applyChip(_ amount: Int) {
        guard hp > 0, !invulnerable else { return }
        hp = max(0, hp - amount)
        if hp == 0 { state = .ko; animation.set("ko") }
    }
    var standingOnPlatform: Bool { onGround && position.y > 42.5 }

    func reset(at x: CGFloat, facing: CGFloat) {
        position = CGPoint(x: x, y: 42)
        self.facing = facing
        hp = 100; energy = 0; velocity = .zero; onGround = true
        stun = 0; cooldowns.removeAll(); comboStage = 0; comboWindow = 0
        awakening = 0; awakenedTime = 0; awakenedThisRound = false; awakenedUltReady = false
        for buff in Array(buffs.keys) { removeBuff(buff) }
        slowTime = 0; burnTicks = 0; airJumps = 0; lastHitGuarded = false
        invulnerable = false; attackQueued = false; state = .idle; animation.set("idle")
        updateVisuals()
    }
    func jump() {
        guard onGround || airJumps > 0, !state.locksMovement, !blockHeld else { return }
        if !onGround { airJumps -= 1 }
        velocity.dy = data.jumpVelocity ?? 185; onGround = false; state = .jump; animation.set("jump")
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
        if move == "skill3" && awakeningTier < 1 { return false }
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
        var dealt = guarded ? max(1, Int(ceil(Double(damage) * 0.2))) : damage
        if has(.guardian) { dealt = max(1, Int(ceil(Double(dealt) * 0.5))) }
        hp = max(0, hp - dealt)
        gainEnergy(5)
        lastHitGuarded = guarded
        let armored = has(.guardian) || has(.superArmor)
        velocity.dx = armored ? 0 : knockback
        if has(.meditate) { buffs[.meditate] = nil }
        if hp == 0 {
            state = .ko; animation.set("ko")
        } else if !guarded && !has(.superArmor) {
            state = .hurt; animation.set("hurt"); hurtTime = 0.26; stun = 0.24
        }
        return dealt
    }
    func updateFixed(_ dt: CGFloat) {
        if stun > 0 { stun = max(0, stun - dt) }
        if comboWindow > 0 { comboWindow = max(0, comboWindow - dt) }
        if slowTime > 0 { slowTime = max(0, slowTime - dt) }
        for (key, value) in cooldowns { cooldowns[key] = max(0, value - dt) }
        updateBuffs(dt)
        if burnTicks > 0 && hp > 0 {
            burnClock -= dt
            if burnClock <= 0 {
                burnClock = 0.5; burnTicks -= 1
                hp = max(0, hp - burnDamage)
                if hp == 0 { state = .ko; animation.set("ko") }
            }
        }
        if case .hurt = state {
            hurtTime -= dt
            if hurtTime <= 0 { state = .idle; animation.set("idle") }
        }
        if case .attacking(let move) = state {
            moveTime += dt
            let info = data.moves[move]
            let dashTime = info?.dashTime ?? (move == "skill2" ? 0.32 : 0)
            if moveTime < dashTime {
                invulnerable = info?.invulnerable ?? true
                velocity.dx = facing * (info?.dashSpeed ?? 250)
            } else { invulnerable = false }
        }
        if !state.locksMovement {
            if blockHeld && onGround { state = .block; animation.set("crouch_block"); velocity.dx = 0 }
            else {
                let axis: CGFloat = (rightHeld ? 1 : 0) - (leftHeld ? 1 : 0)
                var speed = (data.walkSpeed ?? 83) * moveScale
                if has(.frenzy) { speed *= 1.25 }
                if slowTime > 0 { speed *= 0.6 }
                velocity.dx = axis * speed
                if !onGround { state = .jump; animation.set("jump") }
                else if axis != 0 { state = .walk; animation.set("walk") }
                else { state = .idle; animation.set("idle") }
            }
        }
        // Walking off a platform edge, or a platform vanishing, starts a fall.
        if standingOnPlatform && terrain?.supports(x: position.x, y: position.y) != true { onGround = false }
        if !onGround {
            let floating: CGFloat = has(.glide) && velocity.dy < 0 ? 0.35 : 1
            velocity.dy -= 440 * gravityScale * floating * dt
            let previousY = position.y
            position.y += velocity.dy * dt
            if velocity.dy <= 0, let top = terrain?.landingHeight(x: position.x, from: previousY, to: position.y) {
                position.y = top; velocity.dy = 0; onGround = true
            } else if position.y <= 42 { position.y = 42; velocity.dy = 0; onGround = true }
        }
        position.x = min(arenaMaxX, max(arenaMinX, position.x + velocity.dx * dt))
        if state == .hurt || state == .ko { velocity.dx *= 0.84 }
        let finished = animation.update(dt * animationScale)
        updateVisuals()
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
    private func updateBuffs(_ dt: CGFloat) {
        if awakenedTime > 0 {
            awakenedTime = max(0, awakenedTime - dt)
            if awakenedTime == 0 { awakening = 0; awakenedUltReady = false }
        }
        for (buff, remaining) in buffs {
            let next = remaining - dt
            if next > 0 { buffs[buff] = next } else { buffs[buff] = nil; buffEnded(buff, expired: true) }
        }
    }
    private func buffEnded(_ buff: Buff, expired: Bool = false) {
        switch buff {
        case .meditate:
            // Only an uninterrupted meditation heals; a hit removes the buff before it expires.
            if expired { heal(data.moves["skill3"]?.heal ?? 10); cleanse() }
        case .summon: phantom.removeAllActions(); phantom.isHidden = true
        case .clone: echo.isHidden = true
        case .giant: visualScale = 1
        case .glide: airJumps = 0
        default: break
        }
    }
    private func applyScale() {
        sprite.xScale = facing * visualScale; sprite.yScale = visualScale
    }
    private func updateVisuals() {
        aura.isHidden = !isAwakened
        if isAwakened { aura.alpha = 0.55 + 0.35 * abs(sin(awakenedTime * 4)) }
        alpha = has(.vanish) ? 0.3 : 1
        if has(.guardian) || has(.superArmor) { sprite.color = SKColor(white: 0.85, alpha: 1); sprite.colorBlendFactor = 0.35 }
        else if has(.frenzy) { sprite.color = Theme.fire; sprite.colorBlendFactor = 0.3 }
        else if has(.meditate) { sprite.color = Theme.gold; sprite.colorBlendFactor = 0.3 }
        else { sprite.colorBlendFactor = 0 }
        echo.isHidden = !has(.clone)
        if has(.clone) {
            echo.texture = sprite.texture; echo.size = sprite.size; echo.anchorPoint = sprite.anchorPoint
            echo.xScale = sprite.xScale; echo.yScale = sprite.yScale
            echo.position = CGPoint(x: -26 * facing, y: 0); echo.alpha = 0.45
        }
        phantom.isHidden = !has(.summon)
        phantom.xScale = facing
        if phantom.action(forKey: "strike") == nil { phantom.position.x = -24 * facing }
    }
}
