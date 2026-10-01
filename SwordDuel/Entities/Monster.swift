import SpriteKit
import UIKit

/// The stage resolves the attacks monsters launch.
protocol MonsterHost: AnyObject {
    func monsterShoot(_ monster: Monster, from point: CGPoint, velocity: CGVector)
    func monsterShockwave(_ monster: Monster, direction: CGFloat)
    func monsterSummon(_ monster: Monster, type: String, count: Int)
    func monsterTelegraph(_ monster: Monster, rect: CGRect, duration: CGFloat)
}

/// A stage enemy. Every attack has a visible wind-up: the body flashes red and slams or charges also mark the ground.
final class Monster: SKNode {
    enum Phase { case spawning, idle, windup, active, recover, hurt, dead }
    let data: MonsterData
    let elite: Bool
    let maxHP: Int
    private(set) var hp: Int
    private(set) var phase: Phase = .spawning
    weak var host: MonsterHost?
    var velocity = CGVector.zero
    private(set) var facing: CGFloat = -1
    var movementXRange: ClosedRange<CGFloat> = 26...454
    /// Live swing or contact hitbox; the stage hits the player once per `attackSerial`.
    private(set) var attackBox: CGRect?
    private(set) var attackSerial = 0
    /// Set by the stage once the kill has been counted.
    var rewarded = false
    private let body: SKSpriteNode
    private let flash: SKSpriteNode
    private let hpBar = SKSpriteNode(color: Theme.fire, size: CGSize(width: 24, height: 2))
    private let baseColor: SKColor
    private var timer: CGFloat = 0.6
    private var cooldown: CGFloat = 0.8
    private var slowTime: CGFloat = 0
    private var burnTicks = 0
    private var burnDamage = 0
    private var burnClock: CGFloat = 0
    private var attackIndex = 0
    private var currentAttack = ""
    private var summonsLeft: [CGFloat] = [0.66, 0.33]
    private var airborne = false
    private var hoverClock = CGFloat.random(in: 0...6)
    private var textures: [SKTexture] = []
    private var animClock: CGFloat = 0

    init(data: MonsterData, elite: Bool, at point: CGPoint) {
        self.data = data; self.elite = elite
        let total = Int(CGFloat(data.hp) * (elite ? 2.5 : 1))
        maxHP = total; hp = total
        baseColor = SKColor(rgb: data.color)
        let size = CGSize(width: data.width * (elite ? 1.25 : 1), height: data.height * (elite ? 1.25 : 1))
        body = SKSpriteNode(color: baseColor, size: size)
        flash = SKSpriteNode(color: .white, size: size)
        super.init()
        position = point
        body.anchorPoint = CGPoint(x: 0.5, y: 0); addChild(body)
        flash.anchorPoint = CGPoint(x: 0.5, y: 0); flash.alpha = 0; flash.zPosition = 2; body.addChild(flash)
        textures = Monster.loadFrames(data)
        if let first = textures.first {
            body.texture = first; body.color = .white
            flash.texture = first
        } else {
            // Placeholder face on the front side; the body flips with facing.
            for offset in [CGFloat(0.12), 0.32] {
                let eye = SKSpriteNode(color: .white, size: CGSize(width: 3, height: 3))
                eye.position = CGPoint(x: size.width * offset, y: size.height * 0.72); eye.zPosition = 1; body.addChild(eye)
            }
        }
        if elite {
            let outline = SKShapeNode(rect: CGRect(x: -size.width / 2 - 2, y: -2, width: size.width + 4, height: size.height + 4))
            outline.strokeColor = Theme.gold; outline.lineWidth = 1.5; outline.zPosition = -1; addChild(outline)
        }
        hpBar.anchorPoint = CGPoint(x: 0, y: 0.5); hpBar.position = CGPoint(x: -12, y: size.height + 6)
        hpBar.isHidden = true; hpBar.zPosition = 3; addChild(hpBar)
        alpha = 0
    }
    required init?(coder: NSCoder) { fatalError() }

    var isDead: Bool { phase == .dead }
    var isBoss: Bool { data.behavior == "boss" }
    var canBeHit: Bool { phase != .dead && phase != .spawning }
    var hpFraction: CGFloat { CGFloat(hp) / CGFloat(max(1, maxHP)) }
    var hurtbox: CGRect { CGRect(x: position.x - body.size.width / 2, y: position.y, width: body.size.width, height: body.size.height) }
    /// Damage dealt to the player, before difficulty scaling.
    var attackDamage: CGFloat { CGFloat(data.damage) * (elite ? 1.5 : 1) }
    private var isFlyer: Bool { data.behavior == "flyer" }
    private var armored: Bool { data.armor ?? false }
    private var secondPhase: Bool { isBoss && hpFraction < 0.5 }

    // MARK: Damage

