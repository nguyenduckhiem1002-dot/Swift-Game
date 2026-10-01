import SpriteKit
import UIKit

/// A delayed hit: ULT volleys, clone echoes and phantom strikes.
private struct PendingHit {
    enum Kind { case ult, echo, summon }
    var time: CGFloat
    let attacker: Fighter
    let defender: Fighter
    let damage: Int
    let unblockable: Bool
    let kind: Kind
    var effect: HitEffect? = nil
    var knockback: CGFloat = 0
}

final class FightScene: GameScene {
    private let config: MatchConfig
    private var player: Fighter!
    private var opponent: Fighter!
    private var ai: AIController!
    private let map: MapData
    private let arena: ArenaBackground
    private let terrain: ArenaTerrain
    /// Everything that lives in arena coordinates; the camera scrolls and zooms this node.
    private let world = SKNode()
    private var cameraX: CGFloat = 240
    private var zoom: CGFloat = 1
    private var shakeOffset = CGPoint.zero
    private let minimap = SKNode()
    private var minimapDots: [SKSpriteNode] = []
    private let minimapView = SKSpriteNode(color: SKColor.white.withAlphaComponent(0.25), size: CGSize(width: 10, height: 7))
    private var controls = TouchControls()
    private var projectiles: [Projectile] = []
    private var touchMap: [ObjectIdentifier: Control] = [:]
    private var keyMap: Set<Control> = []
    private var debugEnabled = false
    private var debugNodes: [SKNode] = []
    private var accumulator: CGFloat = 0
    private var lastUpdate: TimeInterval = 0
    private let step: CGFloat = 1.0 / 60.0
    private var hitStop: CGFloat = 0
    private var slowMotion: CGFloat = 0
    private var roundSeconds: CGFloat = 60
    private var round = 1
    private var roundEndDelay: CGFloat = -1
    private var roundResolved = false
    private var roundDraw = false
    private var pendingHits: [PendingHit] = []
    private var landedSerial: [ObjectIdentifier: Int] = [:]
    private var comboHits = 0
    private var comboTimer: CGFloat = 0
    private var hpFill: [UIResourceBar] = []
    private var energyFill: [UIResourceBar] = []
    private var awakeningFill: [UIResourceBar] = []
    private var tierLabels: [SKLabelNode] = []
    private var scoreDots: [[SKSpriteNode]] = [[], []]
    private var timerLabel = Theme.label("60", size: 18, color: Theme.gold)
    private var comboLabel = Theme.label("", size: 10, color: Theme.gold)
    private var announcement = Theme.label("", size: 25, color: Theme.gold)
    private var darkOverlay = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 480, height: 270))
    private var shakeTime: CGFloat = 0
    private var fightPaused = false
    private var uiStatePreview = false
    private let pausePanel = SKNode()
    private let announcementPanel = SKSpriteNode()
    private let roundLabel = Theme.label("", size: 8, color: Theme.gold)

    init(size: CGSize, config: MatchConfig) {
        self.config = config
        map = MapLibrary.map(id: config.mapID)
        arena = ArenaBackground(map: map, groundInWorld: true)
        terrain = ArenaTerrain(map: map)
        super.init(size: size)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func didMove(to view: SKView) {
        arena.zPosition = -10; addChild(arena)
        addChild(world)
        if let ground = arena.worldGround { ground.zPosition = -5; world.addChild(ground) }
        terrain.zPosition = 8; terrain.delegate = self; world.addChild(terrain)
        terrain.screenOverlay.zPosition = 30; addChild(terrain.screenOverlay)
        let playerData = CharacterLibrary.all[config.playerIndex]
        let opponentData = CharacterLibrary.all[config.opponentIndex]
        player = Fighter(data: playerData, isPlayer: true)
        opponent = Fighter(data: opponentData, isPlayer: false)
        for fighter in [player!, opponent!] {
            fighter.gravityScale = map.gravityScale; fighter.moveScale = map.movementScale
            fighter.animationScale = map.animSpeed ?? 1; fighter.terrain = terrain
            fighter.arenaMaxX = map.arenaWidth - 26
        }
        player.zPosition = 15; opponent.zPosition = 15
        world.addChild(player); world.addChild(opponent)
        ai = AIController(fighter: opponent, target: player, difficulty: config.difficulty)
        ai.terrain = terrain
        controls.configure(character: playerData)
        addChild(controls)
        setupHUD()
        setupMinimap()
        setupPausePanel()
        darkOverlay.fillColor = .black; darkOverlay.strokeColor = .clear; darkOverlay.alpha = 0
        darkOverlay.zPosition = 40; addChild(darkOverlay)
        announcementPanel.position = CGPoint(x: 240, y: 166); announcementPanel.size = CGSize(width: 160, height: 40)
        announcementPanel.zPosition = 59; addChild(announcementPanel)
        announcement.position = CGPoint(x: 240, y: 166); announcement.zPosition = 60; addChild(announcement)
        roundLabel.position = CGPoint(x: 240, y: 194); roundLabel.zPosition = 60; addChild(roundLabel)
        comboLabel.position = CGPoint(x: 138, y: 117); comboLabel.zPosition = 60; addChild(comboLabel)
        startRound()
        if ProcessInfo.processInfo.arguments.contains("--test-ui") { runUIInputChecks(); exit(0) }
        if ProcessInfo.processInfo.arguments.contains("--preview-paused") { setFightPaused(true) }
        if ProcessInfo.processInfo.arguments.contains("--preview-ui-states") {
            // Reproducible art-review state; normal play never enters this branch.
            uiStatePreview = true
            player.hp = 60; opponent.hp = 35; player.energy = 100; opponent.energy = 48
            player.wins = 1; opponent.wins = 1
            player.cooldowns = ["skill1": 1.5, "skill2": 3.75, "skill3": 4]
            player.gainAwakening(65); opponent.gainAwakening(35)
            for node in [announcementPanel as SKNode, announcement, roundLabel] { node.removeAllActions(); node.alpha = 0 }
            controls.setPressed(.attack, true)
            controls.update(energy: player.energy, cooldowns: player.cooldowns, awakeningTier: player.awakeningTier, dt: 0)
            updateHUD()
        }
    }
    private func runUIInputChecks() {
        // Exercise the same identity-based ownership path as two simultaneous UITouches.
        let first = NSObject(), second = NSObject()
        touchMap[ObjectIdentifier(first)] = .left; controlDown(.left)
        touchMap[ObjectIdentifier(second)] = .left; controlDown(.left)
        touchMap.removeValue(forKey: ObjectIdentifier(first)); controlUp(.left)
        precondition(player.leftHeld && controls.isPressed(.left), "One released finger must not release another finger's button")
        touchMap.removeValue(forKey: ObjectIdentifier(second)); controlUp(.left)
        precondition(!player.leftHeld && !controls.isPressed(.left))
        keyChanged("a", down: true); keyChanged("s", down: true); keyChanged("s", down: false)
        precondition(player.leftHeld && !player.blockHeld, "Independent keyboard holds")
        let seconds = roundSeconds
        keyChanged("p", down: true); keyChanged("p", down: true)
        precondition(fightPaused && !player.leftHeld, "Pause clears gameplay input and ignores key repeat")
        update(1); update(2)
        precondition(roundSeconds == seconds, "Paused timer must stay frozen")
        keyChanged("p", down: false); keyChanged("p", down: true); keyChanged("p", down: false)
        precondition(!fightPaused && !controls.isPressed(.pause), "Pause can resume and release its visual state")
        let button = MenuButton(text: "TEST", size: CGSize(width: 110, height: 28), action: {})
        button.setPressed(true); precondition(abs(button.xScale-0.92) < 0.001)
        button.isEnabled = false; precondition(button.xScale == 1)
        button.setPressed(true); precondition(button.xScale == 1, "Disabled button must not press")
        let fallback = UIAssets.shared.texture("deliberately_missing_ui_asset", size: CGSize(width: 24, height: 24))
        precondition(fallback.size() == CGSize(width: 24, height: 24) && fallback.filteringMode == .nearest)
        for character in CharacterLibrary.all {
            let frames = UIAssets.shared.frames("btn_\(character.id)_ult_ready", frameSize: CGSize(width: 44, height: 44), count: 4)
            precondition(frames.count == 4 && frames.allSatisfy { $0.filteringMode == .nearest })
            for (name, spec) in character.animations {
                precondition(SpriteSheet.shared.frames(character: character, animation: name).count == spec.frames, "\(character.id) \(name) frame count")
            }
            for move in ["attack1", "attack2", "attack3", "skill1", "skill2", "ult"] { precondition(character.moves[move] != nil, "\(character.id) is missing \(move)") }
        }
        precondition(Set(CharacterLibrary.all.map(\.id)).count == CharacterLibrary.all.count, "Character ids must be unique")
        for character in CharacterLibrary.all {
            for move in ["skill3", "ultAwakened"] { precondition(character.moves[move] != nil, "\(character.id) is missing \(move)") }
            if let buff = character.moves["skill3"]?.buff { precondition(Buff(rawValue: buff) != nil, "\(character.id) has unknown SK3 buff \(buff)") }
            if let buff = character.moves["ultAwakened"]?.buff { precondition(Buff(rawValue: buff) != nil, "\(character.id) has unknown ULT buff \(buff)") }
        }
        runAwakeningChecks()
        for map in MapLibrary.all { precondition(!ArenaBackground(map: map).children.isEmpty, "\(map.id) arena is empty") }
        runTerrainChecks()
        runStageChecks()
        print("PASS UI: shared touch ownership, independent inputs, pause/resume, frozen timer, disabled/pressed menu states, missing-file fallback, \(CharacterLibrary.all.count) character rosters and ULT strips, \(MapLibrary.all.count) arenas.")
    }
    /// Layout sanity plus a 40-second headless run of every map's events with two idle fighters.
    private func runTerrainChecks() {
        for map in MapLibrary.all {
            let spawns = map.spawnPoints
            for zone in map.terrain?.zones ?? [] where ["lava", "poison", "void"].contains(zone.kind) {
                precondition(!(zone.x...(zone.x + zone.w)).contains(spawns.left) && !(zone.x...(zone.x + zone.w)).contains(spawns.right), "\(map.id) hazard covers a spawn point")
            }
            if map.isWide {
                // Both fighters stay on screen at the widest allowed gap, at either wall and at spawn.
                let width = map.arenaWidth
                for (left, right) in [(CGFloat(26), 26 + CameraFraming.maxGap), (width - 26 - CameraFraming.maxGap, width - 26), (spawns.left, spawns.right)] {
                    let frame = CameraFraming.target(width: width, leftX: left, rightX: right)
                    let half = 240 / frame.zoom
                    precondition(frame.zoom >= CameraFraming.minZoom && frame.zoom <= 1, "\(map.id) zoom out of range")
                    precondition(frame.x - half >= -0.5 && frame.x + half <= width + 0.5, "\(map.id) camera shows outside the arena")
                    precondition(left >= frame.x - half && right <= frame.x + half, "\(map.id) camera loses a fighter")
                }
            }
            for platform in map.terrain?.platforms ?? [] {
                // A standard jump rises about 39 points; low-gravity maps reach higher.
                precondition(platform.y - 42 <= 39 / map.gravityScale, "\(map.id) platform at y \(platform.y) is out of jump reach")
            }
            let field = ArenaTerrain(map: map)
            let a = Fighter(data: CharacterLibrary.all[0], isPlayer: true), b = Fighter(data: CharacterLibrary.all[1], isPlayer: false)
            a.reset(at: spawns.left, facing: 1); b.reset(at: spawns.right, facing: -1)
            for fighter in [a, b] { fighter.terrain = field; fighter.gravityScale = map.gravityScale; fighter.arenaMaxX = map.arenaWidth - 26 }
            for _ in 0..<2400 {
                a.updateFixed(1.0 / 60.0); b.updateFixed(1.0 / 60.0)
                field.updateFixed(1.0 / 60.0, fighters: [a, b], projectiles: [])
            }
            field.reset()
            precondition(a.position.x >= 26 && a.position.x <= map.arenaWidth - 26 && b.position.y >= 42, "\(map.id) terrain moved a fighter out of bounds")
        }
    }
    /// Stage data rules from the spec, then every monster type fights an idle fighter for 12 seconds and is killed.
    private func runStageChecks() {
        for stage in StageLibrary.all {
            precondition((4...6).contains(stage.zones.count), "\(stage.id) needs 4-6 zones")
            precondition(stage.width >= 4 * 480 - 0.5 && stage.width <= 6 * 480 + 0.5, "\(stage.id) should be 4-6 screens wide")
            precondition(stage.zones.last?.kind == "boss", "\(stage.id) must end in a boss zone")
            precondition(MapLibrary.all.contains { $0.id == stage.map }, "\(stage.id) uses an unknown map")
            for zone in stage.zones {
                for spawn in (zone.waves ?? []).flatMap({ $0 }) { precondition(MonsterLibrary.monster(spawn.type) != nil, "\(stage.id) spawns unknown \(spawn.type)") }
                precondition((zone.pickups ?? []).allSatisfy { $0.x >= 0 && $0.x <= zone.width }, "\(stage.id) pickup outside its zone")
            }
            precondition(stage.arenaMap.arenaWidth == stage.width, "\(stage.id) arena width mismatch")
        }
        for data in MonsterLibrary.all {
            if let summon = data.summon { precondition(MonsterLibrary.monster(summon) != nil, "\(data.id) summons unknown \(summon)") }
            let target = Fighter(data: CharacterLibrary.all[0], isPlayer: true)
            target.reset(at: 200, facing: 1)
            let monster = Monster(data: data, elite: false, at: CGPoint(x: 320, y: data.behavior == "flyer" ? 120 : 42))
            monster.bounds = 26...454
            for _ in 0..<720 { monster.update(1.0 / 60.0, target: target) }
            precondition(!monster.isDead && monster.position.x >= 26 && monster.position.x <= 454, "\(data.id) left its bounds")
            var guardHits = 0
            while !monster.isDead && guardHits < 500 { _ = monster.takeHit(damage: 10, knockback: 0); monster.update(1.0 / 60.0, target: target); guardHits += 1 }
            precondition(monster.isDead && monster.hp == 0, "\(data.id) cannot be killed")
        }
    }
    private func runAwakeningChecks() {
        let probe = Fighter(data: CharacterLibrary.all[0], isPlayer: false)
        probe.reset(at: 100, facing: 1); probe.energy = 100
        precondition(!probe.use("skill3"), "SK3 stays locked below tier I")
        probe.gainAwakening(30)
        precondition(probe.awakeningTier == 1 && probe.use("skill3"), "Tier I unlocks SK3")
        probe.reset(at: 100, facing: 1)
        precondition(probe.gainAwakening(100) && probe.isAwakened && probe.awakeningTier == 3, "A full meter awakens")
        precondition(probe.consumeAwakenedUlt() && !probe.consumeAwakenedUlt(), "One awakened ULT per awakening")
        for _ in 0...Int(Fighter.awakenedDuration * 60) { probe.updateFixed(1.0 / 60.0) }
        precondition(!probe.isAwakened && !probe.gainAwakening(100) && probe.awakeningTier == 2, "One awakening per round")
        probe.reset(at: 100, facing: 1); probe.apply(.guardian, for: 3)
        precondition(probe.takeHit(damage: 10, knockback: 50, unblockable: true) == 5 && probe.velocity.dx == 0, "Guardian halves damage and knockback")
    }
    private func setupHUD() {
        let backing = SKSpriteNode(color: Theme.navy.withAlphaComponent(0.58), size: CGSize(width: 480, height: 57))
        backing.position = CGPoint(x: 240, y: 241.5); backing.zPosition = 48; addChild(backing)
        for (index, fighter) in [player!, opponent!].enumerated() {
            let left = index == 0
            let name = Theme.label(fighter.data.name, size: 7, color: fighter.data.accentColor)
            name.horizontalAlignmentMode = left ? .left : .right
            name.position = CGPoint(x: left ? 49 : 431, y: 262); name.zPosition = 50; addChild(name)
            let hp = UIResourceBar(frame: "hp_frame", fill: "hp_\(fighter.data.id)_fill", nativeFrame: CGSize(width: 128, height: 14), nativeFill: CGSize(width: 124, height: 10), displayWidth: 166, outsideIsLeft: left)
            hp.position = CGPoint(x: left ? 132 : 348, y: 247); hp.zPosition = 50; addChild(hp); hpFill.append(hp)
            let energy = UIResourceBar(frame: "energy_frame", fill: "energy_fill", nativeFrame: CGSize(width: 96, height: 8), nativeFill: CGSize(width: 92, height: 4), displayWidth: 124, outsideIsLeft: left)
            energy.position = CGPoint(x: left ? 111 : 369, y: 233); energy.zPosition = 50; addChild(energy); energyFill.append(energy)
            let awaken = UIResourceBar(frame: "energy_frame", fill: "awaken_fill", nativeFrame: CGSize(width: 96, height: 8), nativeFill: CGSize(width: 92, height: 4), displayWidth: 100, outsideIsLeft: left)
            awaken.position = CGPoint(x: left ? 99 : 381, y: 222); awaken.zPosition = 50; addChild(awaken); awakeningFill.append(awaken)
            // Tier I and II thresholds, measured from the inner (center-facing) end where the fill starts.
            let inner: CGFloat = 96
            for mark in [CGFloat(0.3), 0.6] {
                let tick = SKSpriteNode(color: .white, size: CGSize(width: 1, height: 6))
                tick.alpha = 0.7; tick.zPosition = 3
                tick.position.x = left ? inner / 2 - inner * mark : -inner / 2 + inner * mark
                awaken.addChild(tick)
            }
            let tier = Theme.label("", size: 6, color: Theme.awaken)
            tier.position = CGPoint(x: left ? 160 : 320, y: 222); tier.zPosition = 50; addChild(tier); tierLabels.append(tier)
            var dots: [SKSpriteNode] = []
            for dotIndex in 0..<2 {
                let dot = UIAssets.shared.sprite("round_empty", size: CGSize(width: 16, height: 16))
                dot.position = CGPoint(x: left ? 189 + CGFloat(dotIndex) * 19 : 291 - CGFloat(dotIndex) * 19, y: 226)
                dot.zPosition = 50; addChild(dot); dots.append(dot)
            }
            scoreDots[index] = dots
            let portrait = SKNode(); portrait.position = CGPoint(x: left ? 24 : 456, y: 246); portrait.zPosition = 50
            let portraitBacking = SKSpriteNode(color: Theme.navy, size: CGSize(width: 28, height: 28)); portrait.addChild(portraitBacking)
            let crop = SKCropNode(); crop.maskNode = SKSpriteNode(color: .white, size: CGSize(width: 25, height: 25))
            let source = SpriteSheet.shared.frames(character: fighter.data, animation: "idle")[0]
            let face = SKTexture(rect: CGRect(x: 0.4, y: 0.5, width: 0.6, height: 0.5), in: source); face.filteringMode = .nearest
            let faceSprite = SKSpriteNode(texture: face, size: CGSize(width: 26, height: 29))
            crop.addChild(faceSprite); portrait.addChild(crop)
            let frame = UIAssets.shared.sprite("portrait_frame", size: CGSize(width: 32, height: 32)); frame.zPosition = 1
            portrait.addChild(frame); addChild(portrait)
        }
        let timerFrame = UIAssets.shared.sprite("timer_frame", size: CGSize(width: 48, height: 24))
        timerFrame.position = CGPoint(x: 240, y: 244); timerFrame.zPosition = 49; addChild(timerFrame)
        timerLabel.fontSize = 14; timerLabel.position = CGPoint(x: 240, y: 244); timerLabel.zPosition = 50; addChild(timerLabel)
    }
    /// Wide arenas show both fighters and the camera's view on a strip between the touch controls.
    private func setupMinimap() {
        guard map.isWide else { return }
        minimap.position = CGPoint(x: 240, y: 9); minimap.zPosition = 50; addChild(minimap)
        let strip = SKSpriteNode(color: Theme.navy.withAlphaComponent(0.7), size: CGSize(width: 124, height: 7))
        minimap.addChild(strip)
        minimapView.zPosition = 1; minimap.addChild(minimapView)
        for fighter in [player!, opponent!] {
            let dot = SKSpriteNode(color: fighter.data.accentColor, size: CGSize(width: 3, height: 5))
            dot.zPosition = 2; minimap.addChild(dot); minimapDots.append(dot)
        }
    }
    private func updateMinimap() {
        guard map.isWide else { return }
        let scale = 120 / map.arenaWidth
        for (dot, fighter) in zip(minimapDots, [player!, opponent!]) { dot.position.x = (fighter.position.x - map.arenaWidth / 2) * scale }
        minimapView.size.width = 480 / zoom * scale
        minimapView.position.x = (cameraX - map.arenaWidth / 2) * scale
    }
    /// Eases toward the framing target; `snap` jumps there at round start.
    private func updateCamera(_ dt: CGFloat, snap: Bool = false) {
        let target = CameraFraming.target(width: map.arenaWidth, leftX: min(player.position.x, opponent.position.x), rightX: max(player.position.x, opponent.position.x))
        let t: CGFloat = snap ? 1 : min(1, dt * 5)
        zoom += (target.zoom - zoom) * t
        cameraX = CameraFraming.clampedX(cameraX + (target.x - cameraX) * t, width: map.arenaWidth, zoom: zoom)
        // The floor stays at screen y = 42 while zooming, so the HUD and touch controls never cover more ground.
        world.setScale(zoom)
        world.position = CGPoint(x: 240 - cameraX * zoom + shakeOffset.x, y: 42 * (1 - zoom) + shakeOffset.y)
        arena.setCamera(x: cameraX)
        updateMinimap()
    }
    private func setupPausePanel() {
        pausePanel.zPosition = 110; pausePanel.isHidden = true
        let backing = SKSpriteNode(color: Theme.navy.withAlphaComponent(0.83), size: CGSize(width: 204, height: 78))
        backing.position = CGPoint(x: 240, y: 147); pausePanel.addChild(backing)
        let plate = UIAssets.shared.sprite("btn_menu_normal", size: CGSize(width: 96, height: 28))
        plate.centerRect = CGRect(x: 0.24, y: 0.32, width: 0.52, height: 0.36); plate.size = CGSize(width: 160, height: 34)
        plate.position = CGPoint(x: 240, y: 157); pausePanel.addChild(plate)
        let label = Theme.label("PAUSED", size: 14, color: Theme.gold); label.position = plate.position; label.zPosition = 1; pausePanel.addChild(label)
        let hint = Theme.label("TAP PAUSE OR PRESS P TO RESUME", size: 6, color: Theme.ice)
        hint.position = CGPoint(x: 240, y: 126); pausePanel.addChild(hint); addChild(pausePanel)
    }
    private func setFightPaused(_ value: Bool) {
        fightPaused = value; pausePanel.isHidden = !value
        // SpriteKit actions and the fixed-step simulation both stop, while touch routing stays live.
        speed = value ? 0 : 1
        accumulator = 0
        touchMap = touchMap.filter { $0.value == .pause }
        keyMap = keyMap.intersection([.pause])
        controls.clearPressed(except: [.pause])
        player.leftHeld = false; player.rightHeld = false; player.blockHeld = false
    }
    func pauseForInterruption() {
        if player != nil { setFightPaused(true); touchMap.removeAll(); keyMap.removeAll(); controls.clearPressed() }
    }
    private func startRound() {
        player.reset(at: map.spawnPoints.left, facing: 1); opponent.reset(at: map.spawnPoints.right, facing: -1)
        roundSeconds = 60; roundResolved = false; roundDraw = false; roundEndDelay = -1
        projectiles.forEach { $0.removeFromParent() }; projectiles.removeAll()
        pendingHits.removeAll(); landedSerial.removeAll(); comboHits = 0; comboTimer = 0
        terrain.reset()
        announcementPanel.texture = UIAssets.shared.texture("banner_fight", size: CGSize(width: 160, height: 40))
        announcement.fontColor = .white
        announcement.text = "FIGHT!"; roundLabel.text = "ROUND \(round)"
        for node in [announcementPanel as SKNode, announcement, roundLabel] {
            node.removeAllActions(); node.alpha = 1
            node.run(.sequence([.wait(forDuration: 0.8), .fadeOut(withDuration: 0.3)]))
        }
        controls.update(energy: player.energy, cooldowns: player.cooldowns, awakeningTier: player.awakeningTier, dt: 0)
        updateHUD()
        updateCamera(0, snap: true)
    }
    override func update(_ currentTime: TimeInterval) {
        if lastUpdate == 0 { lastUpdate = currentTime; return }
        let realDelta = min(0.1, max(0, currentTime - lastUpdate)); lastUpdate = currentTime
        if fightPaused { return }
        if hitStop > 0 { hitStop = max(0, hitStop - CGFloat(realDelta)); return }
        if slowMotion > 0 { slowMotion = max(0, slowMotion - CGFloat(realDelta)) }
        accumulator += CGFloat(realDelta) * (slowMotion > 0 ? 0.3 : 1)
        var iterations = 0
        while accumulator >= step && iterations < 6 { fixedUpdate(step); accumulator -= step; iterations += 1 }
        if iterations == 6 { accumulator = 0 }
    }
    private func fixedUpdate(_ dt: CGFloat) {
        if uiStatePreview { controls.update(energy: player.energy, cooldowns: player.cooldowns, awakeningTier: player.awakeningTier, dt: dt); return }
        arena.updateFixed(dt)
        if shakeTime > 0 {
            shakeTime -= dt
            shakeOffset = CGPoint(x: CGFloat.random(in: -2...2), y: CGFloat.random(in: -1...1))
        } else { shakeOffset = .zero }
        arena.position = shakeOffset
        if comboTimer > 0 { comboTimer -= dt; if comboTimer <= 0 { comboHits = 0; comboLabel.text = "" } }
        if roundEndDelay >= 0 {
            roundEndDelay -= dt
            if roundEndDelay < 0 { finishRound() }
            return
        }
        roundSeconds = max(0, roundSeconds - dt)
        applyInput()
        ai.updateFixed(dt)
        player.facing = player.position.x < opponent.position.x ? 1 : -1
        opponent.facing = -player.facing
        player.updateFixed(dt); opponent.updateFixed(dt)
        if abs(player.position.x - opponent.position.x) < 22 {
            let middle = (player.position.x + opponent.position.x) / 2
            if player.position.x < opponent.position.x { player.position.x = middle - 11; opponent.position.x = middle + 11 }
            else { player.position.x = middle + 11; opponent.position.x = middle - 11 }
        }
        terrain.updateFixed(dt, fighters: [player!, opponent!], projectiles: projectiles)
        if map.isWide && abs(player.position.x - opponent.position.x) > CameraFraming.maxGap {
            // Neither fighter may leave the widest camera view.
            let middle = (player.position.x + opponent.position.x) / 2, half = CameraFraming.maxGap / 2
            let playerLeft = player.position.x < opponent.position.x
            player.position.x = middle + (playerLeft ? -half : half); opponent.position.x = middle + (playerLeft ? half : -half)
        }
        handleMove(player, target: opponent)
        handleMove(opponent, target: player)
        for projectile in projectiles {
            projectile.updateFixed(dt)
            let target = projectile.owner === player ? opponent! : player!
            guard !projectile.didHit, projectile.parent != nil, projectile.hitbox.intersects(target.hurtbox) else { continue }
            if target.isReflecting {
                projectile.reflect(to: target)
                showEffect("hit_spark", at: projectile.position, color: target.data.accentColor)
                continue
            }
            if target.has(.vanish) { continue }
            projectile.didHit = true
            registerHit(attacker: projectile.owner, target: target, damage: projectile.damage, knockback: projectile.direction * 48 * projectile.pushScale, unblockable: false,
                        effect: projectile.effect, enhanced: projectile.enhanced)
            showEffect("skill1_impact", at: projectile.position, color: projectile.owner.data.accentColor)
            projectile.removeFromParent()
        }
        projectiles.removeAll { $0.parent == nil }
        resolvePendingHits(dt)
        controls.update(energy: player.energy, cooldowns: player.cooldowns, awakeningTier: player.awakeningTier, dt: dt)
        updateHUD()
        updateCamera(dt)
        if player.hp == 0 || opponent.hp == 0 || roundSeconds <= 0 { resolveRound() }
        if debugEnabled { drawDebug() }
    }
    private func handleMove(_ attacker: Fighter, target: Fighter) {
        guard let move = attacker.currentMove, let info = attacker.data.moves[move] else { return }
        let shots = move == "skill1" ? max(0, info.projectiles ?? 1) : 0
        let enhanced = (move == "skill1" || move == "skill2") && attacker.awakeningTier >= 2
        if shots > 0, !attacker.emitted, attacker.currentFrame >= info.activeStart {
            attacker.markEmitted()
            // A fan splits the move's total damage; each projectile can land once.
            for index in 0..<shots {
                let damage = info.damage / shots + (index < info.damage % shots ? 1 : 0)
                let rise = (CGFloat(index) - CGFloat(shots - 1) / 2) * 42
                let projectile = Projectile(owner: attacker, damage: max(1, damage), direction: attacker.facing, rise: rise,
                                            effect: hitEffect(info, enhanced: enhanced), enhanced: enhanced)
                projectile.arenaWidth = map.arenaWidth
                projectile.zPosition = 20; world.addChild(projectile); projectiles.append(projectile)
            }
        }
        if let name = info.buff, move != "ult", !attacker.emitted, attacker.currentFrame >= info.activeStart {
            attacker.markEmitted()
            castBuff(name, info: info, caster: attacker, target: target)
        }
        if move == "ult", !attacker.emitted, attacker.currentFrame >= info.activeStart {
            attacker.markEmitted(); darkOverlay.alpha = 0.65
            darkOverlay.run(.sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.25)]))
            let awakened = attacker.consumeAwakenedUlt() ? attacker.data.moves["ultAwakened"] : nil
            let size = awakened == nil ? CGSize(width: 250, height: 130) : CGSize(width: 320, height: 170)
            let effect = EffectNode(name: SpriteSheet.shared.effectName("ult", character: attacker.data), frames: 8, color: attacker.data.accentColor, size: size, frameTime: 0.08)
            effect.position = CGPoint(x: cameraX, y: 110); effect.zPosition = 45; world.addChild(effect)
            if let awakened { castAwakenedUlt(awakened, caster: attacker, target: target) }
            else {
                for (index, delay) in [CGFloat(0), 0.13, 0.26].enumerated() {
                    pendingHits.append(PendingHit(time: delay, attacker: attacker, defender: target, damage: index == 2 ? 11 : 12,
                                                  unblockable: index == 0, kind: .ult, knockback: attacker.facing * 18))
                }
            }
        }
        if info.teleport == true, !attacker.emitted, attacker.currentFrame >= info.activeStart {
            attacker.position.x = min(map.arenaWidth - 26, max(26, target.position.x + (attacker.position.x < target.position.x ? 27 : -27)))
            attacker.facing = attacker.position.x < target.position.x ? 1 : -1
            attacker.markEmitted()
            showEffect("dash_trail", at: attacker.position, color: attacker.data.accentColor)
        }
        guard shots == 0, move != "ult", info.damage > 0, let hitbox = attacker.hitbox(for: move), hitbox.intersects(target.hurtbox) else { return }
        let key = ObjectIdentifier(attacker)
        guard landedSerial[key] != attacker.attackSerial else { return }
        landedSerial[key] = attacker.attackSerial
        registerHit(attacker: attacker, target: target, damage: info.damage, knockback: attacker.facing * info.knockback, unblockable: false,
                    effect: hitEffect(info, enhanced: enhanced), enhanced: enhanced)
    }
    private func hitEffect(_ info: MoveData, enhanced: Bool) -> HitEffect? {
        guard enhanced, let extra = info.enhanced else { return info.onHit }
        return (info.onHit ?? HitEffect()).merged(with: extra)
    }
    /// SK3: apply the caster's buff; a summon also schedules its phantom's three strikes.
    private func castBuff(_ name: String, info: MoveData, caster: Fighter, target: Fighter) {
        guard let buff = Buff(rawValue: name) else { return }
        let duration = info.buffTime ?? 3
        caster.apply(buff, for: duration)
        if buff != .meditate, let heal = info.heal { caster.heal(heal) }
        if buff == .summon {
            for strike in 1...3 {
                pendingHits.append(PendingHit(time: duration * CGFloat(strike) / 4, attacker: caster, defender: target, damage: 5, unblockable: false, kind: .summon))
            }
        }
        showEffect("skill1_impact", at: CGPoint(x: caster.position.x, y: caster.position.y + 30), color: caster.data.accentColor)
        callout(info.title, over: caster)
    }
    /// The once-per-awakening ULT: fixed spec damage split over `hits`, plus its buff, heal or pull.
    private func castAwakenedUlt(_ spec: MoveData, caster: Fighter, target: Fighter) {
        darkOverlay.removeAllActions(); darkOverlay.alpha = 0.75
        darkOverlay.run(.sequence([.wait(forDuration: 0.9), .fadeOut(withDuration: 0.3)]))
        callout(spec.title, over: caster, color: Theme.awaken, size: 10)
        if let name = spec.buff, let buff = Buff(rawValue: name) { caster.apply(buff, for: spec.buffTime ?? 3) }
        if let heal = spec.heal { caster.heal(heal) }
        if spec.pull == true {
            target.position.x = min(map.arenaWidth - 26, max(26, caster.position.x + caster.facing * 40)); target.velocity = .zero
            for projectile in projectiles where projectile.owner === target { projectile.removeFromParent() }
        }
        let hits = max(1, spec.hits ?? 4)
        for index in 0..<hits {
            let last = index == hits - 1
            pendingHits.append(PendingHit(time: (spec.delay ?? 0) + CGFloat(index) * (spec.hitInterval ?? 0.15), attacker: caster, defender: target,
                                          damage: spec.damage / hits + (index < spec.damage % hits ? 1 : 0),
                                          unblockable: spec.unblockable == true || index == 0, kind: .ult,
                                          effect: last ? spec.onHit : nil, knockback: caster.facing * (last ? spec.knockback : 18)))
        }
    }
    private func resolvePendingHits(_ dt: CGFloat) {
        // Indices are captured up front; echoes appended during the loop resolve on a later step.
        for i in pendingHits.indices.reversed() {
            pendingHits[i].time -= dt
            guard pendingHits[i].time <= 0 else { continue }
            let hit = pendingHits.remove(at: i)
            guard hit.defender.hp > 0 else { continue }
            switch hit.kind {
            case .ult:
                registerHit(attacker: hit.attacker, target: hit.defender, damage: hit.damage, knockback: hit.knockback, unblockable: hit.unblockable,
                            effect: hit.effect, scaled: false, allowEcho: false)
            case .echo:
                guard hit.attacker.has(.clone), hit.attacker.hp > 0 else { continue }
                registerHit(attacker: hit.attacker, target: hit.defender, damage: hit.damage, knockback: hit.knockback, unblockable: false,
                            scaled: false, allowEcho: false)
            case .summon:
                let dx = hit.defender.position.x - hit.attacker.position.x
                guard hit.attacker.has(.summon), hit.attacker.hp > 0, abs(dx) < 170 else { continue }
                let phantom = hit.attacker.phantom, home = -24 * hit.attacker.facing
                phantom.run(.sequence([.moveTo(x: dx - 14 * hit.attacker.facing, duration: 0.08), .wait(forDuration: 0.08), .moveTo(x: home, duration: 0.14)]), withKey: "strike")
                registerHit(attacker: hit.attacker, target: hit.defender, damage: hit.damage, knockback: hit.attacker.facing * 20, unblockable: false, allowEcho: false)
            }
        }
    }
    private func callout(_ text: String?, over fighter: Fighter, color: SKColor? = nil, size: CGFloat = 8) {
        guard let text, !text.isEmpty else { return }
        let label = Theme.label(text, size: size, color: color ?? fighter.data.accentColor)
        label.position = CGPoint(x: min(map.arenaWidth - 80, max(80, fighter.position.x)), y: min(200, fighter.position.y + 84)); label.zPosition = 61
        world.addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: 14, duration: 1.1), .sequence([.wait(forDuration: 0.7), .fadeOut(withDuration: 0.4)])]), .removeFromParent()]))
    }
    /// Awakening gains: the fighter with less HP charges 50% faster.
    private func gainAwakening(_ fighter: Fighter, _ amount: CGFloat, versus other: Fighter) {
        guard fighter.gainAwakening(amount * (fighter.hp < other.hp ? 1.5 : 1)) else { return }
        callout("THỨC TỈNH!", over: fighter, color: Theme.awaken, size: 11)
        showEffect("hit_spark", at: CGPoint(x: fighter.position.x, y: fighter.position.y + 30), color: Theme.awaken)
        slowMotion = max(slowMotion, 0.25)
    }
    /// `scaled` applies awakening, tier II, frenzy and empower bonuses; ULT hits keep their fixed spec damage.
    private func registerHit(attacker: Fighter, target: Fighter, damage: Int, knockback: CGFloat, unblockable: Bool,
                             effect: HitEffect? = nil, enhanced: Bool = false, scaled: Bool = true, allowEcho: Bool = true) {
        let empowered = scaled && attacker.has(.empower)
        var amount = CGFloat(damage)
        if scaled { amount *= attacker.damageMultiplier(enhanced: enhanced) * (empowered ? 1.5 : 1) }
        let dealt = target.takeHit(damage: max(1, Int(amount.rounded())), knockback: knockback, unblockable: unblockable)
        guard dealt > 0 else { return }
        if empowered { _ = attacker.consumeEmpower() }
        attacker.gainEnergy(8)
        gainAwakening(attacker, 6, versus: target)
        gainAwakening(target, target.lastHitGuarded ? 4 : 3, versus: attacker)
        if !target.lastHitGuarded {
            if let effect {
                target.applyEffect(effect)
                if let drain = effect.drain { attacker.heal(max(1, Int((CGFloat(dealt) * drain).rounded()))) }
            }
            if attacker.has(.frenzy) { attacker.heal(max(1, Int((CGFloat(dealt) * 0.2).rounded()))) }
        }
        if allowEcho && attacker.has(.clone) {
            // The shadow clone repeats the hit at 40% a moment later.
            pendingHits.append(PendingHit(time: 0.12, attacker: attacker, defender: target, damage: max(1, damage * 2 / 5),
                                          unblockable: false, kind: .echo, knockback: knockback))
        }
        hitStop = 0.06; shakeTime = 0.18
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let position = CGPoint(x: (attacker.position.x + target.position.x) / 2, y: target.position.y + 32)
        showEffect("hit_spark", at: position, color: attacker.data.accentColor)
        if attacker === player {
            comboHits = comboTimer > 0 ? comboHits + 1 : 1
            comboTimer = 1.1
            comboLabel.text = comboHits >= 2 ? "\(comboHits) HIT COMBO!" : ""
        }
    }
    private func showEffect(_ name: String, at point: CGPoint, color: SKColor) {
        let effect = EffectNode(name: name, frames: name == "dash_trail" ? 4 : 5, color: color, size: CGSize(width: 58, height: 58))
        effect.position = point; effect.zPosition = 35; world.addChild(effect)
    }
    private func resolveRound() {
        guard !roundResolved else { return }
        roundResolved = true; roundEndDelay = 1.1; slowMotion = 0.5
        roundDraw = player.hp == opponent.hp
        if !roundDraw {
            let winner = player.hp > opponent.hp ? player! : opponent!
            winner.wins += 1
            winner.victoryPose()
        }
        for node in [announcementPanel as SKNode, announcement, roundLabel] { node.removeAllActions(); node.alpha = 1 }
        announcementPanel.texture = UIAssets.shared.texture(roundDraw ? "banner_fight" : "banner_ko", size: CGSize(width: 160, height: 40))
        announcement.fontColor = roundDraw ? Theme.gold : Theme.fire
        announcement.text = roundDraw ? "DRAW" : "K.O."; roundLabel.text = ""
        updateHUD()
    }
    private func finishRound() {
        if player.wins >= 2 || opponent.wins >= 2 || round >= 3 {
            transition(to: ResultScene(size: size, config: config, victory: player.wins >= opponent.wins))
        } else { if !roundDraw { round += 1 }; startRound() }
    }
    private func updateHUD() {
        timerLabel.text = String(Int(ceil(roundSeconds)))
        for (index, fighter) in [player!, opponent!].enumerated() {
            hpFill[index].setFraction(CGFloat(fighter.hp) / 100)
            energyFill[index].setFraction(CGFloat(fighter.energy) / 100)
            awakeningFill[index].setFraction(fighter.awakeningFraction)
            tierLabels[index].text = ["", "I", "II", "III"][fighter.awakeningTier]
            for dotIndex in 0..<2 {
                scoreDots[index][dotIndex].texture = UIAssets.shared.texture(fighter.wins > dotIndex ? "round_filled" : "round_empty", size: CGSize(width: 16, height: 16))
            }
        }
    }
    private func drawDebug() {
        debugNodes.forEach { $0.removeFromParent() }; debugNodes.removeAll()
        for fighter in [player!, opponent!] {
            let hurt = HitboxSystem.debugRect(fighter.hurtbox, color: .green); world.addChild(hurt); debugNodes.append(hurt)
            if let move = fighter.currentMove, let box = fighter.hitbox(for: move) {
                let hit = HitboxSystem.debugRect(box, color: .red); world.addChild(hit); debugNodes.append(hit)
            }
        }
        for projectile in projectiles { let box = HitboxSystem.debugRect(projectile.hitbox, color: .yellow); world.addChild(box); debugNodes.append(box) }
    }
    private func applyInput() {
        guard !fightPaused else { return }
        let held = Set(touchMap.values).union(keyMap)
        player.leftHeld = held.contains(.left)
        player.rightHeld = held.contains(.right)
        player.blockHeld = held.contains(.block) || held.contains(.down)
    }
    private func controlDown(_ control: Control) {
        if control == .pause { controls.setPressed(control, true); setFightPaused(!fightPaused); return }
        guard !fightPaused else { return }
        controls.setPressed(control, true)
        guard roundEndDelay < 0 || control == .debug else { return }
        switch control {
        case .up: player.jump()
        case .attack: player.attack()
        case .skill1: _ = player.use("skill1")
        case .skill2: _ = player.use("skill2")
        case .skill3: _ = player.use("skill3")
        case .ult: _ = player.use("ult")
        case .debug:
            debugEnabled.toggle(); controls.setDebug(debugEnabled)
            if !debugEnabled { debugNodes.forEach { $0.removeFromParent() }; debugNodes.removeAll() }
        default: break
        }
        applyInput()
    }
    private func controlUp(_ control: Control) {
        let stillHeld = touchMap.values.contains(control) || keyMap.contains(control)
        controls.setPressed(control, stillHeld); applyInput()
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let control = controls.control(at: touch.location(in: self)) {
                touchMap[ObjectIdentifier(touch)] = control; controlDown(control)
            }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch), next = controls.control(at: touch.location(in: self))
            if touchMap[id] != next {
                if let old = touchMap[id] { touchMap.removeValue(forKey: id); controlUp(old) }
                if let next { touchMap[id] = next; controlDown(next) }
            }
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { if let old = touchMap.removeValue(forKey: ObjectIdentifier(touch)) { controlUp(old) } }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchesEnded(touches, with: event) }
    func keyChanged(_ key: String, down: Bool) {
        guard let control = KeyboardInput.control(for: key) else { return }
        if down { if keyMap.insert(control).inserted { controlDown(control) } }
        else { keyMap.remove(control); controlUp(control) }
    }
}

