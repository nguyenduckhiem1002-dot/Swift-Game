import SpriteKit
import UIKit

enum Theme {
    static let navy = SKColor(red: 0.035, green: 0.065, blue: 0.15, alpha: 1)
    static let ice = SKColor(red: 0.46, green: 0.84, blue: 1, alpha: 1)
    static let gold = SKColor(red: 1, green: 0.79, blue: 0.38, alpha: 1)
    static let fire = SKColor(red: 1, green: 0.35, blue: 0.13, alpha: 1)
    static let awaken = SKColor(red: 0.8, green: 0.52, blue: 1, alpha: 1)
    static func label(_ text: String, size: CGFloat, color: SKColor = .white) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: "Menlo-Bold")
        node.text = text; node.fontSize = size; node.fontColor = color
        node.verticalAlignmentMode = .center
        return node
    }
    static func button(_ text: String, at point: CGPoint, width: CGFloat = 110, action: @escaping () -> Void) -> MenuButton {
        let button = MenuButton(text: text, size: CGSize(width: width, height: 28), action: action)
        button.position = point
        return button
    }
}

final class MenuButton: SKNode {
    let action: () -> Void
    private let panel: SKSpriteNode
    private let label: SKLabelNode
    private let buttonSize: CGSize
    private let difficulty: Bool
    private var pressed = false
    var isEnabled = true { didSet { if !isEnabled { setPressed(false) } else { refresh() } } }
    var isSelected = false { didSet { refresh() } }
    init(text: String, size: CGSize, difficulty: Bool = false, action: @escaping () -> Void) {
        self.action = action; buttonSize = size; self.difficulty = difficulty
        panel = SKSpriteNode(); label = Theme.label(text, size: difficulty ? 8 : 9, color: Theme.gold)
        super.init()
        panel.centerRect = CGRect(x: 0.24, y: 0.32, width: 0.52, height: 0.36)
        panel.size = size; addChild(panel); label.zPosition = 1; addChild(label); refresh()
    }
    required init?(coder: NSCoder) { fatalError() }
    func containsScenePoint(_ point: CGPoint, scene: SKScene) -> Bool {
        let local = convert(point, from: scene)
        return CGRect(x: -buttonSize.width/2, y: -buttonSize.height/2, width: buttonSize.width, height: buttonSize.height).contains(local)
    }
    func setPressed(_ value: Bool) {
        let next = value && isEnabled
        if next && !pressed { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        pressed = next; setScale(next ? 0.92 : 1); refresh()
    }
    private func refresh() {
        let name: String
        if !isEnabled { name = "btn_menu_disabled" }
        else if difficulty { name = isSelected || pressed ? "btn_difficulty_selected" : "btn_difficulty_unselected" }
        else { name = pressed ? "btn_menu_pressed" : "btn_menu_normal" }
        let native = difficulty && isEnabled ? CGSize(width: 64, height: 24) : CGSize(width: 96, height: 28)
        panel.texture = UIAssets.shared.texture(name, size: native)
        panel.size = buttonSize
        label.fontColor = !isEnabled ? .gray : isSelected ? .white : Theme.gold
        label.position.y = pressed ? -1 : 0
    }
}

class GameScene: SKScene {
    private var menuTouches: [ObjectIdentifier: MenuButton] = [:]
    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFit; backgroundColor = Theme.navy; isUserInteractionEnabled = true
    }
    required init?(coder: NSCoder) { fatalError() }
    func transition(to scene: SKScene) {
        menuTouches.values.forEach { $0.setPressed(false) }; menuTouches.removeAll()
        scene.scaleMode = .aspectFit
        view?.presentScene(scene, transition: .fade(withDuration: 0.25))
    }
    private func button(at point: CGPoint) -> MenuButton? {
        for hit in nodes(at: point) {
            var node: SKNode? = hit
            while let candidate = node {
                if let button = candidate as? MenuButton { return button }
                node = candidate.parent
            }
        }
        return nil
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let button = button(at: touch.location(in: self)), button.isEnabled,
               !menuTouches.values.contains(where: { $0 === button }) {
                menuTouches[ObjectIdentifier(touch)] = button; button.setPressed(true)
            }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let button = menuTouches[ObjectIdentifier(touch)] { button.setPressed(button.containsScenePoint(touch.location(in: self), scene: self)) }
        }
    }
    @discardableResult func endMenuTouches(_ touches: Set<UITouch>, cancelled: Bool = false) -> Bool {
        var handled = false
        for touch in touches {
            if let button = menuTouches.removeValue(forKey: ObjectIdentifier(touch)) {
                handled = true; button.setPressed(false)
                if !cancelled && button.isEnabled && button.containsScenePoint(touch.location(in: self), scene: self) { button.action() }
            }
        }
        return handled
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { endMenuTouches(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { endMenuTouches(touches, cancelled: true) }
}
