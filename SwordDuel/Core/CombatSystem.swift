import SpriteKit
import UIKit

/// Anything a fighter's attacks can hit: the other fighter in 1v1, monsters in a stage.
protocol CombatTarget: AnyObject {
    var position: CGPoint { get set }
    var velocity: CGVector { get set }
    var hurtbox: CGRect { get }
    /// False while knocked out, dead or still spawning.
    var canBeHit: Bool { get }
    /// Whether the last landed hit was blocked; blocked hits skip on-hit effects.
    var lastHitGuarded: Bool { get }
    /// Applies a hit and returns the damage dealt (0 when it did not land).
    func takeCombatHit(damage: Int, knockback: CGFloat, unblockable: Bool) -> Int
    func applyEffect(_ effect: HitEffect)
}

extension Fighter: CombatTarget {
    var canBeHit: Bool { hp > 0 }
    func takeCombatHit(damage: Int, knockback: CGFloat, unblockable: Bool) -> Int {
        takeHit(damage: damage, knockback: knockback, unblockable: unblockable)
    }
}

extension Monster: CombatTarget {
    /// Monsters never block.
    var lastHitGuarded: Bool { false }
    func takeCombatHit(damage: Int, knockback: CGFloat, unblockable: Bool) -> Int {
        takeHit(damage: damage, knockback: knockback)
    }
}

/// The scene side of combat: who can be hit and how a landed hit feels.
protocol CombatHost: AnyObject {
    /// Targets the attacker's melee, projectiles, teleports and phantom can reach.
    func combatTargets(for attacker: Fighter) -> [CombatTarget]
    /// Targets an ULT strikes: the opponent in 1v1, every on-screen monster in a stage.
    func combatUltTargets(for attacker: Fighter) -> [CombatTarget]
    /// Arena x at the screen center; ULT effects and callouts stay on screen around it.
    var combatCameraX: CGFloat { get }
    /// Scene feedback after a landed hit, such as hit-stop and screen shake.
    func combatDidLandHit(attacker: Fighter, target: CombatTarget)
    func combatDidAwaken(_ fighter: Fighter)
}

/// Fighter combat shared by 1v1 and stage mode: move effects (projectiles, SK3 buffs, ULTs, teleports),
/// melee hits, projectiles, delayed hits, the damage pipeline, awakening gains, the combo counter and callouts.
final class CombatSystem {
    private struct PendingHit {
        enum Kind { case ult, echo, summon }
        var time: CGFloat
        let attacker: Fighter
        /// nil: a phantom strike picks the nearest target when it lands.
        let target: CombatTarget?
        let damage: Int
        let unblockable: Bool
        let kind: Kind
        var effect: HitEffect? = nil
        var knockback: CGFloat = 0
    }
    private struct HitKey: Hashable {
        let attacker: ObjectIdentifier
        let target: ObjectIdentifier
    }

    weak var host: CombatHost?
    /// Arena-space layer for projectiles, effects and callouts.
    let world: SKNode
    /// Screen-space layer (the scene) for the ULT darkening, the combo counter and centered callouts.
    private weak var screen: SKNode?
    let arenaWidth: CGFloat
    /// How far an SK2 teleport may reach for a target.
    var teleportRange: CGFloat = .greatestFiniteMagnitude
    /// Screen y for arena-wide callouts.
    var screenCalloutY: CGFloat = 180
    /// This fighter's landed hits drive the combo counter.
    weak var comboFighter: Fighter?
    private(set) var projectiles: [Projectile] = []
    private var pending: [PendingHit] = []
    /// One melee swing lands once per target.
    private var landed: [HitKey: Int] = [:]
    private var comboHits = 0
    private var comboTimer: CGFloat = 0
    private let comboLabel = Theme.label("", size: 10, color: Theme.gold)
    private let ultOverlay = SKSpriteNode(color: .black, size: CGSize(width: 480, height: 270))
    private var debugNodes: [SKNode] = []

    init(world: SKNode, screen: SKNode, arenaWidth: CGFloat) {
        self.world = world; self.screen = screen; self.arenaWidth = arenaWidth
        ultOverlay.anchorPoint = .zero; ultOverlay.alpha = 0; ultOverlay.zPosition = 40; screen.addChild(ultOverlay)
        comboLabel.position = CGPoint(x: 138, y: 117); comboLabel.zPosition = 60; screen.addChild(comboLabel)
    }

