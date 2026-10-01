import Foundation
import CoreGraphics

/// A monster type. `behavior` selects the AI in `Monster`: melee, ranged, slam, flyer, hopper or boss.
struct MonsterData: Codable {
    let id: String
    let name: String
    let behavior: String
    let hp: Int
    let speed: CGFloat
    let damage: Int
    /// Distance at which the monster starts its attack (preferred distance for ranged).
    let range: CGFloat
    let cooldown: CGFloat
    /// Wind-up before the attack lands; always visible as a flash or ground marker.
    let telegraph: CGFloat
    /// Body width and height in points.
    let size: [CGFloat]
    let color: [CGFloat]
    /// Hits do not interrupt or push armored monsters.
    let armor: Bool?
    /// Awakening gained on kill; defaults to 5 (elites always give 20, bosses 50).
    let reward: CGFloat?
    /// Boss attack rotation: charge, fan, slam.
    let attacks: [String]?
    /// Boss minions summoned at 66% and 33% HP.
    let summon: String?
    /// Optional horizontal strip `Assets/Monsters/<id>.png` with this many frames.
    let frames: Int?
    var width: CGFloat { size.count == 2 ? size[0] : 28 }
    var height: CGFloat { size.count == 2 ? size[1] : 28 }
}

struct SpawnData: Codable {
    let type: String
    let count: Int?
    let elite: Bool?
}

/// `x`/`y` are relative to the zone's left edge and the floor.
struct PickupData: Codable {
    /// peach (+25 HP), stone (Linh Văn Thạch, +10 awakening), elixir (+40 energy).
    let kind: String
    let x: CGFloat
    let y: CGFloat?
}

struct StageZoneData: Codable {
    let width: CGFloat
    let title: String?
    /// safe, combat or boss. Waves spawn in order; the exit opens when the last wave is cleared.
    let kind: String
    let waves: [[SpawnData]]?
    let pickups: [PickupData]?
}

struct StageData: Codable {
    let id: String
    let name: String
    let summary: String?
    /// Visual theme, physics and ambient effects come from this map.
    let map: String
    let zones: [StageZoneData]
    /// Absolute arena coordinates across the whole stage.
    let terrain: TerrainData?
    var width: CGFloat { zones.reduce(0) { $0 + $1.width } }
    /// Left edge of each zone in arena coordinates.
    var zoneStarts: [CGFloat] {
        var starts: [CGFloat] = []
        var x: CGFloat = 0
        for zone in zones { starts.append(x); x += zone.width }
        return starts
    }
    /// The base map with this stage's width and terrain.
    var arenaMap: MapData {
        var map = MapLibrary.map(id: self.map)
        map.width = width
        map.terrain = terrain
        return map
    }
}

enum MonsterLibrary {
    static let all: [MonsterData] = load("Monsters")
    static func monster(_ id: String) -> MonsterData? { all.first { $0.id == id } }
}

enum StageLibrary {
    static let all: [StageData] = load("Stages")
}

private func load<T: Decodable>(_ name: String) -> [T] {
    guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let items = try? JSONDecoder().decode([T].self, from: data), !items.isEmpty else {
        fatalError("\(name).json is missing or invalid")
    }
    return items
}
