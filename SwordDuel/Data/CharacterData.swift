import Foundation
import CoreGraphics
import SpriteKit

struct BoxData: Codable {
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat
    func rect(origin: CGPoint, facing: CGFloat) -> CGRect {
        let left = facing > 0 ? origin.x + x : origin.x - x - w
        return CGRect(x: left, y: origin.y + y, width: w, height: h)
    }
}

struct AnimationData: Codable {
    let frames: Int
    let fps: CGFloat
    let loop: Bool
}

struct MoveData: Codable {
    let damage: Int
    let activeStart: Int
    let activeEnd: Int
    let hitbox: BoxData
    let knockback: CGFloat
    let energyCost: Int
    let cooldown: CGFloat
    /// skill1 only: projectiles fired in a vertical fan (default 1). 0 makes skill1 a melee hitbox.
    let projectiles: Int?
    /// Forward movement while the move starts. skill2 defaults to a 250 pt/s, 0.32s invulnerable dash.
    let dashSpeed: CGFloat?
    let dashTime: CGFloat?
    let invulnerable: Bool?
    /// Reappear beside the target when the move becomes active.
    let teleport: Bool?
}

struct CharacterData: Codable {
    let id: String
    let name: String
    /// Element/VFX key: `projectile_<color>.png` and `ult_<color>.png`.
    let color: String
    let role: String?
    /// RGB accent for HUD names, placeholders, generated VFX and fallback buttons.
    let accent: [CGFloat]?
    /// Square strip frame size in pixels; defaults to 64.
    let frameSize: CGFloat?
    let walkSpeed: CGFloat?
    let jumpVelocity: CGFloat?
    let animations: [String: AnimationData]
    let moves: [String: MoveData]
    var tint: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        if let accent, accent.count == 3 { return (accent[0], accent[1], accent[2]) }
        return color == "ice" ? (0.42, 0.82, 1) : (1, 0.36, 0.16)
    }
    var accentColor: SKColor { SKColor(red: tint.red, green: tint.green, blue: tint.blue, alpha: 1) }
    var spriteSize: CGFloat { frameSize ?? 64 }
}

enum CharacterLibrary {
    static let all: [CharacterData] = {
        guard let url = Bundle.main.url(forResource: "Characters", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let characters = try? JSONDecoder().decode([CharacterData].self, from: data), characters.count >= 2 else {
            fatalError("Characters.json is missing or invalid")
        }
        return characters
    }()
    static func index(of id: String) -> Int? { all.firstIndex { $0.id == id } }
}

enum Difficulty: String { case easy = "Easy", normal = "Normal"
    var reaction: CGFloat { self == .easy ? 0.5 : 0.25 }
    var skillChance: CGFloat { self == .easy ? 0.15 : 0.4 }
}

struct MatchConfig {
    var playerIndex: Int
    var opponentIndex: Int
    var difficulty: Difficulty
    var mapID: String
}