    // MARK: Lifecycle

    /// Clears projectiles, delayed hits and the combo for a new round or stage.
    func reset() {
        projectiles.forEach { $0.removeFromParent() }; projectiles.removeAll()
        pending.removeAll(); landed.removeAll()
        comboHits = 0; comboTimer = 0; comboLabel.text = ""
    }
    /// Feedback timers that keep running while a round or stage is ending.
    func updateTimers(_ dt: CGFloat) {
        if comboTimer > 0 { comboTimer -= dt; if comboTimer <= 0 { comboHits = 0; comboLabel.text = "" } }
    }
    /// One fixed step: move effects and melee for each attacker, then projectiles and delayed hits.
    func update(_ dt: CGFloat, attackers: [Fighter]) {
        for attacker in attackers { handleMove(attacker) }
        updateProjectiles(dt)
        resolvePendingHits(dt)
    }
    func addProjectile(_ projectile: Projectile) {
        projectile.arenaWidth = arenaWidth
        projectile.zPosition = 20; world.addChild(projectile); projectiles.append(projectile)
    }

    // MARK: Moves

    private func handleMove(_ attacker: Fighter) {
        guard let move = attacker.currentMove, let info = attacker.data.moves[move] else { return }
        let shots = move == "skill1" ? max(0, info.projectiles ?? 1) : 0
        let enhanced = (move == "skill1" || move == "skill2") && attacker.awakeningTier >= 2
        if shots > 0, !attacker.emitted, attacker.currentFrame >= info.activeStart {
            attacker.markEmitted()
            // A fan splits the move's total damage; each projectile can land once.
            for index in 0..<shots {
                let damage = info.damage / shots + (index < info.damage % shots ? 1 : 0)
                let rise = (CGFloat(index) - CGFloat(shots - 1) / 2) * 42
                addProjectile(Projectile(owner: attacker, damage: max(1, damage), direction: attacker.facing, rise: rise,
                                         effect: hitEffect(info, enhanced: enhanced), enhanced: enhanced))
            }
        }
        if let name = info.buff, move != "ult", !attacker.emitted, attacker.currentFrame >= info.activeStart {
            attacker.markEmitted()
            castBuff(name, info: info, caster: attacker)
        }
        if move == "ult", !attacker.emitted, attacker.currentFrame >= info.activeStart {
            attacker.markEmitted()
            castUlt(attacker)
        }
        if info.teleport == true, !attacker.emitted, attacker.currentFrame >= info.activeStart {
            attacker.markEmitted()
            if let target = nearestTarget(for: attacker, within: teleportRange) {
                attacker.position.x = min(attacker.arenaMaxX, max(attacker.arenaMinX, target.position.x + (attacker.position.x < target.position.x ? 27 : -27)))
                attacker.facing = attacker.position.x < target.position.x ? 1 : -1
            }
            showEffect("dash_trail", at: attacker.position, color: attacker.data.accentColor)
        }
        let boxes = attacker.hitboxes(for: move)
        guard shots == 0, move != "ult", info.damage > 0, !boxes.isEmpty else { return }
        for target in host?.combatTargets(for: attacker) ?? [] where target.canBeHit && boxes.contains(where: { $0.intersects(target.hurtbox) }) {
            let key = HitKey(attacker: ObjectIdentifier(attacker), target: ObjectIdentifier(target))
            guard landed[key] != attacker.attackSerial else { continue }
            let dealt = registerHit(attacker: attacker, target: target, damage: info.damage, knockback: attacker.facing * info.knockback,
                        effect: hitEffect(info, enhanced: enhanced), enhanced: enhanced)
            if dealt > 0 { landed[key] = attacker.attackSerial }
        }
    }
    private func hitEffect(_ info: MoveData, enhanced: Bool) -> HitEffect? {
        guard enhanced, let extra = info.enhanced else { return info.onHit }
        return (info.onHit ?? HitEffect()).merged(with: extra)
    }
    /// SK3: apply the caster's buff; a summon also schedules its phantom's three strikes.
    private func castBuff(_ name: String, info: MoveData, caster: Fighter) {
        guard let buff = Buff(rawValue: name) else { return }
        let duration = info.buffTime ?? 3
        caster.apply(buff, for: duration)
        if buff != .meditate, let heal = info.heal { caster.heal(heal) }
        if buff == .summon {
            for strike in 1...3 {
                pending.append(PendingHit(time: duration * CGFloat(strike) / 4, attacker: caster, target: nil, damage: 5, unblockable: false, kind: .summon))
            }
        }
        showEffect("skill1_impact", at: CGPoint(x: caster.position.x, y: caster.position.y + 30), color: caster.data.accentColor)
        callout(info.title, over: caster)
    }
    /// The ULT strikes every host ULT target three times; the once-per-awakening version uses its spec damage
    /// split over `hits`, plus its buff, heal or pull.
    private func castUlt(_ attacker: Fighter) {
        let awakened = attacker.consumeAwakenedUlt() ? attacker.data.moves["ultAwakened"] : nil
        ultOverlay.removeAllActions(); ultOverlay.alpha = awakened == nil ? 0.65 : 0.75
        ultOverlay.run(.sequence([.wait(forDuration: awakened == nil ? 0.5 : 0.9), .fadeOut(withDuration: awakened == nil ? 0.25 : 0.3)]))
        let size = awakened == nil ? CGSize(width: 250, height: 130) : CGSize(width: 320, height: 170)
        let effect = EffectNode(name: SpriteSheet.shared.effectName("ult", character: attacker.data), frames: 8, color: attacker.data.accentColor, size: size, frameTime: 0.08)
        effect.position = CGPoint(x: host?.combatCameraX ?? 240, y: 110); effect.zPosition = 45; world.addChild(effect)
        let targets = host?.combatUltTargets(for: attacker) ?? []
        guard let spec = awakened else {
            for target in targets {
                for (index, delay) in [CGFloat(0), 0.13, 0.26].enumerated() {
                    pending.append(PendingHit(time: delay, attacker: attacker, target: target, damage: index == 2 ? 11 : 12,
                                              unblockable: index == 0, kind: .ult, knockback: attacker.facing * 18))
                }
            }
            return
        }
        callout(spec.title, over: attacker, color: Theme.awaken, size: 10)
        if let name = spec.buff, let buff = Buff(rawValue: name) { attacker.apply(buff, for: spec.buffTime ?? 3) }
        if let heal = spec.heal { attacker.heal(heal) }
        let hits = max(1, spec.hits ?? 4)
        for target in targets {
            if spec.pull == true {
                target.position.x = min(attacker.arenaMaxX, max(attacker.arenaMinX, attacker.position.x + attacker.facing * 40))
                target.velocity = .zero
                for projectile in projectiles where projectile.owner === target { projectile.removeFromParent() }
            }
            for index in 0..<hits {
                let last = index == hits - 1
                pending.append(PendingHit(time: (spec.delay ?? 0) + CGFloat(index) * (spec.hitInterval ?? 0.15), attacker: attacker, target: target,
                                          damage: spec.damage / hits + (index < spec.damage % hits ? 1 : 0),
                                          unblockable: spec.unblockable == true || index == 0, kind: .ult,
                                          effect: last ? spec.onHit : nil, knockback: attacker.facing * (last ? spec.knockback : 18)))
            }
        }
    }
    private func nearestTarget(for attacker: Fighter, within range: CGFloat) -> CombatTarget? {
        (host?.combatTargets(for: attacker) ?? [])
            .filter { $0.canBeHit && abs($0.position.x - attacker.position.x) <= range }
            .min { abs($0.position.x - attacker.position.x) < abs($1.position.x - attacker.position.x) }
    }

