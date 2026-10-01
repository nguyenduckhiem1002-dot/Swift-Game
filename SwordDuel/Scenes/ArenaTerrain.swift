import SpriteKit

/// What a fighter needs for one-way platforms; the floor at y = 42 is handled by the fighter.
protocol TerrainSurface: AnyObject {
    func landingHeight(x: CGFloat, from oldY: CGFloat, to newY: CGFloat) -> CGFloat?
    func supports(x: CGFloat, y: CGFloat) -> Bool
}

/// The fight scene applies arena damage so hit-stop, HUD and awakening stay in one place.
protocol TerrainDelegate: AnyObject {
    /// Unattributed, unblockable arena damage. Returns whether it landed.
    func terrainHit(_ fighter: Fighter, damage: Int, knockback: CGFloat, launch: CGFloat, stun: CGFloat, color: SKColor) -> Bool
    func terrainAwakening(_ fighter: Fighter, amount: CGFloat)
    func terrainCallout(_ text: String, at point: CGPoint, color: SKColor)
}

private let floorY: CGFloat = 42
private let lavaColor = SKColor(red: 1, green: 0.42, blue: 0.1, alpha: 1)
private let iceColor = SKColor(red: 0.7, green: 0.92, blue: 1, alpha: 1)
private let poisonColor = SKColor(red: 0.55, green: 0.95, blue: 0.3, alpha: 1)

private final class Platform {
    let kind: String
    let width: CGFloat
    let base: CGPoint
    let node: SKSpriteNode
    var moveX: CGFloat = 0
    var moveY: CGFloat = 0
    var period: CGFloat = 6
    var onTime: CGFloat?
    var offTime: CGFloat = 0
    var crumble = false
    var top: CGPoint
    var solid = true
    /// Seconds until a dissipated or collapsed platform returns.
    var downTime: CGFloat = 0
    var occupied: CGFloat = 0
    var cycle: CGFloat = 0
    init(kind: String, width: CGFloat, at top: CGPoint, color: SKColor) {
        self.kind = kind; self.width = width; base = top; self.top = top
        node = SKSpriteNode(color: color, size: CGSize(width: width, height: kind == "cloud" ? 8 : 6))
        node.anchorPoint = CGPoint(x: 0.5, y: 1); node.position = top
    }
    func contains(_ x: CGFloat) -> Bool { abs(x - top.x) <= width / 2 }
    var rect: CGRect { CGRect(x: top.x - width / 2, y: top.y - 10, width: width, height: 14) }
    func reset() {
        top = base; solid = true; downTime = 0; occupied = 0; cycle = 0
        node.position = base; node.alpha = 1; node.removeAllActions()
    }
}

private final class Zone {
    let kind: String
    let rect: CGRect
    let node: SKSpriteNode
    let cover = SKSpriteNode()
    /// Frozen lava or burned-away poison mist.
    var disabled: CGFloat = 0
    /// Lightning-charged rune.
    var charged: CGFloat = 0
    init(_ data: ZoneData) {
        kind = data.kind
        let height: CGFloat
        let color: SKColor
        switch data.kind {
        case "lava": height = 8; color = lavaColor
        case "poison": height = data.h ?? 60; color = poisonColor.withAlphaComponent(0.26)
        case "rune": height = 3; color = Theme.gold.withAlphaComponent(0.65)
        case "void": height = floorY; color = SKColor(red: 0.02, green: 0.01, blue: 0.05, alpha: 1)
        case "waterfall": height = data.h ?? 228; color = iceColor.withAlphaComponent(0.28)
        default: height = data.h ?? 10; color = SKColor.white.withAlphaComponent(0.2)
        }
        let bottom = data.kind == "void" ? 0 : (data.kind == "lava" ? floorY - 6 : floorY)
        rect = CGRect(x: data.x, y: bottom, width: data.w, height: height)
        node = SKSpriteNode(color: color, size: rect.size)
        node.anchorPoint = .zero; node.position = rect.origin
        cover.anchorPoint = .zero; cover.position = .zero; cover.isHidden = true
        if data.kind == "lava" { cover.color = iceColor; cover.size = CGSize(width: data.w, height: 9) }
        if data.kind == "rune" { cover.color = Theme.gold; cover.size = CGSize(width: data.w, height: 26); cover.alpha = 0.35 }
        node.addChild(cover)
    }
    var harmful: Bool { (kind == "lava" || kind == "poison") && disabled <= 0 }
    func reset() { disabled = 0; charged = 0; cover.isHidden = true; node.isHidden = false }
}

