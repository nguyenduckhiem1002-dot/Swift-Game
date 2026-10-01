import SpriteKit

final class AnimationController {
    private weak var sprite: SKSpriteNode?
    private let character: CharacterData
    private(set) var name = "idle"
    private(set) var frame = 0
    private var elapsed: CGFloat = 0
    /// The lowest frame index visited during the last update tick.
    private(set) var visitedLow = 0
    /// The highest frame index visited during the last update tick.
    private(set) var visitedHigh = 0
    init(sprite: SKSpriteNode, character: CharacterData) { self.sprite = sprite; self.character = character; set("idle") }
    func set(_ next: String) {
        guard next != name || sprite?.texture == nil else { return }
        name = next
        frame = 0
        elapsed = 0
        visitedLow = 0
        visitedHigh = 0
        if let sprite { SpriteSheet.shared.applyFrame(to: sprite, character: character, animation: next, index: 0) }
    }
    @discardableResult func update(_ dt: CGFloat) -> Bool {
        guard let spec = character.animations[name] else { return false }
        elapsed += dt
        let duration = 1 / spec.fps
        var advanced = false
        var finished = false
        visitedLow = frame
        visitedHigh = frame
        
        while elapsed >= duration {
            elapsed -= duration
            advanced = true
            if frame + 1 >= spec.frames {
                if spec.loop { frame = 0 } 
                else { frame = spec.frames - 1; finished = true; break }
            } else { 
                frame += 1 
            }
            visitedHigh = max(visitedHigh, frame)
        }
        
        // Clamp elapsed so it doesn't carry over huge residual into next animation
        if finished { elapsed = 0 }
        
        if advanced, let sprite = sprite { 
            SpriteSheet.shared.applyFrame(to: sprite, character: character, animation: name, index: frame) 
        }
        return finished
    }
}

