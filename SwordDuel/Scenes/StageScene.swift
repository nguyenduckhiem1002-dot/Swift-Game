import SpriteKit
import UIKit

private final class MonsterShot {
    let node: SKSpriteNode
    var velocity: CGVector
    let damage: CGFloat
    var life: CGFloat = 3
    init(at point: CGPoint, velocity: CGVector, damage: CGFloat, color: SKColor) {
        node = SKSpriteNode(color: color, size: CGSize(width: 10, height: 6)); node.position = point
        self.velocity = velocity; self.damage = damage
    }
    var rect: CGRect { CGRect(x: node.position.x - 5, y: node.position.y - 3, width: 10, height: 6) }
}

/// Boss slam wave running along the floor; jump over it.
private final class Shockwave {
    let node: SKSpriteNode
    let direction: CGFloat
    let damage: CGFloat
    var life: CGFloat = 1.6
    var landed = false
    init(at x: CGFloat, direction: CGFloat, damage: CGFloat, color: SKColor) {
        node = SKSpriteNode(color: color, size: CGSize(width: 18, height: 12))
        node.anchorPoint = CGPoint(x: 0.5, y: 0); node.position = CGPoint(x: x, y: 42)
        self.direction = direction; self.damage = damage
    }
    var rect: CGRect { CGRect(x: node.position.x - 9, y: 42, width: 18, height: 12) }
}

private final class Pickup {
    let kind: String
    let node: SKSpriteNode
    init(kind: String, at point: CGPoint) {
        self.kind = kind
        let color: SKColor = kind == "peach" ? SKColor(red: 1, green: 0.55, blue: 0.6, alpha: 1) : kind == "stone" ? Theme.awaken : Theme.gold
        node = SKSpriteNode(color: color, size: CGSize(width: 10, height: 10))
        node.position = point; node.zRotation = .pi / 4
        node.run(.repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 0.5), .moveBy(x: 0, y: -3, duration: 0.5)])))
    }
    var rect: CGRect { CGRect(x: node.position.x - 7, y: node.position.y - 7, width: 14, height: 14) }
}

/// Stage mode: one player crosses zones left to right. Each zone locks its exit until its waves are cleared;
/// the last zone holds the boss.
final class StageScene: GameScene, KeyboardControllable {
    private let stage: StageData
    private let playerIndex: Int
    private let difficulty: Difficulty
    private let map: MapData
    private let zoneStarts: [CGFloat]
    private let arena: ArenaBackground
    private let terrain: ArenaTerrain
    private let world = SKNode()
    private var player: Fighter!
    private var combat: CombatSystem!
    private let input = PlayerInputRouter()
    private var controls: TouchControls { input.controls }
    private var monsters: [Monster] = []
    private var shots: [MonsterShot] = []
    private var shockwaves: [Shockwave] = []
    private var pickups: [Pickup] = []
    private var monsterHitSerial: [ObjectIdentifier: Int] = [:]
    private var zoneIndex = 0
    private var waveIndex = 0
    private var waveSpawned = false
    private var waveDelay: CGFloat = 0
    private var zoneCleared = false
    private var leftBound: CGFloat = 26
    private var rightBound: CGFloat = 454
    private var elapsed: CGFloat = 0
    private var kills = 0
    /// Once the stage is won or lost, only the hitbox overlay responds to input.
    private var finished = false { didSet { input.actionsLocked = finished } }
    private var victory = false
    private var endDelay: CGFloat = -1
    private var cameraX: CGFloat = 240
    private var shakeTime: CGFloat = 0
    private var shakeOffset = CGPoint.zero
    private var hitStop: CGFloat = 0
    private var accumulator: CGFloat = 0
    private var lastUpdate: TimeInterval = 0
    private let step: CGFloat = 1.0 / 60.0
    private var stagePaused = false
    private var debugEnabled = false
    private let gate = SKSpriteNode()
    private let pausePanel = PausePanel()
    private let announcementPanel = SKSpriteNode()
    private let announcement = Theme.title("", size: 18, color: Theme.gold)
    private let goLabel = Theme.title("ĐI TIẾP ▶", size: 9, color: Theme.gold)
    private var hud: FighterHUD!
    private let zoneLabel = Theme.label("", size: 6, color: .white)
    private let killLabel = Theme.label("", size: 6, color: Theme.ice)
    private let timerLabel = Theme.title("0:00", size: 10, color: Theme.gold)
    private var bossBar: UIResourceBar!
    private let bossName = Theme.label("", size: 7, color: Theme.fire)
    private let minimap = SKNode()
    private let minimapPlayer = SKSpriteNode(color: .white, size: CGSize(width: 3, height: 5))
    private var minimapMonsters: [SKSpriteNode] = []

