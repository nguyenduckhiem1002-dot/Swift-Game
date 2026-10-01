import Foundation
import CoreGraphics

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
}

struct CharacterData: Codable {
    let id: String
    let name: String
    let color: String
    let animations: [String: AnimationData]
    let moves: [String: MoveData]
    var tint: (red: CGFloat, green: CGFloat, blue: CGFloat) { color == "ice" ? (0.42, 0.82, 1) : (1, 0.36, 0.16) }
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
}

enum Difficulty: String { case easy = "Easy", normal = "Normal"
    var reaction: CGFloat { self == .easy ? 0.5 : 0.25 }
    var skillChance: CGFloat { self == .easy ? 0.15 : 0.4 }
}

struct MatchConfig {
    var playerIndex: Int
    var difficulty: Difficulty
}
