import SpriteKit
import UIKit

final class FightScene: GameScene {
    private let config: MatchConfig
    private var player: Fighter!
    private var opponent: Fighter!
    private var ai: AIController!
    private let map: MapData
    private let arena: ArenaBackground
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
    private var pendingUlt: [(time: CGFloat, attacker: Fighter, defender: Fighter, damage: Int, first: Bool)] = []
    private var landedSerial: [ObjectIdentifier: Int] = [:]
    private var comboHits = 0
    private var comboTimer: CGFloat = 0
    private var hpFill: [UIResourceBar] = []
    private var energyFill: [UIResourceBar] = []
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
        arena = ArenaBackground(map: map)
        super.init(size: size)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func didMove(to view: SKView) {
        arena.zPosition = -10; addChild(arena)
        let playerData = CharacterLibrary.all[config.playerIndex]
        let opponentData = CharacterLibrary.all[config.opponentIndex]
        player = Fighter(data: playerData, isPlayer: true)
        opponent = Fighter(data: opponentData, isPlayer: false)
        for fighter in [player!, opponent!] { fighter.gravityScale = map.gravityScale; fighter.moveScale = map.movementScale }
        player.zPosition = 15; opponent.zPosition = 15
        addChild(player); addChild(opponent)
        ai = AIController(fighter: opponent, target: player, difficulty: config.difficulty)
        controls.configure(character: playerData)
        addChild(controls)
        setupHUD()
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
            player.cooldowns = ["skill1": 1.5, "skill2": 3.75]
            for node in [announcementPanel as SKNode, announcement, roundLabel] { node.removeAllActions(); node.alpha = 0 }
            controls.setPressed(.attack, true)
            controls.update(energy: player.energy, cooldowns: player.cooldowns, dt: 0)
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
        for map in MapLibrary.all { precondition(!ArenaBackground(map: map).children.isEmpty, "\(map.id) arena is empty") }
        print("PASS UI: shared touch ownership, independent inputs, pause/resume, frozen timer, disabled/pressed menu states, missing-file fallback, \(CharacterLibrary.all.count) character rosters and ULT strips, \(MapLibrary.all.count) arenas.")
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
        player.reset(at: 122, facing: 1); opponent.reset(at: 358, facing: -1)
        roundSeconds = 60; roundResolved = false; roundDraw = false; roundEndDelay = -1
        projectiles.forEach { $0.removeFromParent() }; projectiles.removeAll()
        pendingUlt.removeAll(); landedSerial.removeAll(); comboHits = 0; comboTimer = 0
        announcementPanel.texture = UIAssets.shared.texture("banner_fight", size: CGSize(width: 160, height: 40))
        announcement.fontColor = .white
        announcement.text = "FIGHT!"; roundLabel.text = "ROUND \(round)"
        for node in [announcementPanel as SKNode, announcement, roundLabel] {
            node.removeAllActions(); node.alpha = 1
            node.run(.sequence([.wait(forDuration: 0.8), .fadeOut(withDuration: 0.3)]))
        }
        controls.update(energy: player.energy, cooldowns: player.cooldowns, dt: 0)
        updateHUD()
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
        if uiStatePreview { controls.update(energy: player.energy, cooldowns: player.cooldowns, dt: dt); return }
        arena.updateFixed(dt)
        if shakeTime > 0 {
            shakeTime -= dt
            arena.position = CGPoint(x: CGFloat.random(in: -2...2), y: CGFloat.random(in: -1...1))
        } else { arena.position = .zero }
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
        handleMove(player, target: opponent)
        handleMove(opponent, target: player)
        for projectile in projectiles {
            projectile.updateFixed(dt)
            let target = projectile.owner === player ? opponent! : player!
            if !projectile.didHit && projectile.parent != nil && projectile.hitbox.intersects(target.hurtbox) {
                projectile.didHit = true
                registerHit(attacker: projectile.owner, target: target, damage: projectile.damage, knockback: projectile.direction * 48, unblockable: false)
                showEffect("skill1_impact", at: projectile.position, color: projectile.owner.data.accentColor)
                projectile.removeFromParent()
            }
        }
        projectiles.removeAll { $0.parent == nil }
        for i in pendingUlt.indices.reversed() {
            pendingUlt[i].time -= dt
            if pendingUlt[i].time <= 0 {
                let hit = pendingUlt.remove(at: i)
                if hit.defender.hp > 0 { registerHit(attacker: hit.attacker, target: hit.defender, damage: hit.damage, knockback: hit.attacker.facing * 18, unblockable: hit.first) }
            }
        }
        controls.update(energy: player.energy, cooldowns: player.cooldowns, dt: dt)
        updateHUD()
        if player.hp == 0 || opponent.hp == 0 || roundSeconds <= 0 { resolveRound() }
        if debugEnabled { drawDebug() }
    }
    private func handleMove(_ attacker: Fighter, target: Fighter) {
        guard let move = attacker.currentMove, let info = attacker.data.moves[move] else { return }
        let shots = move == "skill1" ? max(0, info.projectiles ?? 1) : 0
        if shots > 0, !attacker.emitted, attacker.currentFrame >= info.activeStart {
            attacker.markEmitted()
            // A fan splits the move's total damage; each projectile can land once.
            for index in 0..<shots {
                let damage = info.damage / shots + (index < info.damage % shots ? 1 : 0)
                let rise = (CGFloat(index) - CGFloat(shots - 1) / 2) * 42
                let projectile = Projectile(owner: attacker, damage: max(1, damage), direction: attacker.facing, rise: rise)
                projectile.zPosition = 20; addChild(projectile); projectiles.append(projectile)
            }
        }
        if move == "ult", !attacker.emitted, attacker.currentFrame >= info.activeStart {
            attacker.markEmitted(); darkOverlay.alpha = 0.65
            darkOverlay.run(.sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.25)]))
            let effect = EffectNode(name: SpriteSheet.shared.effectName("ult", character: attacker.data), frames: 8, color: attacker.data.accentColor, size: CGSize(width: 250, height: 130), frameTime: 0.08)
            effect.position = CGPoint(x: 240, y: 110); effect.zPosition = 45; addChild(effect)
            for (index, delay) in [CGFloat(0), 0.13, 0.26].enumerated() {
                pendingUlt.append((time: delay, attacker: attacker, defender: target, damage: index == 2 ? 11 : 12, first: index == 0))
            }
        }
        if info.teleport == true, !attacker.emitted, attacker.currentFrame >= info.activeStart {
            attacker.position.x = min(454, max(26, target.position.x + (attacker.position.x < target.position.x ? 27 : -27)))
            attacker.facing = attacker.position.x < target.position.x ? 1 : -1
            attacker.markEmitted()
            showEffect("dash_trail", at: attacker.position, color: attacker.data.accentColor)
        }
        guard shots == 0, move != "ult", let hitbox = attacker.hitbox(for: move), hitbox.intersects(target.hurtbox) else { return }
        let key = ObjectIdentifier(attacker)
        guard landedSerial[key] != attacker.attackSerial else { return }
        landedSerial[key] = attacker.attackSerial
        registerHit(attacker: attacker, target: target, damage: info.damage, knockback: attacker.facing * info.knockback, unblockable: false)
    }
    private func registerHit(attacker: Fighter, target: Fighter, damage: Int, knockback: CGFloat, unblockable: Bool) {
        let dealt = target.takeHit(damage: damage, knockback: knockback, unblockable: unblockable)
        guard dealt > 0 else { return }
        attacker.energy = min(100, attacker.energy + 8)
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
        effect.position = point; effect.zPosition = 35; addChild(effect)
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
            for dotIndex in 0..<2 {
                scoreDots[index][dotIndex].texture = UIAssets.shared.texture(fighter.wins > dotIndex ? "round_filled" : "round_empty", size: CGSize(width: 16, height: 16))
            }
        }
    }
    private func drawDebug() {
        debugNodes.forEach { $0.removeFromParent() }; debugNodes.removeAll()
        for fighter in [player!, opponent!] {
            let hurt = HitboxSystem.debugRect(fighter.hurtbox, color: .green); addChild(hurt); debugNodes.append(hurt)
            if let move = fighter.currentMove, let box = fighter.hitbox(for: move) {
                let hit = HitboxSystem.debugRect(box, color: .red); addChild(hit); debugNodes.append(hit)
            }
        }
        for projectile in projectiles { let box = HitboxSystem.debugRect(projectile.hitbox, color: .yellow); addChild(box); debugNodes.append(box) }
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