    // MARK: Projectiles and delayed hits

    private func updateProjectiles(_ dt: CGFloat) {
        for projectile in projectiles {
            projectile.updateFixed(dt)
            defer { projectile.removeIfExpired() }
            guard !projectile.didHit, projectile.parent != nil,
                  let contact = (host?.combatTargets(for: projectile.owner) ?? [])
                    .filter({ $0.canBeHit && !(($0 as? Fighter)?.invulnerable ?? false) && !(($0 as? Fighter)?.has(.vanish) ?? false) })
                    .compactMap({ target -> (CombatTarget, CGFloat)? in
                        guard let time = projectile.contactTime(with: target.hurtbox) else { return nil }
                        return (target, time)
                    }).min(by: { $0.1 < $1.1 })
            else { continue }
            let target = contact.0
            projectile.moveToContact(contact.1)
            if let fighter = target as? Fighter {
                if fighter.isReflecting {
                    projectile.reflect(to: fighter)
                    showEffect("hit_spark", at: projectile.position, color: fighter.data.accentColor)
                    continue
                }
                if fighter.has(.vanish) { continue }
            }
            projectile.didHit = true
            registerHit(attacker: projectile.owner, target: target, damage: projectile.damage, knockback: projectile.direction * 48 * projectile.pushScale,
                        effect: projectile.effect, enhanced: projectile.enhanced)
            showEffect("skill1_impact", at: projectile.position, color: projectile.owner.data.accentColor)
            projectile.removeFromParent()
        }
        projectiles.removeAll { $0.parent == nil }
    }
    private func resolvePendingHits(_ dt: CGFloat) {
        // Indices are captured up front; echoes appended during the loop resolve on a later step.
        for index in pending.indices.reversed() {
            pending[index].time -= dt
            guard pending[index].time <= 0 else { continue }
            let hit = pending.remove(at: index)
            switch hit.kind {
            case .ult:
                guard let target = hit.target, target.canBeHit else { continue }
                registerHit(attacker: hit.attacker, target: target, damage: hit.damage, knockback: hit.knockback, unblockable: hit.unblockable,
                            effect: hit.effect, scaled: false, allowEcho: false)
            case .echo:
                guard hit.attacker.has(.clone), hit.attacker.hp > 0, let target = hit.target, target.canBeHit else { continue }
                registerHit(attacker: hit.attacker, target: target, damage: hit.damage, knockback: hit.knockback, scaled: false, allowEcho: false)
            case .summon:
                guard hit.attacker.has(.summon), hit.attacker.hp > 0, let target = nearestTarget(for: hit.attacker, within: 170) else { continue }
                let dx = target.position.x - hit.attacker.position.x, home = -24 * hit.attacker.facing
                hit.attacker.phantom.run(.sequence([.moveTo(x: dx - 14 * hit.attacker.facing, duration: 0.08), .wait(forDuration: 0.08),
                                                    .moveTo(x: home, duration: 0.14)]), withKey: "strike")
                registerHit(attacker: hit.attacker, target: target, damage: hit.damage, knockback: hit.attacker.facing * 20, allowEcho: false)
            }
        }
    }

