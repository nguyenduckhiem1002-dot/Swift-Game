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
    /// Arena width in points; wider than 480 enables the following, zooming camera.
    var width: CGFloat?
    var tiledMap: String?
    var terrain: TerrainData?

    var gravityScale: CGFloat { gravity ?? 1 }
    var movementScale: CGFloat { moveScale ?? 1 }
    var arenaWidth: CGFloat { max(480, width ?? 480) }
    var isWide: Bool { arenaWidth > 480 }
    /// Fighters start 236 points apart around the arena center.
    var spawnPoints: (left: CGFloat, right: CGFloat) { (arenaWidth / 2 - 118, arenaWidth / 2 + 118) }
}

/// Camera framing for wide arenas: follow the fighters' midpoint and zoom out from 1.0x to 0.75x as they separate.
enum CameraFraming {
    static let minZoom: CGFloat = 0.75
    /// Fighters may not separate beyond what the widest zoom can show.
    static let maxGap: CGFloat = 480 / minZoom - 70
    static func target(width: CGFloat, leftX: CGFloat, rightX: CGFloat) -> (x: CGFloat, zoom: CGFloat) {
        guard width > 480 else { return (240, 1) }
        let zoom = min(1, max(minZoom, 480 / (abs(rightX - leftX) + 170)))
        return (clampedX((leftX + rightX) / 2, width: width, zoom: zoom), zoom)
    }
    /// Keeps the visible span inside the arena.
    static func clampedX(_ x: CGFloat, width: CGFloat, zoom: CGFloat) -> CGFloat {
        let half = 240 / zoom
        return width <= half * 2 ? width / 2 : min(width - half, max(half, x))
    }
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
import Foundation
import SpriteKit

struct TiledMap: Codable {
    let width: Int
    let height: Int
    let tilewidth: Int
    let tileheight: Int
    let layers: [TiledLayer]
    let tilesets: [TiledTilesetRef]
}

struct TiledLayer: Codable {
    let type: String
    let name: String
    let visible: Bool?
    let opacity: CGFloat?
    let data: [Int]?
    let objects: [TiledObject]?
    let width: Int?
    let height: Int?
}

struct TiledObject: Codable {
    let id: Int
    let name: String
    let type: String?
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let properties: [TiledProperty]?
}

struct TiledProperty: Codable {
    let name: String
    let type: String
    let value: AnyValue
    
    enum AnyValue: Codable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let v = try? container.decode(String.self) { self = .string(v) }
            else if let v = try? container.decode(Int.self) { self = .int(v) }
            else if let v = try? container.decode(Double.self) { self = .double(v) }
            else if let v = try? container.decode(Bool.self) { self = .bool(v) }
            else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown value type") }
        }
        func encode(to encoder: Encoder) throws {}
    }
}

struct TiledTilesetRef: Codable {
    let firstgid: Int
    let source: String?
    let name: String?
    let margin: Int?
    let spacing: Int?
    let tilewidth: Int?
    let tileheight: Int?
}
import Foundation
import SpriteKit

struct TiledLoader {
    static func parseTileset(_ jsonName: String) -> (texture: SKTexture, tileWidth: Int, tileHeight: Int, columns: Int)? {
        guard let url = Bundle.main.url(forResource: jsonName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let image = json["image"] as? String,
              let tileWidth = json["tilewidth"] as? Int,
              let tileHeight = json["tileheight"] as? Int,
              let columns = json["columns"] as? Int else {
            return nil
        }
        let textureName = (image as NSString).lastPathComponent
        return (UIAssets.shared.texture(textureName, size: .zero), tileWidth, tileHeight, columns)
    }
}
import Foundation
import SpriteKit

class TiledArenaBuilder {
    static func build(map: TiledMap, tilesetTexture: SKTexture, tileW: Int, tileH: Int, cols: Int) -> (node: SKNode, terrain: TerrainData) {
        let node = SKNode()
        var platforms: [PlatformData] = []
        var zones: [ZoneData] = []
        var objects: [ObjectData] = []
        
        let mapWidth = CGFloat(map.width * map.tilewidth)
        let mapHeight = CGFloat(map.height * map.tileheight)
        
        for layer in map.layers {
            if layer.type == "tilelayer", let data = layer.data {
                let layerNode = SKNode()
                let width = layer.width ?? map.width
                
                // Assuming floor Y = 42 for now, or we can align map bottom to Y = 0
                // Let's align map bottom to Y = 0 (or 42)
                for (index, gid) in data.enumerated() {
                    if gid == 0 { continue }
                    let localGid = gid - (map.tilesets.first?.firstgid ?? 1)
                    if localGid < 0 { continue }
                    
                    let col = index % width
                    let row = index / width
                    let x = CGFloat(col * map.tilewidth) + CGFloat(map.tilewidth) / 2
                    let y = mapHeight - CGFloat(row * map.tileheight) - CGFloat(map.tileheight) / 2
                    
                    let tx = localGid % cols
                    let ty = localGid / cols
                    
                    let rect = CGRect(
                        x: CGFloat(tx) * CGFloat(tileW) / tilesetTexture.size().width,
                        y: 1.0 - CGFloat(ty + 1) * CGFloat(tileH) / tilesetTexture.size().height,
                        width: CGFloat(tileW) / tilesetTexture.size().width,
                        height: CGFloat(tileH) / tilesetTexture.size().height
                    )
                    
                    let sprite = SKSpriteNode(texture: SKTexture(rect: rect, in: tilesetTexture))
                    sprite.position = CGPoint(x: x, y: y)
                    sprite.size = CGSize(width: map.tilewidth, height: map.tileheight)
                    layerNode.addChild(sprite)
                }
                node.addChild(layerNode)
            } else if layer.type == "objectgroup", let objs = layer.objects {
                for obj in objs {
                    // Coordinates in Tiled for objects are bottom-left for some types, top-left for others. 
                    // Usually origin is top-left, but Y goes down.
                    let x = obj.x + obj.width / 2
                    let y = mapHeight - obj.y + obj.height / 2
                    
                    if let type = obj.type {
                        if type == "platform" {
                            platforms.append(PlatformData(x: x, y: y, w: obj.width, kind: "stone", moveX: nil, moveY: nil, period: nil, onTime: nil, offTime: nil, crumble: false))
                        } else if type == "zone" {
                            let kind = obj.properties?.first(where: { $0.name == "kind" })?.stringValue ?? "lava"
                            zones.append(ZoneData(kind: kind, x: obj.x, w: obj.width, h: obj.height))
                        } else {
                            objects.append(ObjectData(kind: type, x: x, y: y))
                        }
                    } else {
                        objects.append(ObjectData(kind: obj.name, x: x, y: y))
                    }
                }
            }
        }
        
        return (node, TerrainData(platforms: platforms, zones: zones, objects: objects, events: nil))
    }
}

extension TiledProperty {
    var stringValue: String? {
        if case .string(let v) = value { return v }
        return nil
    }
}