    /// Returns the damage dealt. Armored monsters keep attacking through hits.
    func takeHit(damage: Int, knockback: CGFloat, stun: CGFloat = 0) -> Int {
        guard canBeHit else { return 0 }
        let dealt = applyDamage(damage)
        guard dealt > 0, phase != .dead, !armored else { return dealt }
        phase = .hurt; timer = max(0.25, stun); attackBox = nil
        velocity.dx = knockback
        if isFlyer { velocity.dy = 0 }
        return dealt
    }
    func applyEffect(_ effect: HitEffect) {
        guard phase != .dead else { return }
        if let slow = effect.slow { slowTime = max(slowTime, slow) }
        if let stun = effect.stun, phase == .hurt { timer = max(timer, stun) }
        if let burn = effect.burn, burn > 0 { burnTicks = 3; burnDamage = max(1, burn / 3); burnClock = 0.5 }
    }
    private func applyDamage(_ amount: Int) -> Int {
        guard phase != .dead, amount > 0 else { return 0 }
        let dealt = min(hp, amount)
        hp -= dealt
        flash.color = .white; flash.alpha = 0.85
        if !isBoss { hpBar.isHidden = false; hpBar.size.width = 24 * hpFraction }
        if let summon = data.summon {
            while let threshold = summonsLeft.first, hpFraction <= threshold, hp > 0 {
                summonsLeft.removeFirst()
                host?.monsterSummon(self, type: summon, count: 2)
            }
        }
        if hp == 0 { die() }
        return dealt
    }
    private func die() {
        phase = .dead; attackBox = nil; velocity = .zero
        run(.sequence([.group([.fadeOut(withDuration: 0.45), .moveBy(x: 0, y: 6, duration: 0.45)]), .removeFromParent()]))
    }

    // MARK: AI

