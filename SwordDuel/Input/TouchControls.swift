import SpriteKit
import UIKit

enum Control: String, CaseIterable {
    case left = "◀", right = "▶", up = "▲", down = "▼"
    case attack = "ATK", skill1 = "SK1", skill2 = "SK2", skill3 = "SK3", ult = "ULT", block = "BLOCK", debug = "BOX", pause = "PAUSE"
}

final class TouchControls: SKNode {
    private var buttons: [Control: SKSpriteNode] = [:]
    private var cooldownSprites: [Control: SKSpriteNode] = [:]
    private var cooldownLabels: [Control: SKLabelNode] = [:]
    private var pressed: Set<Control> = []
    private var character: CharacterData?
    private var energy = 0
    /// SK3 is greyed out until awakening tier I.
    private var skill3Unlocked = false
    private var pulseTime: CGFloat = 0
    private var debugOn = false
    private let layout: [(Control, CGPoint, CGFloat)] = [
        (.left, CGPoint(x: 27, y: 36), 32), (.right, CGPoint(x: 91, y: 36), 32),
        (.up, CGPoint(x: 59, y: 68), 32), (.down, CGPoint(x: 59, y: 18), 32),
        (.attack, CGPoint(x: 440, y: 30), 40), (.skill1, CGPoint(x: 397, y: 70), 36),
        (.skill2, CGPoint(x: 355, y: 30), 36), (.skill3, CGPoint(x: 355, y: 74), 36), (.ult, CGPoint(x: 449, y: 86), 44),
        (.block, CGPoint(x: 309, y: 29), 36), (.pause, CGPoint(x: 225, y: 208), 24),
        (.debug, CGPoint(x: 255, y: 208), 24)
    ]
    override init() {
        super.init(); zPosition = 90
        for (control, point, diameter) in layout {
            let node = SKSpriteNode(); node.position = point; node.size = CGSize(width: diameter, height: diameter)
            node.alpha = 0.85; addChild(node); buttons[control] = node
            if [.attack, .skill1, .skill2, .skill3, .ult, .block].contains(control) {
                let label = Theme.label(control.rawValue, size: 5.5, color: .white)
                label.position.y = -diameter/2 - 4; label.zPosition = 4; node.addChild(label)
            }
            if control == .skill1 || control == .skill2 || control == .skill3 {
                let overlay = SKSpriteNode(); overlay.size = CGSize(width: 36, height: 36); overlay.zPosition = 2
                overlay.isHidden = true; node.addChild(overlay); cooldownSprites[control] = overlay
                let number = Theme.label("", size: 8, color: .white); number.zPosition = 3
                node.addChild(number); cooldownLabels[control] = number
            }
        }
        buttons[.skill3]?.alpha = 0.35
        refreshAll()
    }
    required init?(coder: NSCoder) { fatalError() }
    func isPressed(_ control: Control) -> Bool { pressed.contains(control) }
    func configure(character: CharacterData) { self.character = character; refreshAll() }
    func control(at point: CGPoint) -> Control? {
        // Stable ordering and circular hit regions avoid overlapping rectangle corners.
        layout.filter { _, center, diameter in
            let dx = point.x-center.x, dy = point.y-center.y
            return dx*dx+dy*dy <= pow(diameter/2 + 3, 2)
        }.min { a, b in
            hypot(point.x-a.1.x, point.y-a.1.y) / a.2 < hypot(point.x-b.1.x, point.y-b.1.y) / b.2
        }?.0
    }
    func setPressed(_ control: Control, _ value: Bool) {
        let wasPressed = pressed.contains(control)
        if value { pressed.insert(control) } else { pressed.remove(control) }
        if value && !wasPressed { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        buttons[control]?.setScale(value ? 0.92 : 1)
        buttons[control]?.alpha = control == .skill3 && !skill3Unlocked ? 0.35 : value ? 1 : 0.85
        refresh(control)
    }
    func clearPressed(except retained: Set<Control> = []) { for control in Control.allCases where !retained.contains(control) { setPressed(control, false) } }
    func setDebug(_ value: Bool) { debugOn = value; refresh(.debug) }
    /// Keep a fighter readable when the camera places them behind touch artwork.
    /// This changes opacity only; button locations and touch ownership stay stable.
    func revealFighters(_ fighters: [Fighter]) {
        let bodies = fighters.compactMap { fighter -> CGRect? in
            guard let world = fighter.parent else { return nil }
            let box = fighter.hurtbox.insetBy(dx: -8, dy: -4)
            let a = convert(CGPoint(x: box.minX, y: box.minY), from: world)
            let b = convert(CGPoint(x: box.maxX, y: box.maxY), from: world)
            return CGRect(x: min(a.x,b.x), y: min(a.y,b.y), width: abs(b.x-a.x), height: abs(b.y-a.y))
        }
        for (control, node) in buttons {
            let locked = control == .skill3 && !skill3Unlocked
            let obscures = bodies.contains { $0.intersects(node.frame) }
            node.alpha = locked ? 0.35 : pressed.contains(control) ? 1 : obscures ? 0.28 : 0.85
        }
    }
    func update(energy: Int, cooldowns: [String: CGFloat], awakeningTier: Int = 0, dt: CGFloat) {
        self.energy = energy; pulseTime += dt; refresh(.ult)
        if skill3Unlocked != (awakeningTier >= 1) {
            skill3Unlocked = awakeningTier >= 1
            buttons[.skill3]?.alpha = skill3Unlocked ? (pressed.contains(.skill3) ? 1 : 0.85) : 0.35
        }
        let frames = UIAssets.shared.frames("cooldown", frameSize: CGSize(width: 36, height: 36), count: 8)
        for (control, move) in [(Control.skill1, "skill1"), (.skill2, "skill2"), (.skill3, "skill3")] {
            let remaining = max(0, cooldowns[move] ?? 0)
            let total = max(0.001, character?.moves[move]?.cooldown ?? 1)
            let fraction = min(1, remaining / total)
            cooldownSprites[control]?.isHidden = remaining <= 0
            cooldownSprites[control]?.texture = frames[min(7, max(0, Int((1-fraction) * 7)))]
            cooldownLabels[control]?.text = remaining > 0 ? String(format: "%.1f", remaining) : ""
        }
    }
    private func refreshAll() { for control in Control.allCases { refresh(control) } }
    private func refresh(_ control: Control) {
        guard let node = buttons[control], let spec = layout.first(where: { $0.0 == control }) else { return }
        let id = character?.id ?? "frost"
        let native = CGSize(width: spec.2, height: spec.2)
        if control == .ult {
            if energy >= 100 {
                let frames = UIAssets.shared.frames("btn_\(id)_ult_ready", frameSize: native, count: 4)
                node.texture = frames[Int(pulseTime / 0.12) % 4]
            } else { node.texture = UIAssets.shared.texture("btn_\(id)_ult_locked", size: native) }
            return
        }
        let base: String
        switch control {
        case .left: base = "dpad_left"
        case .right: base = "dpad_right"
        case .up: base = "dpad_up"
        case .down: base = "dpad_down"
        case .attack: base = "btn_atk"
        case .block: base = "btn_block"
        case .skill1: base = "btn_\(id)_sk1"
        case .skill2: base = "btn_\(id)_sk2"
        case .skill3: base = "btn_\(id)_sk3"
        case .pause: base = "btn_pause"
        case .debug: base = debugOn ? "btn_debug_on" : "btn_debug_off"
        case .ult: return
        }
        let name = pressed.contains(control) && control != .debug ? base + "_pressed" : base
        node.texture = UIAssets.shared.texture(name, size: native)
    }
}