private final class ArenaObject {
    let kind: String
    let home: CGPoint
    let node: SKSpriteNode
    let size: CGSize
    var hp = 3
    var active = true
    /// Respawn, rebuild, reuse or light timer depending on the kind.
    var timer: CGFloat = 0
    var charge = 0
    var owner: Fighter?
    var rubble: Platform?
    var lastSerial: [ObjectIdentifier: Int] = [:]
    init(_ data: ObjectData, accent: SKColor, stone: SKColor) {
        let shape: CGSize
        let color: SKColor
        switch data.kind {
        case "pillar": shape = CGSize(width: 18, height: 70); color = stone
        case "bell": shape = CGSize(width: 20, height: 24); color = Theme.gold
        case "mushroom": shape = CGSize(width: 14, height: 12); color = SKColor(red: 0.95, green: 0.3, blue: 0.35, alpha: 1)
        case "tombstone": shape = CGSize(width: 16, height: 22); color = SKColor(white: 0.45, alpha: 1)
        case "lantern": shape = CGSize(width: 10, height: 16); color = accent
        case "rod": shape = CGSize(width: 5, height: 84); color = SKColor(white: 0.7, alpha: 1)
        case "tablet": shape = CGSize(width: 14, height: 22); color = stone
        case "statue": shape = CGSize(width: 24, height: 60); color = stone
        default: shape = CGSize(width: 12, height: 12); color = accent
        }
        // `y` is the object's center for hanging props; floor props stand on y = 42.
        let center = CGPoint(x: data.x, y: data.y ?? floorY + shape.height / 2)
        kind = data.kind; size = shape; home = center
        node = SKSpriteNode(color: color, size: shape)
        node.position = center
    }
    var rect: CGRect {
        let current = active || kind != "pillar" ? size : CGSize(width: 30, height: 12)
        return CGRect(x: home.x - current.width / 2, y: kind == "pillar" ? floorY : home.y - current.height / 2, width: current.width, height: current.height)
    }
    var hittable: Bool {
        switch kind {
        case "pillar": return active
        case "bell", "lantern", "rod", "tablet": return true
        default: return false
        }
    }
    /// Standing pillars block and absorb projectiles; other props react to melee only.
    var stopsProjectiles: Bool { kind == "pillar" && active }
}

private final class Mover {
    let kind: String
    let node: SKSpriteNode
    var velocity: CGVector
    var life: CGFloat
    var hp: Int
    let damage: Int
    var lastSerial: [ObjectIdentifier: Int] = [:]
    init(kind: String, at point: CGPoint, velocity: CGVector, size: CGSize, color: SKColor, life: CGFloat, hp: Int, damage: Int) {
        self.kind = kind; self.velocity = velocity; self.life = life; self.hp = hp; self.damage = damage
        node = SKSpriteNode(color: color, size: size); node.position = point
    }
    var rect: CGRect { CGRect(x: node.position.x - node.size.width / 2, y: node.position.y - node.size.height / 2, width: node.size.width, height: node.size.height) }
}

private final class TimedEvent {
    let kind: String
    let start: CGFloat
    let interval: CGFloat
    let telegraph: CGFloat
    let duration: CGFloat
    var next: CGFloat
    var warned = false
    var endsAt: CGFloat = -1
    var marker: SKNode?
    init(_ data: EventData) {
        kind = data.kind; start = data.start; interval = max(1, data.interval)
        telegraph = data.telegraph ?? 1.5; duration = data.duration ?? 0; next = data.start
    }
    func reset() { next = start; warned = false; endsAt = -1; marker?.removeFromParent(); marker = nil }
}

/// A telegraphed column strike: geysers, roots and lightning.
private struct Strike {
    var time: CGFloat
    let x: CGFloat
    let kind: String
    let marker: SKNode
    let fromEvent: Bool
}

/// Platforms, hazard zones, interactable props, timed events and element reactions for one map.
final class ArenaTerrain: SKNode, TerrainSurface {
    weak var delegate: TerrainDelegate?
    let map: MapData
    private var platforms: [Platform] = []
    private var zones: [Zone] = []
    private var objects: [ArenaObject] = []
    private var events: [TimedEvent] = []
    private var movers: [Mover] = []
    private var strikes: [Strike] = []
    private var fighters: [Fighter] = []
    private var clock: CGFloat = 0
    private var windDirection: CGFloat = 1
    private var sandstorm = false
    private var currentDirection: CGFloat = 0
    private var darkness = false
    private var debrisFromLeft = true
    private var hazardCooldown: [ObjectIdentifier: CGFloat] = [:]
    private var tickClock: [ObjectIdentifier: CGFloat] = [:]
    private var energyCarry: [ObjectIdentifier: CGFloat] = [:]
    private let overlay = SKNode()
    private let sandOverlay = SKSpriteNode(color: SKColor(red: 0.85, green: 0.68, blue: 0.4, alpha: 1), size: CGSize(width: 480, height: 270))
    private let darkOverlay = SKSpriteNode(color: .black, size: CGSize(width: 480, height: 270))
    private let indicator = Theme.label("", size: 7, color: .white)