    init(size: CGSize, stage: StageData, playerIndex: Int, difficulty: Difficulty) {
        self.stage = stage; self.playerIndex = playerIndex; self.difficulty = difficulty
        map = stage.arenaMap
        zoneStarts = stage.zoneStarts
        arena = ArenaBackground(map: map, groundInWorld: true)
        terrain = ArenaTerrain(map: map)
        super.init(size: size)
    }
    required init?(coder: NSCoder) { fatalError() }

    private var difficultyScale: CGFloat { difficulty == .easy ? 0.7 : 1 }
    private func zoneEnd(_ index: Int) -> CGFloat { zoneStarts[index] + stage.zones[index].width }
    private var zone: StageZoneData { stage.zones[zoneIndex] }

    override func didMove(to view: SKView) {
        arena.zPosition = -10; addChild(arena)
        addChild(world)
        if let ground = arena.worldGround { ground.zPosition = -5; world.addChild(ground) }
        terrain.zPosition = 8; terrain.delegate = self; world.addChild(terrain)
        terrain.screenOverlay.zPosition = 30; addChild(terrain.screenOverlay)
        let data = CharacterLibrary.all[min(playerIndex, CharacterLibrary.all.count - 1)]
        player = Fighter(data: data, isPlayer: true)
        player.zPosition = 15; world.addChild(player)
        player.gravityScale = map.gravityScale; player.moveScale = map.movementScale
        player.animationScale = map.animSpeed ?? 1; player.terrain = terrain
        player.reset(at: 90, facing: 1)
        gate.color = SKColor(rgb: map.accent); gate.size = CGSize(width: 6, height: 228); gate.anchorPoint = CGPoint(x: 0.5, y: 0)
        gate.zPosition = 9; gate.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.4), .fadeAlpha(to: 0.75, duration: 0.4)])))
        world.addChild(gate)
        combat = CombatSystem(world: world, screen: self, arenaWidth: stage.width)
        combat.host = self; combat.comboFighter = player
        combat.teleportRange = 220; combat.screenCalloutY = 196
        input.fighter = player
        input.onTogglePause = { [weak self] in
            guard let self else { return }
            self.setPaused(!self.stagePaused)
        }
        input.onToggleDebug = { [weak self] in self?.toggleDebug() }
        controls.configure(character: data); addChild(controls)
        setupHUD(); setupMinimap()
        addChild(pausePanel)
        announcementPanel.position = CGPoint(x: 240, y: 166); announcementPanel.size = CGSize(width: 200, height: 40)
        announcementPanel.texture = UIAssets.shared.texture("banner_fight", size: CGSize(width: 160, height: 40))
        announcementPanel.zPosition = 59; announcementPanel.alpha = 0; addChild(announcementPanel)
        announcement.position = CGPoint(x: 240, y: 166); announcement.zPosition = 60; addChild(announcement)
        goLabel.position = CGPoint(x: 424, y: 140); goLabel.zPosition = 60; goLabel.isHidden = true
        goLabel.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.3), .fadeAlpha(to: 1, duration: 0.3)])))
        addChild(goLabel)
        enterZone(0)
        announce(stage.name.uppercased())
        updateCamera(0, snap: true)
        updateHUD()
    }

    // MARK: HUD

    private func setupHUD() {
        let backing = SKSpriteNode(color: Theme.navy.withAlphaComponent(0.58), size: CGSize(width: 480, height: 57))
        backing.position = CGPoint(x: 240, y: 241.5); backing.zPosition = 48; addChild(backing)
        hud = FighterHUD(fighter: player, left: true); hud.zPosition = 50; addChild(hud)
        let stageName = Theme.label(stage.name, size: 7, color: Theme.gold)
        for (label, y) in [(stageName, CGFloat(262)), (zoneLabel, 247), (killLabel, 233)] {
            label.horizontalAlignmentMode = .right; label.position = CGPoint(x: 431, y: y); label.zPosition = 50; addChild(label)
        }
        let timerFrame = UIAssets.shared.sprite("timer_frame", size: CGSize(width: 48, height: 24))
        timerFrame.position = CGPoint(x: 240, y: 244); timerFrame.zPosition = 49; addChild(timerFrame)
        timerLabel.position = CGPoint(x: 240, y: 244); timerLabel.zPosition = 50; addChild(timerLabel)
        bossBar = UIResourceBar(frame: "hp_frame", fill: "hp_flame_fill", nativeFrame: CGSize(width: 128, height: 14), nativeFill: CGSize(width: 124, height: 10), displayWidth: 200, outsideIsLeft: false)
        bossBar.position = CGPoint(x: 240, y: 186); bossBar.zPosition = 50; bossBar.isHidden = true; addChild(bossBar)
        bossName.position = CGPoint(x: 240, y: 175); bossName.zPosition = 50; bossName.isHidden = true; addChild(bossName)
    }
    private func updateHUD() {
        controls.revealFighters([player])
        hud.update(player)
        let waves = zone.waves?.count ?? 0
        zoneLabel.text = "KHU \(zoneIndex + 1)/\(stage.zones.count)" + (waves > 0 && !zoneCleared ? " · ĐỢT \(min(waveIndex + 1, waves))/\(waves)" : "")
        killLabel.text = "DIỆT \(kills)"
        timerLabel.text = clockText(elapsed)
        if let boss = monsters.first(where: { $0.isBoss && !$0.isDead }) {
            bossBar.isHidden = false; bossName.isHidden = false
            bossBar.setFraction(boss.hpFraction); bossName.text = boss.data.name
        } else { bossBar.isHidden = true; bossName.isHidden = true }
        updateMinimap()
    }
    private func clockText(_ seconds: CGFloat) -> String {
        let total = Int(seconds)
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
    private func setupMinimap() {
        minimap.position = CGPoint(x: 240, y: 9); minimap.zPosition = 50; addChild(minimap)
        minimap.addChild(SKSpriteNode(color: Theme.navy.withAlphaComponent(0.7), size: CGSize(width: 164, height: 7)))
        for start in zoneStarts.dropFirst() {
            let tick = SKSpriteNode(color: Theme.gold.withAlphaComponent(0.6), size: CGSize(width: 1, height: 7))
            tick.position.x = (start - stage.width / 2) * 160 / stage.width; tick.zPosition = 1; minimap.addChild(tick)
        }
        for _ in 0..<16 {
            let dot = SKSpriteNode(color: Theme.fire, size: CGSize(width: 2, height: 4)); dot.zPosition = 2; dot.isHidden = true
            minimap.addChild(dot); minimapMonsters.append(dot)
        }
        minimapPlayer.color = player.data.accentColor; minimapPlayer.zPosition = 3; minimap.addChild(minimapPlayer)
    }
    private func updateMinimap() {
        let scale = 160 / stage.width
        minimapPlayer.position.x = (player.position.x - stage.width / 2) * scale
        for (index, dot) in minimapMonsters.enumerated() {
            if index < monsters.count {
                dot.isHidden = false; dot.position.x = (monsters[index].position.x - stage.width / 2) * scale
                dot.size = monsters[index].isBoss ? CGSize(width: 4, height: 6) : CGSize(width: 2, height: 4)
            } else { dot.isHidden = true }
        }
    }
    private func announce(_ text: String, color: SKColor = Theme.gold) {
        announcement.text = text; announcement.fontColor = color
        for node in [announcementPanel as SKNode, announcement] {
            node.removeAllActions(); node.alpha = 1
            node.run(.sequence([.wait(forDuration: 1.2), .fadeOut(withDuration: 0.4)]))
        }
    }

    // MARK: Zones and waves

    private func enterZone(_ index: Int) {
        zoneIndex = index; waveIndex = 0; waveSpawned = false; zoneCleared = false
        leftBound = zoneStarts[index] + 26; rightBound = zoneEnd(index) - 26
        player.arenaMinX = leftBound; player.arenaMaxX = rightBound
        player.allowNewAwakening()
        gate.position = CGPoint(x: zoneEnd(index), y: 42); gate.isHidden = false
        goLabel.isHidden = true
        for pickup in zone.pickups ?? [] {
            spawnPickup(pickup.kind, at: CGPoint(x: zoneStarts[index] + pickup.x, y: 42 + (pickup.y ?? 10)))
        }
        if index > 0 { callout("KHU \(index + 1): \((zone.title ?? "").uppercased())", at: nil, color: Theme.gold) }
        if (zone.waves ?? []).isEmpty { clearZone() } else { waveDelay = index == 0 ? 1.5 : 0.8 }
    }
    private func updateWaves(_ dt: CGFloat) {
        guard !zoneCleared, !finished else { return }
        if waveDelay > 0 {
            waveDelay -= dt
            if waveDelay <= 0 { spawnWave() }
            return
        }
        guard waveSpawned, monsters.isEmpty else { return }
        waveSpawned = false
        waveIndex += 1
        if waveIndex < (zone.waves?.count ?? 0) {
            waveDelay = 1
            callout("ĐỢT \(waveIndex + 1)", at: nil, color: Theme.fire)
        } else { clearZone() }
    }
    private func spawnWave() {
        guard let wave = zone.waves, waveIndex < wave.count else { return }
        waveSpawned = true
        var slot = 0
        for spawn in wave[waveIndex] {
            guard let data = MonsterLibrary.monster(spawn.type) else { continue }
            for _ in 0..<max(1, spawn.count ?? 1) {
                // Monsters enter from the side away from the player, alternating when the player is central.
                let center = (leftBound + rightBound) / 2
                var fromRight = player.position.x < center ? slot % 3 != 2 : slot % 3 == 2
                var x = fromRight ? rightBound - 14 - CGFloat(slot / 2) * 26 : leftBound + 14 + CGFloat(slot / 2) * 26
                if abs(x - player.position.x) < 80 {
                    fromRight.toggle()
                    x = fromRight ? rightBound - 14 : leftBound + 14
                }
                spawnMonster(data, elite: spawn.elite ?? false, x: data.behavior == "boss" ? rightBound - 50 : x)
                slot += 1
            }
            if data.behavior == "boss" { announce(data.name.uppercased(), color: Theme.fire) }
        }
    }
    private func spawnMonster(_ data: MonsterData, elite: Bool, x: CGFloat) {
        let y: CGFloat = data.behavior == "flyer" ? 120 : 42
        let monster = Monster(data: data, elite: elite, at: CGPoint(x: x, y: y))
        monster.host = self
        monster.movementXRange = (zoneStarts[zoneIndex] + 12)...(zoneEnd(zoneIndex) - 12)
        monster.zPosition = 14; world.addChild(monster); monsters.append(monster)
    }
    private func clearZone() {
        zoneCleared = true
        if zoneIndex == stage.zones.count - 1 {
            finished = true; victory = true; endDelay = 2.2
            player.victoryPose()
            announce("ẢI HOÀN THÀNH")
            return
        }
        if !(zone.waves ?? []).isEmpty {
            player.heal(15)
            callout("KHU ĐÃ SẠCH · +15 HP", at: nil, color: Theme.gold)
        }
        gate.isHidden = true; goLabel.isHidden = false
        rightBound = zoneEnd(zoneIndex + 1) - 26; player.arenaMaxX = rightBound
    }
    private func checkZoneAdvance() {
        guard zoneCleared, !finished, zoneIndex + 1 < stage.zones.count, player.position.x > zoneStarts[zoneIndex + 1] + 60 else { return }
        enterZone(zoneIndex + 1)
    }
    private func spawnPickup(_ kind: String, at point: CGPoint) {
        let pickup = Pickup(kind: kind, at: point)
        pickup.node.zPosition = 12; world.addChild(pickup.node); pickups.append(pickup)
    }
    private func updatePickups() {
        for pickup in pickups where pickup.rect.intersects(player.hurtbox) {
            switch pickup.kind {
            case "peach": player.heal(25); callout("+25 HP", at: pickup.node.position, color: Theme.gold)
            case "stone": gainAwakening(10); callout("LINH VĂN THẠCH", at: pickup.node.position, color: Theme.awaken)
            default: player.gainEnergy(40); callout("+40 NĂNG LƯỢNG", at: pickup.node.position, color: Theme.gold)
            }
            pickup.node.removeFromParent()
        }
        pickups.removeAll { $0.node.parent == nil }
    }

    // MARK: Simulation

    override func update(_ currentTime: TimeInterval) {
        if lastUpdate == 0 { lastUpdate = currentTime; return }
        let realDelta = min(0.1, max(0, currentTime - lastUpdate)); lastUpdate = currentTime
        if stagePaused { return }
        if hitStop > 0 { hitStop = max(0, hitStop - CGFloat(realDelta)); return }
        accumulator += CGFloat(realDelta)
        var iterations = 0
        while accumulator >= step && iterations < 6 { fixedUpdate(step); accumulator -= step; iterations += 1 }
        if iterations == 6 { accumulator = 0 }
    }
    private func fixedUpdate(_ dt: CGFloat) {
        arena.updateFixed(dt)
        if shakeTime > 0 {
            shakeTime -= dt
            shakeOffset = CGPoint(x: CGFloat.random(in: -2...2), y: CGFloat.random(in: -1...1))
        } else { shakeOffset = .zero }
        arena.position = shakeOffset
        combat.updateTimers(dt)
        if endDelay >= 0 {
            player.updateFixed(dt)
            endDelay -= dt
            if endDelay < 0 { showResult() }
            updateCamera(dt)
            return
        }
        elapsed += dt
        input.applyHeld()
        if !player.state.locksMovement {
            if player.leftHeld && !player.rightHeld { player.facing = -1 } else if player.rightHeld && !player.leftHeld { player.facing = 1 }
        }
        player.updateFixed(dt)
        terrain.updateFixed(dt, fighters: [player!], projectiles: combat.projectiles)
        player.position.x = min(rightBound, max(leftBound, player.position.x))
        combat.update(dt, attackers: [player!])
        for monster in monsters {
            monster.update(dt, target: player)
            let key = ObjectIdentifier(monster)
            if let box = monster.attackBox, box.intersects(player.hurtbox), monsterHitSerial[key] != monster.attackSerial {
                monsterHitSerial[key] = monster.attackSerial
                hurtPlayer(monster.attackDamage, from: monster.position.x, color: SKColor(rgb: monster.data.color))
            }
        }
        updateShots(dt)
        updateShockwaves(dt)
        updatePickups()
        processKills()
        updateWaves(dt)
        checkZoneAdvance()
        controls.update(energy: player.energy, cooldowns: player.cooldowns, awakeningTier: player.awakeningTier, dt: dt)
        updateHUD()
        updateCamera(dt)
        if player.hp == 0 && !finished {
            finished = true; victory = false; endDelay = 1.8
            announce("THẤT BẠI", color: Theme.fire)
        }
        if debugEnabled {
            var boxes: [(CGRect, SKColor)] = []
            for monster in monsters {
                boxes.append((monster.hurtbox, .green))
                if let box = monster.attackBox { boxes.append((box, .red)) }
            }
            combat.drawDebug(fighters: [player!], extra: boxes)
        }
    }
    /// Follows the player inside the current zone, or the current and next zone once the exit opens.
    private func updateCamera(_ dt: CGFloat, snap: Bool = false) {
        let low = zoneStarts[zoneIndex]
        let high = zoneCleared && zoneIndex + 1 < stage.zones.count ? zoneEnd(zoneIndex + 1) : zoneEnd(zoneIndex)
        var target = high - low <= 480 ? (low + high) / 2 : min(high - 240, max(low + 240, player.position.x))
        target = min(stage.width - 240, max(240, target))
        cameraX = snap ? target : cameraX + (target - cameraX) * min(1, dt * 6)
        world.position = CGPoint(x: 240 - cameraX + shakeOffset.x, y: shakeOffset.y)
        arena.setCamera(x: cameraX)
    }
    private func showResult() {
        let detail = victory ? "\(clockText(elapsed)) · DIỆT \(kills) QUÁI" : "KHU \(zoneIndex + 1)/\(stage.zones.count) · DIỆT \(kills) QUÁI"
        let stage = self.stage, playerIndex = self.playerIndex, difficulty = self.difficulty
        transition(to: ResultScene(size: size, victory: victory, detail: detail, retryTitle: "RETRY") {
            StageScene(size: CGSize(width: 480, height: 270), stage: stage, playerIndex: playerIndex, difficulty: difficulty)
        })
    }

    // MARK: Kills

    private func processKills() {
        for monster in monsters where monster.isDead && !monster.rewarded {
            monster.rewarded = true; kills += 1
            gainAwakening(monster.isBoss ? 50 : monster.elite ? 20 : (monster.data.reward ?? 5))
            if monster.elite { spawnPickup("stone", at: CGPoint(x: monster.position.x, y: 52)) }
            else if !monster.isBoss && CGFloat.random(in: 0...1) < 0.12 { spawnPickup("peach", at: CGPoint(x: monster.position.x, y: 52)) }
        }
        monsters.removeAll { $0.isDead }
    }

    // MARK: Monster attacks

    private func hurtPlayer(_ damage: CGFloat, from x: CGFloat, color: SKColor) {
        guard !finished else { return }
        let away: CGFloat = player.position.x >= x ? 1 : -1
        let dealt = player.takeHit(damage: max(1, Int((damage * difficultyScale).rounded())), knockback: away * 70, unblockable: false)
        guard dealt > 0 else { return }
        gainAwakening(player.lastHitGuarded ? 4 : 3)
        shakeTime = max(shakeTime, 0.15)
        showEffect("hit_spark", at: CGPoint(x: player.position.x, y: player.position.y + 30), color: color)
    }
    private func updateShots(_ dt: CGFloat) {
        for shot in shots {
            shot.node.position.x += shot.velocity.dx * dt
            shot.node.position.y += shot.velocity.dy * dt
            shot.life -= dt
            if shot.rect.intersects(player.hurtbox) && !player.has(.vanish) {
                if player.isReflecting {
                    // Reflected shots become the player's projectiles.
                    let projectile = Projectile(owner: player, damage: max(1, Int(shot.damage)), direction: shot.velocity.dx > 0 ? -1 : 1)
                    projectile.position = shot.node.position
                    combat.addProjectile(projectile)
                } else {
                    hurtPlayer(shot.damage, from: shot.node.position.x - shot.velocity.dx, color: shot.node.color)
                }
                shot.life = 0
            }
            if shot.life <= 0 || shot.node.position.y < 40 || shot.node.position.y > 280 { shot.node.removeFromParent() }
        }
        shots.removeAll { $0.node.parent == nil }
    }
    private func updateShockwaves(_ dt: CGFloat) {
        for wave in shockwaves {
            wave.node.position.x += wave.direction * 190 * dt
            wave.life -= dt
            // Jumping clears the wave.
            if !wave.landed && player.position.y < 50 && wave.rect.intersects(player.hurtbox) {
                wave.landed = true
                hurtPlayer(wave.damage, from: wave.node.position.x - wave.direction * 20, color: wave.node.color)
            }
            if wave.life <= 0 || wave.node.position.x < leftBound - 30 || wave.node.position.x > rightBound + 30 { wave.node.removeFromParent() }
        }
        shockwaves.removeAll { $0.node.parent == nil }
    }

    // MARK: Shared effects

    private func gainAwakening(_ amount: CGFloat) { combat.gainAwakening(player, amount, versus: nil) }
    private func showEffect(_ name: String, at point: CGPoint, color: SKColor) { combat.showEffect(name, at: point, color: color) }
    private func callout(_ text: String?, at point: CGPoint?, color: SKColor) { combat.callout(text, at: point, color: color) }

    // MARK: Input

    private func setPaused(_ value: Bool) {
        stagePaused = value; pausePanel.isHidden = !value
        speed = value ? 0 : 1
        accumulator = 0
        input.isPaused = value
        input.suspend()
    }
    func pauseForInterruption() {
        if player != nil { setPaused(true); input.reset() }
    }
    private func toggleDebug() {
        debugEnabled.toggle(); controls.setDebug(debugEnabled)
        if !debugEnabled { combat.clearDebug() }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { input.touchesBegan(touches, in: self) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { input.touchesMoved(touches, in: self) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { input.touchesEnded(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { input.touchesEnded(touches) }
    func keyChanged(_ key: String, down: Bool) { input.keyChanged(key, down: down) }
}

extension StageScene: MonsterHost {
    func monsterShoot(_ monster: Monster, from point: CGPoint, velocity: CGVector) {
        let shot = MonsterShot(at: point, velocity: velocity, damage: monster.attackDamage, color: SKColor(rgb: monster.data.color))
        shot.node.zPosition = 20; world.addChild(shot.node); shots.append(shot)
    }
    func monsterShockwave(_ monster: Monster, direction: CGFloat) {
        let wave = Shockwave(at: monster.position.x + direction * 30, direction: direction, damage: monster.attackDamage * 0.8, color: SKColor(rgb: monster.data.color))
        wave.node.zPosition = 13; world.addChild(wave.node); shockwaves.append(wave)
    }
    func monsterSummon(_ monster: Monster, type: String, count: Int) {
        guard let data = MonsterLibrary.monster(type) else { return }
        for index in 0..<count {
            let offset: CGFloat = index % 2 == 0 ? -60 : 60
            spawnMonster(data, elite: false, x: min(rightBound - 14, max(leftBound + 14, monster.position.x + offset)))
        }
        callout("TRIỆU HỒI!", at: CGPoint(x: monster.position.x, y: 140), color: Theme.fire)
    }
    func monsterTelegraph(_ monster: Monster, rect: CGRect, duration: CGFloat) {
        let marker = SKSpriteNode(color: Theme.fire.withAlphaComponent(0.8), size: rect.size)
        marker.anchorPoint = .zero; marker.position = rect.origin; marker.zPosition = 12
        marker.run(.sequence([.repeat(.sequence([.fadeAlpha(to: 0.15, duration: 0.1), .fadeAlpha(to: 0.85, duration: 0.1)]), count: max(1, Int(duration / 0.2))), .removeFromParent()]))
        world.addChild(marker)
    }
}

extension StageScene: TerrainDelegate {
    func terrainHit(_ fighter: Fighter, damage: Int, knockback: CGFloat, launch: CGFloat, stun: CGFloat, color: SKColor) -> Bool {
        guard !finished, combat.applyArenaHit(fighter, damage: damage, knockback: knockback, launch: launch, stun: stun, color: color) else { return false }
        shakeTime = max(shakeTime, 0.12)
        return true
    }
    func terrainAwakening(_ fighter: Fighter, amount: CGFloat) { gainAwakening(amount) }
    func terrainCallout(_ text: String, at point: CGPoint?, color: SKColor) { callout(text, at: point, color: color) }
}

extension StageScene: CombatHost {
    func combatTargets(for attacker: Fighter) -> [CombatTarget] { monsters.map { $0 as CombatTarget } }
    /// The ULT strikes every monster on screen.
    func combatUltTargets(for attacker: Fighter) -> [CombatTarget] {
        monsters.filter { $0.canBeHit && abs($0.position.x - cameraX) < 260 }.map { $0 as CombatTarget }
    }
    var combatCameraX: CGFloat { cameraX }
    func combatDidLandHit(attacker: Fighter, target: CombatTarget) { hitStop = 0.04; shakeTime = max(shakeTime, 0.1) }
    func combatDidAwaken(_ fighter: Fighter) {}
}