extension FightScene: TerrainDelegate {
    func terrainHit(_ fighter: Fighter, damage: Int, knockback: CGFloat, launch: CGFloat, stun: CGFloat, color: SKColor) -> Bool {
        guard roundEndDelay < 0 else { return false }
        let dealt = fighter.takeHit(damage: damage, knockback: knockback, unblockable: true)
        guard dealt > 0 else { return false }
        if launch > 0 && fighter.hp > 0 { fighter.velocity.dy = launch; fighter.onGround = false }
        if stun > 0 { fighter.applyEffect(HitEffect(stun: stun)) }
        gainAwakening(fighter, 3, versus: fighter === player ? opponent! : player!)
        shakeTime = max(shakeTime, 0.12)
        showEffect("hit_spark", at: CGPoint(x: fighter.position.x, y: fighter.position.y + 30), color: color)
        return true
    }
    func terrainAwakening(_ fighter: Fighter, amount: CGFloat) {
        gainAwakening(fighter, amount, versus: fighter === player ? opponent! : player!)
    }
    func terrainCallout(_ text: String, at point: CGPoint?, color: SKColor) {
        let label = Theme.label(text, size: 8, color: color)
        label.zPosition = 61
        if let point {
            label.position = CGPoint(x: min(map.arenaWidth - 60, max(60, point.x)), y: min(200, point.y)); world.addChild(label)
        } else {
            label.position = CGPoint(x: 240, y: 180); addChild(label)
        }
        label.run(.sequence([.group([.moveBy(x: 0, y: 12, duration: 1), .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.4)])]), .removeFromParent()]))
    }
}
extension FightScene: KeyboardControllable {}