    init(map: MapData) {
        self.map = map
        super.init()
        let accent = SKColor(rgb: map.accent)
        let stone = SKColor(rgb: map.mountain).withAlphaComponent(1)
        let terrain = map.terrain
        for data in terrain?.zones ?? [] {
            let zone = Zone(data); zone.node.zPosition = 0; addChild(zone.node); zones.append(zone)
        }
        for data in terrain?.platforms ?? [] {
            let platform = Platform(kind: data.kind, width: data.w, at: CGPoint(x: data.x, y: data.y), color: platformColor(data.kind, accent: accent))
            platform.moveX = data.moveX ?? 0; platform.moveY = data.moveY ?? 0; platform.period = max(1, data.period ?? 6)
            platform.onTime = data.onTime; platform.offTime = data.offTime ?? 0; platform.crumble = data.crumble ?? false
            platform.node.zPosition = 2; addChild(platform.node); platforms.append(platform)
        }
        for data in terrain?.objects ?? [] {
            let object = ArenaObject(data, accent: accent, stone: stone)
            object.node.zPosition = 1; addChild(object.node); objects.append(object)
        }
        events = (terrain?.events ?? []).map(TimedEvent.init)
        overlay.zPosition = 22; addChild(overlay)
        for layer in [sandOverlay, darkOverlay] {
            layer.anchorPoint = .zero; layer.alpha = 0; overlay.addChild(layer)
        }
        indicator.position = CGPoint(x: 240, y: 190); indicator.zPosition = 1; overlay.addChild(indicator)
        reset()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func platformColor(_ kind: String, accent: SKColor) -> SKColor {
        switch kind {
        case "cloud": return SKColor(white: 0.96, alpha: 0.85)
        case "gold": return Theme.gold
        case "chain": return SKColor(red: 0.35, green: 0.27, blue: 0.24, alpha: 1)
        case "coral": return SKColor(rgb: map.structure ?? map.accent)
        case "astral": return accent
        default: return SKColor(rgb: map.mountain)
        }
    }

    // MARK: Fighter support

    func landingHeight(x: CGFloat, from oldY: CGFloat, to newY: CGFloat) -> CGFloat? {
        platforms.filter { $0.solid && $0.contains(x) && oldY >= $0.top.y - 0.5 && newY <= $0.top.y }.map(\.top.y).max()
    }
    func supports(x: CGFloat, y: CGFloat) -> Bool {
        platforms.contains { $0.solid && $0.contains(x) && abs($0.top.y - y) < 1.5 }
    }

    // MARK: Round lifecycle

    func reset() {
        clock = 0; windDirection = 1; sandstorm = false; currentDirection = 0; darkness = false
        hazardCooldown.removeAll(); tickClock.removeAll(); energyCarry.removeAll()
        for object in objects {
            if let rubble = object.rubble { rubble.node.removeFromParent(); platforms.removeAll { $0 === rubble } }
            object.rubble = nil; object.hp = 3; object.active = true; object.timer = 0; object.charge = 0; object.owner = nil
            object.lastSerial.removeAll(); object.node.removeAllActions()
            object.node.size = object.size; object.node.position = object.home; object.node.alpha = 1; object.node.colorBlendFactor = 0
            if object.kind == "lantern" { object.active = false; object.node.alpha = 0.45 }
        }
        platforms.forEach { $0.reset() }
        zones.forEach { $0.reset() }
        events.forEach { $0.reset() }
        movers.forEach { $0.node.removeFromParent() }; movers.removeAll()
        strikes.forEach { $0.marker.removeFromParent() }; strikes.removeAll()
        sandOverlay.alpha = 0; darkOverlay.alpha = 0
        refreshIndicator(blinking: false)
    }

    // MARK: Simulation

    /// Runs after both fighters have moved for this step.
    func updateFixed(_ dt: CGFloat, fighters: [Fighter], projectiles: [Projectile]) {
        self.fighters = fighters
        clock += dt
        updatePlatforms(dt)
        updateZones(dt)
        updateObjects(dt)
        updateProjectiles(projectiles)
        updateEvents()
        updateStrikes(dt)
        updateMovers(dt)
        applyForces(dt, projectiles: projectiles)
        let darkTarget: CGFloat = darkness ? (objects.contains { $0.kind == "lantern" && $0.active } ? 0.3 : 0.62) : warningAlpha("darkness", 0.15)
        darkOverlay.alpha += (darkTarget - darkOverlay.alpha) * min(1, dt * 4)
        let sandTarget: CGFloat = sandstorm ? 0.32 : warningAlpha("sandstorm", 0.12)
        sandOverlay.alpha += (sandTarget - sandOverlay.alpha) * min(1, dt * 4)
    }
    private func warningAlpha(_ kind: String, _ value: CGFloat) -> CGFloat {
        events.contains { $0.kind == kind && $0.warned } ? value : 0
    }
    private func opponent(of fighter: Fighter) -> Fighter? { fighters.first { $0 !== fighter } }
    private func id(_ fighter: Fighter) -> ObjectIdentifier { ObjectIdentifier(fighter) }
    private func hit(_ fighter: Fighter, damage: Int, knockback: CGFloat = 0, launch: CGFloat = 0, stun: CGFloat = 0, color: SKColor) {
        _ = delegate?.terrainHit(fighter, damage: damage, knockback: knockback, launch: launch, stun: stun, color: color)
    }
    private func callout(_ text: String, at point: CGPoint, color: SKColor = Theme.gold) {
        delegate?.terrainCallout(text, at: point, color: color)
    }
    private func onGround(_ fighter: Fighter) -> Bool { fighter.onGround && fighter.position.y <= floorY + 0.5 }

    private func updatePlatforms(_ dt: CGFloat) {
        for platform in platforms {
            let previous = platform.top
            let wasSolid = platform.solid
            platform.cycle += dt
            let phase = sin(platform.cycle / platform.period * 2 * .pi)
            platform.top = CGPoint(x: platform.base.x + platform.moveX * phase, y: platform.base.y + platform.moveY * phase)
            platform.node.position = platform.top
            if let on = platform.onTime {
                let local = platform.cycle.truncatingRemainder(dividingBy: on + platform.offTime)
                platform.solid = local < on
                platform.node.alpha = !platform.solid ? 0.12 : (on - local < 1 && Int(local * 8) % 2 == 0 ? 0.4 : 1)
            } else if platform.downTime > 0 {
                platform.downTime -= dt
                platform.solid = platform.downTime <= 0
                platform.node.alpha = platform.solid ? 1 : 0.12
            }
            let riders = fighters.filter { $0.onGround && wasSolid && abs($0.position.y - previous.y) < 1.5 && abs($0.position.x - previous.x) <= platform.width / 2 }
            if platform.solid {
                // Moving platforms carry whoever stands on them.
                for rider in riders {
                    rider.position.x = min(454, max(26, rider.position.x + platform.top.x - previous.x))
                    rider.position.y = platform.top.y
                }
            }
            if platform.crumble && platform.solid {
                platform.occupied = riders.isEmpty ? max(0, platform.occupied - dt) : platform.occupied + dt
                platform.node.alpha = platform.occupied > 1 && Int(platform.occupied * 10) % 2 == 0 ? 0.5 : 1
                if platform.occupied >= 2 {
                    platform.occupied = 0; platform.solid = false; platform.downTime = 8; platform.node.alpha = 0.12
                    callout("CẦU SẬP!", at: CGPoint(x: platform.top.x, y: platform.top.y + 20), color: lavaColor)
                }
            }
        }
    }

    private func updateZones(_ dt: CGFloat) {
        for key in Array(hazardCooldown.keys) { hazardCooldown[key] = max(0, (hazardCooldown[key] ?? 0) - dt) }
        for zone in zones {
            if zone.disabled > 0 {
                zone.disabled = max(0, zone.disabled - dt)
                if zone.disabled == 0 { zone.cover.isHidden = true; zone.node.isHidden = false }
            }
            if zone.charged > 0 {
                zone.charged = max(0, zone.charged - dt)
                zone.cover.isHidden = zone.charged == 0
            }
            for fighter in fighters where fighter.hp > 0 && fighter.position.x >= zone.rect.minX && fighter.position.x <= zone.rect.maxX {
                let key = id(fighter)
                switch zone.kind {
                case "lava" where zone.harmful && onGround(fighter) && (hazardCooldown[key] ?? 0) <= 0:
                    hazardCooldown[key] = 0.8
                    let away: CGFloat = fighter.position.x < zone.rect.midX ? -1 : 1
                    hit(fighter, damage: 6, knockback: away * 60, launch: 240, color: lavaColor)
                case "void" where onGround(fighter) && (hazardCooldown[key] ?? 0) <= 0:
                    hazardCooldown[key] = 1
                    let left = fighter.position.x < zone.rect.midX
                    fighter.position.x = left ? zone.rect.minX - 10 : zone.rect.maxX + 10
                    hit(fighter, damage: 8, launch: 200, color: SKColor(rgb: map.accent))
                case "poison" where zone.harmful && fighter.position.y < zone.rect.maxY:
                    fighter.applyEffect(HitEffect(slow: 0.25))
                    tickClock[key, default: 0] += dt
                    if (tickClock[key] ?? 0) >= 0.6 { tickClock[key] = 0; fighter.applyChip(1) }
                case "waterfall":
                    fighter.applyEffect(HitEffect(slow: 0.25))
                case "rune" where onGround(fighter):
                    // Runes feed energy; a lightning-charged rune also charges awakening.
                    energyCarry[key, default: 0] += dt * (zone.charged > 0 ? 12 : 4)
                    let whole = Int(energyCarry[key] ?? 0)
                    if whole > 0 { fighter.gainEnergy(whole); energyCarry[key] = (energyCarry[key] ?? 0) - CGFloat(whole) }
                    if zone.charged > 0 { delegate?.terrainAwakening(fighter, amount: dt * 3) }
                default: break
                }
            }
        }
    }

    // MARK: Props

    private func updateObjects(_ dt: CGFloat) {
        for object in objects {
            if object.timer > 0 {
                object.timer = max(0, object.timer - dt)
                if object.timer == 0 { objectTimerEnded(object) }
            }
            if object.kind == "mushroom", object.active {
                for fighter in fighters where fighter.hp > 0 && fighter.hp < 100 && fighter.hurtbox.intersects(object.rect) {
                    fighter.heal(15); object.active = false; object.timer = 12; object.node.alpha = 0.25
                    callout("+15", at: CGPoint(x: object.home.x, y: object.home.y + 24), color: poisonColor)
                    break
                }
            }
            guard object.hittable else { continue }
            for fighter in fighters {
                guard let box = meleeBox(fighter), box.intersects(object.rect), object.lastSerial[id(fighter)] != fighter.attackSerial else { continue }
                object.lastSerial[id(fighter)] = fighter.attackSerial
                hitObject(object, by: fighter)
            }
        }
    }
    private func objectTimerEnded(_ object: ArenaObject) {
        switch object.kind {
        case "pillar":
            if let rubble = object.rubble { rubble.node.removeFromParent(); platforms.removeAll { $0 === rubble } }
            object.rubble = nil; object.active = true; object.hp = 3
            object.node.size = object.size; object.node.position = object.home
        case "mushroom": object.active = true; object.node.alpha = 1
        case "lantern": object.active = false; object.node.alpha = 0.45
        case "bell": object.node.alpha = 1
        default: break
        }
    }
    private func meleeBox(_ fighter: Fighter) -> CGRect? {
        guard let move = fighter.currentMove, let info = fighter.data.moves[move], info.damage > 0 else { return nil }
        return fighter.hitbox(for: move)
    }
    private func hitObject(_ object: ArenaObject, by fighter: Fighter) {
        object.node.run(.sequence([.moveBy(x: 2, y: 0, duration: 0.04), .moveBy(x: -4, y: 0, duration: 0.04), .moveBy(x: 2, y: 0, duration: 0.04)]))
        switch object.kind {
        case "pillar":
            object.hp -= 1
            guard object.hp <= 0 else { return }
            // A broken pillar leaves a low rubble ledge until it reassembles.
            object.active = false; object.timer = 15
            object.node.size = CGSize(width: 30, height: 12); object.node.position = CGPoint(x: object.home.x, y: floorY + 6)
            let rubble = Platform(kind: "stone", width: 30, at: CGPoint(x: object.home.x, y: floorY + 12), color: SKColor(rgb: map.mountain))
            rubble.node.zPosition = 2; addChild(rubble.node); platforms.append(rubble); object.rubble = rubble
            callout("CỘT VỠ!", at: CGPoint(x: object.home.x, y: floorY + 60), color: SKColor(rgb: map.accent))
        case "bell":
            guard object.timer <= 0 else { return }
            object.timer = 12; object.node.alpha = 0.5
            fighter.gainEnergy(15)
            if let target = opponent(of: fighter) { hit(target, damage: 3, stun: 0.6, color: Theme.gold) }
            callout("CHUÔNG!", at: CGPoint(x: object.home.x, y: object.home.y + 22))
        case "lantern":
            object.active = true; object.timer = 12; object.node.alpha = 1
        case "rod":
            if object.owner !== fighter { object.owner = fighter; object.charge = 0 }
            object.charge += 1
            object.node.color = Theme.ice; object.node.colorBlendFactor = CGFloat(object.charge) / 3
            if object.charge >= 3, let target = opponent(of: fighter) {
                object.charge = 0; object.node.colorBlendFactor = 0
                addStrike(kind: "lightning", x: target.position.x, delay: 1, fromEvent: false)
                callout("THU LÔI!", at: CGPoint(x: object.home.x, y: object.home.y + 50), color: Theme.ice)
            }
        case "tablet":
            // The claimant is spared by the next statue beam.
            object.owner = fighter; object.node.color = fighter.data.accentColor; object.node.colorBlendFactor = 0.7
        default: break
        }
    }

    // MARK: Projectiles and element reactions

    private func updateProjectiles(_ projectiles: [Projectile]) {
        for projectile in projectiles where projectile.parent != nil && !projectile.didHit {
            let box = projectile.hitbox
            if elementTouch(projectile.owner.data.color, box: box) { projectile.removeFromParent(); continue }
            if let object = objects.first(where: { $0.stopsProjectiles && $0.rect.intersects(box) }) {
                hitObject(object, by: projectile.owner); projectile.removeFromParent(); continue
            }
            if let mover = movers.first(where: { $0.rect.intersects(box) }) {
                damageMover(mover, by: projectile.owner); projectile.removeFromParent()
            }
        }
        for fighter in fighters {
            if let box = meleeBox(fighter) { _ = elementTouch(fighter.data.color, box: box) }
        }
    }
    /// Ice freezes lava; fire melts it, burns away clouds and detonates poison mist.
    /// Returns true when the touching projectile should be consumed.
    private func elementTouch(_ element: String, box: CGRect) -> Bool {
        guard element == "ice" || element == "fire" else { return false }
        var consumed = false
        for zone in zones where zone.kind == "lava" || zone.kind == "poison" {
            let reach = CGRect(x: zone.rect.minX, y: floorY - 6, width: zone.rect.width, height: zone.kind == "lava" ? 44 : zone.rect.height + 10)
            guard reach.intersects(box) else { continue }
            if zone.kind == "lava" && element == "ice" && zone.disabled <= 0 {
                zone.disabled = 5; zone.cover.isHidden = false
                callout("BĂNG PHONG!", at: CGPoint(x: zone.rect.midX, y: floorY + 30), color: iceColor)
            } else if zone.kind == "lava" && element == "fire" && zone.disabled > 0 {
                zone.disabled = 0; zone.cover.isHidden = true
            } else if zone.kind == "poison" && element == "fire" && zone.disabled <= 0 {
                zone.disabled = 10; zone.node.isHidden = true; consumed = true
                callout("NỔ ĐỘC!", at: CGPoint(x: zone.rect.midX, y: floorY + 40), color: poisonColor)
                // The explosion hurts anyone inside, including the fighter who lit it.
                for fighter in fighters where fighter.position.x > zone.rect.minX - 24 && fighter.position.x < zone.rect.maxX + 24 && fighter.position.y < zone.rect.maxY + 20 {
                    hit(fighter, damage: 10, launch: 150, color: lavaColor)
                }
            }
        }
        if element == "fire" {
            for platform in platforms where platform.kind == "cloud" && platform.solid && platform.onTime == nil && platform.rect.intersects(box) {
                platform.solid = false; platform.downTime = 8; platform.node.alpha = 0.12
                callout("MÂY TAN", at: CGPoint(x: platform.top.x, y: platform.top.y + 16), color: Theme.fire)
            }
        }
        return consumed
    }

    // MARK: Timed events

    private func updateEvents() {
        for event in events {
            if !event.warned && clock >= event.next - event.telegraph {
                event.warned = true
                warn(event)
            }
            if clock >= event.next {
                event.warned = false
                event.marker?.removeFromParent(); event.marker = nil
                fire(event)
                event.next += event.interval
            }
            if event.endsAt >= 0 && clock >= event.endsAt {
                event.endsAt = -1
                end(event)
            }
        }
    }
    private func warn(_ event: TimedEvent) {
        switch event.kind {
        case "geyser", "roots", "lightning":
            addStrike(kind: event.kind, x: strikeTarget(event.kind), delay: event.telegraph, fromEvent: true)
        case "wind", "current":
            refreshIndicator(blinking: true)
        case "statueBeam":
            let line = SKSpriteNode(color: SKColor(red: 1, green: 0.3, blue: 0.2, alpha: 0.7), size: CGSize(width: 480, height: 2))
            line.anchorPoint = CGPoint(x: 0, y: 0.5); line.position = CGPoint(x: 0, y: floorY + 11); line.zPosition = 3
            line.run(.repeatForever(.sequence([.fadeAlpha(to: 0.15, duration: 0.12), .fadeAlpha(to: 0.8, duration: 0.12)])))
            addChild(line); event.marker = line
            objects.filter { $0.kind == "statue" }.forEach { $0.node.color = SKColor(red: 1, green: 0.3, blue: 0.2, alpha: 1); $0.node.colorBlendFactor = 0.6 }
        case "souls":
            for tomb in objects where tomb.kind == "tombstone" {
                tomb.node.color = SKColor(rgb: map.accent); tomb.node.colorBlendFactor = 0.6
            }
        case "debris":
            debrisFromLeft = Bool.random()
            let mark = Theme.label("!", size: 14, color: Theme.fire)
            mark.position = CGPoint(x: debrisFromLeft ? 12 : 468, y: 120); mark.zPosition = 3
            addChild(mark); event.marker = mark
        default: break
        }
    }
    private func fire(_ event: TimedEvent) {
        switch event.kind {
        case "wind":
            windDirection = -windDirection
            refreshIndicator(blinking: false)
            callout("GIÓ ĐỔI CHIỀU", at: CGPoint(x: 240, y: 180), color: SKColor(rgb: map.accent))
        case "current":
            currentDirection = Bool.random() ? 1 : -1; event.endsAt = clock + event.duration
            refreshIndicator(blinking: false)
            callout("DÒNG CHẢY", at: CGPoint(x: 240, y: 180), color: SKColor(rgb: map.accent))
        case "sandstorm":
            sandstorm = true; event.endsAt = clock + event.duration
            callout("BÃO CÁT", at: CGPoint(x: 240, y: 180), color: SKColor(rgb: map.accent))
        case "darkness":
            darkness = true; event.endsAt = clock + event.duration
            callout("BÓNG TỐI", at: CGPoint(x: 240, y: 180), color: SKColor(rgb: map.accent))
        case "statueBeam":
            objects.filter { $0.kind == "statue" }.forEach { $0.node.colorBlendFactor = 0 }
            let tablet = objects.first { $0.kind == "tablet" }
            let spared = tablet?.owner
            let beam = SKSpriteNode(color: SKColor(red: 1, green: 0.85, blue: 0.5, alpha: 0.9), size: CGSize(width: 480, height: 12))
            beam.anchorPoint = CGPoint(x: 0, y: 0.5); beam.position = CGPoint(x: 0, y: floorY + 11); beam.zPosition = 3
            addChild(beam); beam.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
            // Jumping or standing on a ledge clears the low beam.
            for fighter in fighters where fighter !== spared && fighter.position.y < floorY + 16 {
                hit(fighter, damage: 12, knockback: 60, color: Theme.gold)
            }
            if let tablet { tablet.owner = nil; tablet.node.colorBlendFactor = 0 }
        case "souls":
            let tombs = objects.filter { $0.kind == "tombstone" }
            tombs.forEach { $0.node.colorBlendFactor = 0 }
            if let tomb = tombs.randomElement() {
                let soul = Mover(kind: "soul", at: CGPoint(x: tomb.home.x, y: floorY + 34), velocity: .zero, size: CGSize(width: 8, height: 10),
                                 color: SKColor(rgb: map.accent), life: 8, hp: 1, damage: 6)
                soul.node.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.3), .fadeAlpha(to: 0.95, duration: 0.3)])))
                soul.node.zPosition = 4; addChild(soul.node); movers.append(soul)
            }
        case "debris":
            let fromLeft = debrisFromLeft
            let y = [CGFloat(66), 100, 130].randomElement() ?? 66
            let rock = Mover(kind: "debris", at: CGPoint(x: fromLeft ? -10 : 490, y: y), velocity: CGVector(dx: fromLeft ? 70 : -70, dy: 0),
                             size: CGSize(width: 18, height: 14), color: SKColor(rgb: map.structure ?? map.accent), life: 9, hp: 2, damage: 8)
            rock.node.run(.repeatForever(.rotate(byAngle: fromLeft ? -.pi : .pi, duration: 1)))
            rock.node.zPosition = 4; addChild(rock.node); movers.append(rock)
        default: break
        }
    }
    private func end(_ event: TimedEvent) {
        switch event.kind {
        case "current": currentDirection = 0; refreshIndicator(blinking: false)
        case "sandstorm": sandstorm = false
        case "darkness": darkness = false
        default: break
        }
    }
    private func refreshIndicator(blinking: Bool) {
        indicator.removeAllActions(); indicator.alpha = 1
        if events.contains(where: { $0.kind == "wind" }) {
            indicator.text = windDirection > 0 ? "GIÓ ▶▶" : "◀◀ GIÓ"
        } else if events.contains(where: { $0.kind == "current" }) {
            indicator.text = currentDirection > 0 ? "DÒNG CHẢY ▶▶" : currentDirection < 0 ? "◀◀ DÒNG CHẢY" : (blinking ? "DÒNG CHẢY..." : "")
        } else { indicator.text = "" }
        if blinking { indicator.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.2), .fadeAlpha(to: 1, duration: 0.2)]))) }
    }
    private func strikeTarget(_ kind: String) -> CGFloat {
        let alive = fighters.filter { $0.hp > 0 }
        if kind == "lightning", Bool.random(), let rune = zones.filter({ $0.kind == "rune" }).randomElement() { return rune.rect.midX }
        if let fighter = alive.randomElement() { return min(440, max(40, fighter.position.x)) }
        return CGFloat.random(in: 60...420)
    }

    // MARK: Strikes

    private func addStrike(kind: String, x: CGFloat, delay: CGFloat, fromEvent: Bool) {
        let color: SKColor = kind == "geyser" ? lavaColor : kind == "roots" ? poisonColor : .white
        let marker: SKSpriteNode
        if kind == "lightning" {
            marker = SKSpriteNode(color: color.withAlphaComponent(0.22), size: CGSize(width: 22, height: 228))
            marker.anchorPoint = CGPoint(x: 0.5, y: 0)
        } else {
            marker = SKSpriteNode(color: color, size: CGSize(width: 28, height: 4))
            marker.anchorPoint = CGPoint(x: 0.5, y: 0)
        }
        marker.position = CGPoint(x: x, y: floorY); marker.zPosition = 3
        marker.run(.repeatForever(.sequence([.fadeAlpha(to: 0.15, duration: 0.12), .fadeAlpha(to: 0.9, duration: 0.12)])))
        addChild(marker)
        strikes.append(Strike(time: delay, x: x, kind: kind, marker: marker, fromEvent: fromEvent))
    }
    private func updateStrikes(_ dt: CGFloat) {
        for index in strikes.indices.reversed() {
            strikes[index].time -= dt
            guard strikes[index].time <= 0 else { continue }
            let strike = strikes.remove(at: index)
            strike.marker.removeFromParent()
            resolve(strike)
        }
    }
    private func resolve(_ strike: Strike) {
        let column: SKSpriteNode
        switch strike.kind {
        case "geyser":
            column = SKSpriteNode(color: lavaColor.withAlphaComponent(0.85), size: CGSize(width: 22, height: 110))
            for fighter in fighters where abs(fighter.position.x - strike.x) < 16 && fighter.position.y < floorY + 110 {
                hit(fighter, damage: 10, launch: 260, color: lavaColor)
            }
        case "roots":
            column = SKSpriteNode(color: poisonColor.withAlphaComponent(0.85), size: CGSize(width: 24, height: 28))
            for fighter in fighters where abs(fighter.position.x - strike.x) < 18 && onGround(fighter) {
                hit(fighter, damage: 4, stun: 0.8, color: poisonColor)
            }
        default:
            column = SKSpriteNode(color: SKColor(white: 1, alpha: 0.95), size: CGSize(width: 6, height: 228))
            for fighter in fighters where abs(fighter.position.x - strike.x) < 20 {
                hit(fighter, damage: 12, color: Theme.ice)
            }
            for zone in zones where zone.kind == "rune" && strike.x > zone.rect.minX - 20 && strike.x < zone.rect.maxX + 20 {
                zone.charged = 8; zone.cover.isHidden = false
                callout("PHÙ VĂN KÍCH HOẠT", at: CGPoint(x: zone.rect.midX, y: floorY + 40), color: Theme.gold)
            }
        }
        column.anchorPoint = CGPoint(x: 0.5, y: 0); column.position = CGPoint(x: strike.x, y: floorY); column.zPosition = 3
        addChild(column); column.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
    }

    // MARK: Souls and debris

    private func updateMovers(_ dt: CGFloat) {
        for mover in movers {
            mover.life -= dt
            if mover.kind == "soul", let target = fighters.filter({ $0.hp > 0 }).min(by: { abs($0.position.x - mover.node.position.x) < abs($1.position.x - mover.node.position.x) }) {
                let dx = target.position.x - mover.node.position.x, dy = target.position.y + 30 - mover.node.position.y
                let length = max(1, sqrt(dx * dx + dy * dy))
                mover.velocity = CGVector(dx: dx / length * 34, dy: dy / length * 34)
            }
            mover.node.position.x += mover.velocity.dx * dt
            mover.node.position.y += mover.velocity.dy * dt
            for fighter in fighters where mover.hp > 0 {
                if let box = meleeBox(fighter), box.intersects(mover.rect), mover.lastSerial[id(fighter)] != fighter.attackSerial {
                    mover.lastSerial[id(fighter)] = fighter.attackSerial
                    damageMover(mover, by: fighter)
                } else if fighter.hp > 0 && fighter.hurtbox.intersects(mover.rect) {
                    hit(fighter, damage: mover.damage, knockback: mover.velocity.dx >= 0 ? 80 : -80, color: mover.node.color)
                    mover.hp = 0
                }
            }
            if mover.life <= 0 || mover.node.position.x < -30 || mover.node.position.x > 510 { mover.hp = 0 }
            if mover.hp <= 0 { mover.node.removeFromParent() }
        }
        movers.removeAll { $0.hp <= 0 }
    }
    private func damageMover(_ mover: Mover, by fighter: Fighter) {
        mover.hp -= 1
        if mover.hp <= 0 { fighter.gainEnergy(4) }
    }

    // MARK: Wind, sandstorm and currents

    private func applyForces(_ dt: CGFloat, projectiles: [Projectile]) {
        var push: CGFloat = 0
        if events.contains(where: { $0.kind == "wind" }) { push += windDirection * 22 }
        if sandstorm { push -= 40 }
        push += currentDirection * 50
        if push != 0 {
            for fighter in fighters where fighter.hp > 0 { fighter.position.x = min(454, max(26, fighter.position.x + push * dt)) }
        }
        let flow = events.contains(where: { $0.kind == "wind" }) ? windDirection : currentDirection
        for projectile in projectiles {
            // A tailwind carries projectiles 30% faster and pushes harder; a headwind slows them.
            var speed: CGFloat = flow == 0 ? 1 : (projectile.direction == flow ? 1.3 : 0.85)
            if sandstorm { speed *= 0.8 }
            projectile.speedScale = speed
            projectile.pushScale = flow != 0 && projectile.direction == flow ? 1.5 : 1
        }
    }

    // MARK: AI hints

    /// Direction away from harmful ground or a telegraphed strike, if the fighter should move.
    func escapeDirection(for fighter: Fighter) -> CGFloat? {
        let x = fighter.position.x
        func away(from center: CGFloat) -> CGFloat {
            if x < 60 { return 1 }
            if x > 420 { return -1 }
            return x < center ? -1 : 1
        }
        if let strike = strikes.first(where: { abs($0.x - x) < 28 }) { return away(from: strike.x) }
        if onGround(fighter), let zone = zones.first(where: { $0.harmful && x >= $0.rect.minX - 4 && x <= $0.rect.maxX + 4 }) {
            return away(from: zone.rect.midX)
        }
        return nil
    }
    /// True just before a low statue beam fires, so the AI can hop over it.
    func shouldJump(_ fighter: Fighter) -> Bool {
        guard onGround(fighter), objects.first(where: { $0.kind == "tablet" })?.owner !== fighter else { return false }
        return events.contains { $0.kind == "statueBeam" && $0.warned && $0.next - clock < 0.3 }
    }
}