    func update(_ dt: CGFloat, target: Fighter) {
        guard phase != .dead else { return }
        if slowTime > 0 { slowTime = max(0, slowTime - dt) }
        if burnTicks > 0 {
            burnClock -= dt
            if burnClock <= 0 { burnClock = 0.5; burnTicks -= 1; _ = applyDamage(burnDamage) }
            if phase == .dead { return }
        }
        timer -= dt; cooldown -= dt
        let dx = target.position.x - position.x
        let distance = abs(dx)
        let toward: CGFloat = dx >= 0 ? 1 : -1
        let speed = data.speed * (slowTime > 0 ? 0.6 : 1)
        switch phase {
        case .spawning:
            alpha = min(1, max(0, 1 - timer / 0.6))
            if timer <= 0 { alpha = 1; phase = .idle }
        case .hurt:
            velocity.dx *= 0.85
            if timer <= 0 { phase = .idle }
        case .idle:
            facing = toward
            approach(dx: dx, distance: distance, speed: speed, target: target, dt: dt)
            if cooldown <= 0, target.hp > 0, ready(distance: distance) { beginWindup(target: target) }
        case .windup:
            velocity = isFlyer ? .zero : CGVector(dx: 0, dy: velocity.dy)
            if timer <= 0 { beginActive(target: target) }
        case .active:
            updateActive()
        case .recover:
            if isFlyer { velocity = CGVector(dx: 0, dy: position.y < 110 ? 90 : 0) } else { velocity.dx *= 0.8 }
            if timer <= 0 { phase = .idle; cooldown = data.cooldown * (secondPhase ? 0.7 : 1) }
        case .dead:
            break
        }
        integrate(dt)
        updateVisual(dt)
    }
    private func approach(dx: CGFloat, distance: CGFloat, speed: CGFloat, target: Fighter, dt: CGFloat) {
        let toward: CGFloat = dx >= 0 ? 1 : -1
        switch data.behavior {
        case "ranged":
            velocity.dx = distance < 110 ? -toward * speed : distance > data.range ? toward * speed : 0
        case "flyer":
            // Hover on the near side of the player, bobbing, until close enough to dive.
            hoverClock += dt
            let hoverX = target.position.x - toward * 60, hoverY = 110 + sin(hoverClock * 2) * 10
            velocity = CGVector(dx: max(-speed, min(speed, (hoverX - position.x) * 2)), dy: (hoverY - position.y) * 2)
        case "hopper":
            velocity.dx = 0
        default:
            velocity.dx = distance > data.range * 0.8 ? toward * speed : 0
        }
    }
    private func ready(distance: CGFloat) -> Bool {
        switch data.behavior {
        case "ranged": return distance <= data.range + 20 && distance >= 60
        case "boss": return distance <= 260
        case "hopper": return distance <= data.range && !airborne
        default: return distance <= data.range
        }
    }
    private func beginWindup(target: Fighter) {
        phase = .windup
        timer = data.telegraph * (secondPhase ? 0.75 : 1)
        if isBoss, let attacks = data.attacks, !attacks.isEmpty {
            currentAttack = attacks[attackIndex % attacks.count]; attackIndex += 1
        } else { currentAttack = data.behavior }
        let width = body.size.width
        switch currentAttack {
        case "slam":
            let reach: CGFloat = isBoss ? 140 : 90
            let center = isBoss ? position.x : position.x + facing * (width / 2 + 20)
            host?.monsterTelegraph(self, rect: CGRect(x: center - reach / 2, y: 42, width: reach, height: 4), duration: timer)
        case "charge":
            let start = facing > 0 ? position.x : position.x - 220
            host?.monsterTelegraph(self, rect: CGRect(x: start, y: 42, width: 220, height: 4), duration: timer)
        default: break
        }
    }
    private func beginActive(target: Fighter) {
        phase = .active; attackSerial += 1
        let height = body.size.height
        switch currentAttack {
        case "melee":
            timer = 0.22; velocity.dx = facing * 230
        case "ranged":
            timer = 0.1
            host?.monsterShoot(self, from: CGPoint(x: position.x + facing * 14, y: position.y + height * 0.6), velocity: CGVector(dx: facing * 160, dy: 0))
        case "slam":
            timer = 0.15
            if isBoss {
                attackBox = CGRect(x: position.x - 70, y: position.y, width: 140, height: 30)
                host?.monsterShockwave(self, direction: 1); host?.monsterShockwave(self, direction: -1)
            } else {
                let center = position.x + facing * (body.size.width / 2 + 20)
                attackBox = CGRect(x: center - 45, y: position.y, width: 90, height: 30)
            }
        case "flyer":
            timer = 0.55
            let dx = target.position.x - position.x, dy = target.position.y + 24 - position.y
            let length = max(1, sqrt(dx * dx + dy * dy))
            velocity = CGVector(dx: dx / length * 230, dy: dy / length * 230)
        case "hopper":
            timer = 2; airborne = true
            velocity = CGVector(dx: facing * data.speed, dy: 210)
        case "charge":
            timer = 1; velocity.dx = facing * 300
        case "fan":
            timer = 0.2
            let count = secondPhase ? 5 : 3
            for index in 0..<count {
                let spread = (CGFloat(index) - CGFloat(count - 1) / 2) * 30
                host?.monsterShoot(self, from: CGPoint(x: position.x + facing * 20, y: position.y + height * 0.6), velocity: CGVector(dx: facing * 160, dy: spread))
            }
        default:
            timer = 0.1
        }
    }
    private func updateActive() {
        switch currentAttack {
        case "melee":
            attackBox = CGRect(x: facing > 0 ? position.x : position.x - 34, y: position.y + 4, width: 34, height: 26)
            if timer <= 0 { endActive(recover: 0.5) }
        case "flyer", "charge":
            attackBox = hurtbox
            if timer <= 0 { endActive(recover: currentAttack == "charge" ? 0.7 : 0.6) }
        case "hopper":
            attackBox = hurtbox
            if !airborne || timer <= 0 { endActive(recover: 0.2) }
        default:
            if timer <= 0 { endActive(recover: isBoss ? 0.7 : (currentAttack == "slam" ? 0.8 : 0.4)) }
        }
    }
    private func endActive(recover: CGFloat) {
        phase = .recover; timer = recover; attackBox = nil
        if !isFlyer { velocity.dx = 0 }
    }
    private func integrate(_ dt: CGFloat) {
        if isFlyer {
            position.x += velocity.dx * dt
            position.y = min(170, max(46, position.y + velocity.dy * dt))
        } else {
            velocity.dy -= 440 * dt
            position.y += velocity.dy * dt
            if position.y <= 42 { position.y = 42; velocity.dy = 0; airborne = false }
            position.x += velocity.dx * dt
        }
        let clamped = min(movementXRange.upperBound, max(movementXRange.lowerBound, position.x))
        if clamped != position.x {
            position.x = clamped
            // A charge ends at the arena wall.
            if phase == .active && currentAttack == "charge" { timer = 0 }
        }
    }
    private func updateVisual(_ dt: CGFloat) {
        body.xScale = facing
        if textures.count > 1 {
            animClock += dt
            body.texture = textures[Int(animClock * 8) % textures.count]
        }
        if phase == .windup {
            flash.color = Theme.fire
            flash.alpha = Int(timer * 12) % 2 == 0 ? 0.6 : 0.15
        } else {
            flash.alpha = max(0, flash.alpha - dt * 5)
        }
        if slowTime > 0 { body.colorBlendFactor = 0.3; body.color = textures.isEmpty ? baseColor.withAlphaComponent(0.75) : Theme.ice }
        else if textures.isEmpty { body.color = baseColor } else { body.colorBlendFactor = 0 }
    }

    private static func loadFrames(_ data: MonsterData) -> [SKTexture] {
        guard let count = data.frames, count > 0,
              let url = Bundle.main.url(forResource: data.id, withExtension: "png", subdirectory: "Assets/Monsters"),
              let image = UIImage(contentsOfFile: url.path)?.cgImage, image.width >= count else { return [] }
        let frameWidth = image.width / count
        return (0..<count).compactMap { index in
            guard let crop = image.cropping(to: CGRect(x: index * frameWidth, y: 0, width: frameWidth, height: image.height)) else { return nil }
            let texture = SKTexture(cgImage: crop); texture.filteringMode = .nearest
            return texture
        }
    }
}