    // MARK: Damage pipeline

    /// `scaled` applies awakening, tier II, frenzy and empower bonuses; ULT hits keep their fixed spec damage.
    /// Returns the damage dealt.
    @discardableResult
    func registerHit(attacker: Fighter, target: CombatTarget, damage: Int, knockback: CGFloat, unblockable: Bool = false,
                     effect: HitEffect? = nil, enhanced: Bool = false, scaled: Bool = true, allowEcho: Bool = true) -> Int {
        let empowered = scaled && attacker.has(.empower)
        var amount = CGFloat(damage)
        if scaled { amount *= attacker.damageMultiplier(enhanced: enhanced) * (empowered ? 1.5 : 1) }
        let dealt = target.takeCombatHit(damage: max(1, Int(amount.rounded())), knockback: knockback, unblockable: unblockable)
        guard dealt > 0 else { return 0 }
        if empowered { _ = attacker.consumeEmpower() }
        attacker.gainEnergy(8)
        gainAwakening(attacker, 6, versus: target)
        if let defender = target as? Fighter { gainAwakening(defender, defender.lastHitGuarded ? 4 : 3, versus: attacker) }
        if !target.lastHitGuarded {
            if let effect {
                target.applyEffect(effect)
                if let drain = effect.drain { attacker.heal(max(1, Int((CGFloat(dealt) * drain).rounded()))) }
            }
            if attacker.has(.frenzy) { attacker.heal(max(1, Int((CGFloat(dealt) * 0.2).rounded()))) }
        }
        if allowEcho && attacker.has(.clone) {
            // The shadow clone repeats the hit at 40% a moment later.
            pending.append(PendingHit(time: 0.12, attacker: attacker, target: target, damage: max(1, damage * 2 / 5),
                                      unblockable: false, kind: .echo, knockback: knockback))
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let box = target.hurtbox
        showEffect("hit_spark", at: CGPoint(x: box.midX, y: box.minY + min(28, box.height / 2)), color: attacker.data.accentColor)
        if attacker === comboFighter {
            comboHits = comboTimer > 0 ? comboHits + 1 : 1
            comboTimer = 1.1
            comboLabel.text = comboHits >= 2 ? "\(comboHits) HIT COMBO!" : ""
        }
        host?.combatDidLandHit(attacker: attacker, target: target)
        return dealt
    }
    /// Awakening gains; a fighter trailing an opposing fighter in HP charges 50% faster.
    func gainAwakening(_ fighter: Fighter, _ amount: CGFloat, versus other: CombatTarget?) {
        let trailing = (other as? Fighter).map { fighter.hp < $0.hp } ?? false
        guard fighter.gainAwakening(amount * (trailing ? 1.5 : 1)) else { return }
        callout("THỨC TỈNH!", over: fighter, color: Theme.awaken, size: 11)
        showEffect("hit_spark", at: CGPoint(x: fighter.position.x, y: fighter.position.y + 30), color: Theme.awaken)
        host?.combatDidAwaken(fighter)
    }
    /// Unblockable terrain damage with an optional launch and stun. Returns whether it landed.
    func applyArenaHit(_ fighter: Fighter, damage: Int, knockback: CGFloat, launch: CGFloat, stun: CGFloat, color: SKColor) -> Bool {
        let dealt = fighter.takeHit(damage: damage, knockback: knockback, unblockable: true)
        guard dealt > 0 else { return false }
        if launch > 0 && fighter.hp > 0 { fighter.velocity.dy = launch; fighter.onGround = false }
        if stun > 0 { fighter.applyEffect(HitEffect(stun: stun)) }
        gainAwakening(fighter, 3, versus: host?.combatTargets(for: fighter).first)
        showEffect("hit_spark", at: CGPoint(x: fighter.position.x, y: fighter.position.y + 30), color: color)
        return true
    }

    // MARK: Effects and callouts

    func showEffect(_ name: String, at point: CGPoint, color: SKColor) {
        let effect = EffectNode(name: name, frames: name == "dash_trail" ? 4 : 5, color: color, size: CGSize(width: 58, height: 58))
        effect.position = point; effect.zPosition = 35; world.addChild(effect)
    }
    /// `point` is in arena coordinates and is kept on screen; nil shows the text at screen center.
    func callout(_ text: String?, at point: CGPoint?, color: SKColor, size: CGFloat = 8) {
        guard let text, !text.isEmpty else { return }
        let label = Theme.label(text, size: size, color: color)
        label.zPosition = 61
        if let point {
            let center = host?.combatCameraX ?? 240
            label.position = CGPoint(x: min(center + 200, max(center - 200, point.x)), y: min(200, point.y))
            world.addChild(label)
        } else {
            guard let screen else { return }
            label.position = CGPoint(x: 240, y: screenCalloutY); screen.addChild(label)
        }
        label.run(.sequence([.group([.moveBy(x: 0, y: 12, duration: 1.1), .sequence([.wait(forDuration: 0.7), .fadeOut(withDuration: 0.4)])]), .removeFromParent()]))
    }
    func callout(_ text: String?, over fighter: Fighter, color: SKColor? = nil, size: CGFloat = 8) {
        callout(text, at: CGPoint(x: fighter.position.x, y: fighter.position.y + 84), color: color ?? fighter.data.accentColor, size: size)
    }

    // MARK: Hitbox overlay

    /// Redraws hurt (green), hit (red) and projectile (yellow) boxes, plus any extra boxes from the host.
    func drawDebug(fighters: [Fighter], extra: [(CGRect, SKColor)] = []) {
        clearDebug()
        var boxes = extra
        for fighter in fighters {
            boxes.append((fighter.hurtbox, .green))
            if let move = fighter.currentMove { boxes += fighter.hitboxes(for: move).map { ($0, .red) } }
        }
        for projectile in projectiles { boxes.append((projectile.hitbox, .yellow)) }
        for (rect, color) in boxes {
            let node = HitboxSystem.debugRect(rect, color: color); world.addChild(node); debugNodes.append(node)
        }
    }
    func clearDebug() { debugNodes.forEach { $0.removeFromParent() }; debugNodes.removeAll() }
}
