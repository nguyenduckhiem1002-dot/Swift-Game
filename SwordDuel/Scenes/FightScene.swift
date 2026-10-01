import SpriteKit
import UIKit

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
    private var combat: CombatSystem!
    private let input = PlayerInputRouter()
    private var controls: TouchControls { input.controls }
    private var cameraX: CGFloat = 240
    private var zoom: CGFloat = 1
    private var shakeOffset = CGPoint.zero
    private let minimap = SKNode()
    private var minimapDots: [SKSpriteNode] = []
    private let minimapView = SKSpriteNode(color: SKColor.white.withAlphaComponent(0.25), size: CGSize(width: 10, height: 7))
    private var debugEnabled = false
    private var accumulator: CGFloat = 0
    private var lastUpdate: TimeInterval = 0
    private let step: CGFloat = 1.0 / 60.0
    private var hitStop: CGFloat = 0
    private var slowMotion: CGFloat = 0
    private var roundSeconds: CGFloat = 60
    private var round = 1
    /// While a decided round winds down, only the hitbox overlay responds to input.
    private var roundEndDelay: CGFloat = -1 { didSet { input.actionsLocked = roundEndDelay >= 0 } }
    private var roundResolved = false
    private var roundDraw = false
    private var huds: [FighterHUD] = []
    private var scoreDots: [[SKSpriteNode]] = [[], []]
    private var timerLabel = Theme.label("60", size: 18, color: Theme.gold)
    private var announcement = Theme.label("", size: 25, color: Theme.gold)
    private var shakeTime: CGFloat = 0
    private var fightPaused = false
    private var uiStatePreview = false
    private let pausePanel = PausePanel()
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
        combat = CombatSystem(world: world, screen: self, arenaWidth: map.arenaWidth)
        combat.host = self; combat.comboFighter = player
        input.fighter = player
        input.onTogglePause = { [weak self] in
            guard let self else { return }
            self.setFightPaused(!self.fightPaused)
        }
        input.onToggleDebug = { [weak self] in self?.toggleDebug() }
        controls.configure(character: playerData)
        addChild(controls)
        setupHUD()
        setupMinimap()
        addChild(pausePanel)
        announcementPanel.position = CGPoint(x: 240, y: 166); announcementPanel.size = CGSize(width: 160, height: 40)
        announcementPanel.zPosition = 59; addChild(announcementPanel)
        announcement.position = CGPoint(x: 240, y: 166); announcement.zPosition = 60; addChild(announcement)
        roundLabel.position = CGPoint(x: 240, y: 194); roundLabel.zPosition = 60; addChild(roundLabel)
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
        input.press(.left, touch: ObjectIdentifier(first))
        input.press(.left, touch: ObjectIdentifier(second))
        input.release(touch: ObjectIdentifier(first))
        precondition(player.leftHeld && controls.isPressed(.left), "One released finger must not release another finger's button")
        input.release(touch: ObjectIdentifier(second))
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
        runCombatChecks()
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
    /// The shared damage pipeline against a fighter and a monster, without a scene.
    private func runCombatChecks() {
        let system = CombatSystem(world: SKNode(), screen: SKNode(), arenaWidth: 480)
        let attacker = Fighter(data: CharacterLibrary.all[0], isPlayer: true), defender = Fighter(data: CharacterLibrary.all[1], isPlayer: false)
        attacker.reset(at: 200, facing: 1); defender.reset(at: 240, facing: -1)
        precondition(system.registerHit(attacker: attacker, target: defender, damage: 10, knockback: 20) == 10 && defender.hp == 90 && attacker.energy == 8,
                     "A landed hit deals damage and charges the attacker's energy")
        precondition(attacker.awakeningFraction > 0 && defender.awakeningFraction > 0, "Both fighters gain awakening from a hit")
        attacker.apply(.empower, for: 5)
        precondition(system.registerHit(attacker: attacker, target: defender, damage: 10, knockback: 0) == 15 && !attacker.has(.empower),
                     "Empower adds 50% to one hit")
        guard let wolf = MonsterLibrary.monster("wolf") else { preconditionFailure("The wolf monster is missing") }
        let monster = Monster(data: wolf, elite: false, at: CGPoint(x: 260, y: 42))
        for _ in 0..<60 { monster.update(1.0 / 60.0, target: attacker) }
        let before = monster.hp
        precondition(system.registerHit(attacker: attacker, target: monster, damage: 6, knockback: 0) == 6 && monster.hp == before - 6,
                     "Monsters take the same damage pipeline")
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
            let hud = FighterHUD(fighter: fighter, left: left); hud.zPosition = 50; addChild(hud); huds.append(hud)
            var dots: [SKSpriteNode] = []
            for dotIndex in 0..<2 {
                let dot = UIAssets.shared.sprite("round_empty", size: CGSize(width: 16, height: 16))
                dot.position = CGPoint(x: left ? 189 + CGFloat(dotIndex) * 19 : 291 - CGFloat(dotIndex) * 19, y: 226)
                dot.zPosition = 50; addChild(dot); dots.append(dot)
            }
            scoreDots[index] = dots
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
    private func setFightPaused(_ value: Bool) {
        fightPaused = value; pausePanel.isHidden = !value
        // SpriteKit actions and the fixed-step simulation both stop, while touch routing stays live.
        speed = value ? 0 : 1
        accumulator = 0
        input.isPaused = value
        input.suspend()
    }
    func pauseForInterruption() {
        if player != nil { setFightPaused(true); input.reset() }
    }
    private func toggleDebug() {
        debugEnabled.toggle(); controls.setDebug(debugEnabled)
        if !debugEnabled { combat.clearDebug() }
    }
    private func startRound() {
        player.reset(at: map.spawnPoints.left, facing: 1); opponent.reset(at: map.spawnPoints.right, facing: -1)
        roundSeconds = 60; roundResolved = false; roundDraw = false; roundEndDelay = -1
        combat.reset()
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
        combat.updateTimers(dt)
        if roundEndDelay >= 0 {
            roundEndDelay -= dt
            if roundEndDelay < 0 { finishRound() }
            return
        }
        roundSeconds = max(0, roundSeconds - dt)
        input.applyHeld()
        ai.updateFixed(dt)
        player.facing = player.position.x < opponent.position.x ? 1 : -1
        opponent.facing = -player.facing
        player.updateFixed(dt); opponent.updateFixed(dt)
        if abs(player.position.x - opponent.position.x) < 22 {
            let middle = (player.position.x + opponent.position.x) / 2
            if player.position.x < opponent.position.x { player.position.x = middle - 11; opponent.position.x = middle + 11 }
            else { player.position.x = middle + 11; opponent.position.x = middle - 11 }
        }
        terrain.updateFixed(dt, fighters: [player!, opponent!], projectiles: combat.projectiles)
        if map.isWide && abs(player.position.x - opponent.position.x) > CameraFraming.maxGap {
            // Neither fighter may leave the widest camera view.
            let middle = (player.position.x + opponent.position.x) / 2, half = CameraFraming.maxGap / 2
            let playerLeft = player.position.x < opponent.position.x
            player.position.x = middle + (playerLeft ? -half : half); opponent.position.x = middle + (playerLeft ? half : -half)
        }
        combat.update(dt, attackers: [player!, opponent!])
        controls.update(energy: player.energy, cooldowns: player.cooldowns, awakeningTier: player.awakeningTier, dt: dt)
        updateHUD()
        updateCamera(dt)
        if player.hp == 0 || opponent.hp == 0 || roundSeconds <= 0 { resolveRound() }
        if debugEnabled { combat.drawDebug(fighters: [player!, opponent!]) }
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
            huds[index].update(fighter)
            for dotIndex in 0..<2 {
                scoreDots[index][dotIndex].texture = UIAssets.shared.texture(fighter.wins > dotIndex ? "round_filled" : "round_empty", size: CGSize(width: 16, height: 16))
            }
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { input.touchesBegan(touches, in: self) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { input.touchesMoved(touches, in: self) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { input.touchesEnded(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { input.touchesEnded(touches) }
    func keyChanged(_ key: String, down: Bool) { input.keyChanged(key, down: down) }
}

extension FightScene: TerrainDelegate {
    func terrainHit(_ fighter: Fighter, damage: Int, knockback: CGFloat, launch: CGFloat, stun: CGFloat, color: SKColor) -> Bool {
        guard roundEndDelay < 0, combat.applyArenaHit(fighter, damage: damage, knockback: knockback, launch: launch, stun: stun, color: color) else { return false }
        shakeTime = max(shakeTime, 0.12)
        return true
    }
    func terrainAwakening(_ fighter: Fighter, amount: CGFloat) {
        combat.gainAwakening(fighter, amount, versus: fighter === player ? opponent! : player!)
    }
    func terrainCallout(_ text: String, at point: CGPoint?, color: SKColor) {
        combat.callout(text, at: point, color: color)
    }
}

extension FightScene: CombatHost {
    func combatTargets(for attacker: Fighter) -> [CombatTarget] { [attacker === player ? opponent! : player!] }
    func combatUltTargets(for attacker: Fighter) -> [CombatTarget] { combatTargets(for: attacker) }
    var combatCameraX: CGFloat { cameraX }
    func combatDidLandHit(attacker: Fighter, target: CombatTarget) { hitStop = 0.06; shakeTime = 0.18 }
    func combatDidAwaken(_ fighter: Fighter) { slowMotion = max(slowMotion, 0.25) }
}

extension FightScene: KeyboardControllable {}
