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
    /// Animation speed multiplier, e.g. slower attacks underwater.
    let animSpeed: CGFloat?
    let terrain: TerrainData?

    var gravityScale: CGFloat { gravity ?? 1 }
    var movementScale: CGFloat { moveScale ?? 1 }
}

/// Interactive arena layout. Coordinates are scene points; the floor is y = 42.
struct TerrainData: Codable {
    let platforms: [PlatformData]?
    let zones: [ZoneData]?
    let objects: [ObjectData]?
    let events: [EventData]?
}

/// One-way platform; `x` is its center and `y` its walkable top.
struct PlatformData: Codable {
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    /// stone, cloud (fire dissipates it), gold, chain, coral, astral.
    let kind: String
    let moveX: CGFloat?
    let moveY: CGFloat?
    let period: CGFloat?
    /// Timed platforms are solid for `onTime`, then gone for `offTime`.
    let onTime: CGFloat?
    let offTime: CGFloat?
    /// Collapses after two seconds of standing on it, returns after eight.
    let crumble: Bool?
}

/// Floor strip from `x` to `x + w`. lava, poison, rune, void, waterfall.
struct ZoneData: Codable {
    let kind: String
    let x: CGFloat
    let w: CGFloat
    let h: CGFloat?
}

/// pillar, bell, mushroom, tombstone, lantern, rod, tablet, statue.
struct ObjectData: Codable {
    let kind: String
    let x: CGFloat
    let y: CGFloat?
}

/// Timed map event: first fires at `start`, then every `interval` seconds, after a `telegraph` warning.
/// wind, geyser, sandstorm, statueBeam, roots, lightning, current, souls, darkness, debris.
struct EventData: Codable {
    let kind: String
    let start: CGFloat
    let interval: CGFloat
    let telegraph: CGFloat?
    let duration: CGFloat?
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
