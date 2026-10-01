import SpriteKit

final class AnimationController {
    private weak var sprite: SKSpriteNode?
    private let character: CharacterData
    private(set) var name = "idle"
    private(set) var frame = 0
    private var elapsed: CGFloat = 0
    init(sprite: SKSpriteNode, character: CharacterData) { self.sprite = sprite; self.character = character; set("idle") }
    func set(_ next: String) {
        guard next != name || sprite?.texture == nil else { return }
        name = next
        frame = 0
        elapsed = 0
        if let sprite { SpriteSheet.shared.applyFrame(to: sprite, character: character, animation: next, index: 0) }
    }
    @discardableResult func update(_ dt: CGFloat) -> Bool {
        guard let spec = character.animations[name] else { return false }
        elapsed += dt
        let duration = 1 / spec.fps
        guard elapsed >= duration else { return false }
        elapsed -= duration
        if frame + 1 >= spec.frames {
            if spec.loop { frame = 0 } else { frame = spec.frames - 1; return true }
        } else { frame += 1 }
        if let sprite { SpriteSheet.shared.applyFrame(to: sprite, character: character, animation: name, index: frame) }
        return false
    }
}
