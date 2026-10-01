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
