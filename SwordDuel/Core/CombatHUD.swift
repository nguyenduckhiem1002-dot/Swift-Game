import SpriteKit

/// One fighter's name, HP, energy and awakening bars, tier label and portrait, mirrored for the right side.
final class FighterHUD: SKNode {
    private let hp: UIResourceBar
    private let energy: UIResourceBar
    private let awakening: UIResourceBar
    private let tier = Theme.label("", size: 6, color: Theme.awaken)

    init(fighter: Fighter, left: Bool) {
        hp = UIResourceBar(frame: "hp_frame", fill: "hp_\(fighter.data.id)_fill", nativeFrame: CGSize(width: 128, height: 14), nativeFill: CGSize(width: 124, height: 10), displayWidth: 166, outsideIsLeft: left)
        energy = UIResourceBar(frame: "energy_frame", fill: "energy_fill", nativeFrame: CGSize(width: 96, height: 8), nativeFill: CGSize(width: 92, height: 4), displayWidth: 124, outsideIsLeft: left)
        awakening = UIResourceBar(frame: "energy_frame", fill: "awaken_fill", nativeFrame: CGSize(width: 96, height: 8), nativeFill: CGSize(width: 92, height: 4), displayWidth: 100, outsideIsLeft: left)
        super.init()
        let name = Theme.label(fighter.data.name, size: 7, color: fighter.data.accentColor)
        name.horizontalAlignmentMode = left ? .left : .right
        name.position = CGPoint(x: left ? 49 : 431, y: 262); addChild(name)
        hp.position = CGPoint(x: left ? 132 : 348, y: 247); addChild(hp)
        energy.position = CGPoint(x: left ? 111 : 369, y: 233); addChild(energy)
        awakening.position = CGPoint(x: left ? 99 : 381, y: 222); addChild(awakening)
        // Tier I and II thresholds, measured from the inner (center-facing) end where the fill starts.
        let inner: CGFloat = 96
        for mark in [CGFloat(0.3), 0.6] {
            let tick = SKSpriteNode(color: .white, size: CGSize(width: 1, height: 6))
            tick.alpha = 0.7; tick.zPosition = 3
            tick.position.x = left ? inner / 2 - inner * mark : -inner / 2 + inner * mark
            awakening.addChild(tick)
        }
        tier.position = CGPoint(x: left ? 160 : 320, y: 222); addChild(tier)
        let portrait = SKNode(); portrait.position = CGPoint(x: left ? 24 : 456, y: 246)
        portrait.addChild(SKSpriteNode(color: Theme.navy, size: CGSize(width: 28, height: 28)))
        let crop = SKCropNode(); crop.maskNode = SKSpriteNode(color: .white, size: CGSize(width: 25, height: 25))
        let source = SpriteSheet.shared.frames(character: fighter.data, animation: "idle")[0]
        let face = SKTexture(rect: CGRect(x: 0.4, y: 0.5, width: 0.6, height: 0.5), in: source); face.filteringMode = .nearest
        crop.addChild(SKSpriteNode(texture: face, size: CGSize(width: 26, height: 29))); portrait.addChild(crop)
        let frame = UIAssets.shared.sprite("portrait_frame", size: CGSize(width: 32, height: 32)); frame.zPosition = 1
        portrait.addChild(frame); addChild(portrait)
    }
    required init?(coder: NSCoder) { fatalError() }

    func update(_ fighter: Fighter) {
        hp.setFraction(CGFloat(fighter.hp) / 100)
        energy.setFraction(CGFloat(fighter.energy) / 100)
        awakening.setFraction(fighter.awakeningFraction)
        tier.text = ["", "I", "II", "III"][fighter.awakeningTier]
    }
}

/// The centered PAUSED plate; scenes toggle `isHidden`.
final class PausePanel: SKNode {
    override init() {
        super.init()
        zPosition = 110; isHidden = true
        let backing = SKSpriteNode(color: Theme.navy.withAlphaComponent(0.83), size: CGSize(width: 204, height: 78))
        backing.position = CGPoint(x: 240, y: 147); addChild(backing)
        let plate = UIAssets.shared.sprite("btn_menu_normal", size: CGSize(width: 96, height: 28))
        plate.centerRect = CGRect(x: 0.24, y: 0.32, width: 0.52, height: 0.36); plate.size = CGSize(width: 160, height: 34)
        plate.position = CGPoint(x: 240, y: 157); addChild(plate)
        let label = Theme.label("PAUSED", size: 14, color: Theme.gold); label.position = plate.position; label.zPosition = 1; addChild(label)
        let hint = Theme.label("TAP PAUSE OR PRESS P TO RESUME", size: 6, color: Theme.ice)
        hint.position = CGPoint(x: 240, y: 126); addChild(hint)
    }
    required init?(coder: NSCoder) { fatalError() }
}
