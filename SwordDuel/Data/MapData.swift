import Foundation
import SpriteKit

/// One arena. Art is optional: `painting`, then `<id>_far/mid/near.png`, then a procedural scene in the palette below.
struct MapData: Codable {
    let id: String
    let name: String
    /// Short terrain description shown on the select screen.
    let summary: String?
    let sky: [CGFloat]
    let horizon: [CGFloat]
    let mountain: [CGFloat]
    let ground: [CGFloat]
    let accent: [CGFloat]
    let structure: [CGFloat]?
    /// Moon or sun color; omitted for maps without one.
    let orb: [CGFloat]?
    /// Procedural particles: embers, sand, spores, motes, rain, bubbles, souls, stars, petals.
    let ambient: String?
    let gravity: CGFloat?
    let moveScale: CGFloat?
    /// Illustrated full-screen background in Assets/Backgrounds, with an optional transparent mist overlay.
    let painting: String?
    let mist: String?

    var gravityScale: CGFloat { gravity ?? 1 }
    var movementScale: CGFloat { moveScale ?? 1 }
}

enum MapLibrary {
    static let all: [MapData] = {
        guard let url = Bundle.main.url(forResource: "Maps", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let maps = try? JSONDecoder().decode([MapData].self, from: data), !maps.isEmpty else {
            fatalError("Maps.json is missing or invalid")
        }
        return maps
    }()
    static func map(id: String) -> MapData { all.first { $0.id == id } ?? all[0] }
}

extension SKColor {
    convenience init(rgb: [CGFloat], alpha: CGFloat = 1) {
        let c = rgb.count == 3 ? rgb : [1, 1, 1]
        self.init(red: c[0], green: c[1], blue: c[2], alpha: alpha)
    }
}
