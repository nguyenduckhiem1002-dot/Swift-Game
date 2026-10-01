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
