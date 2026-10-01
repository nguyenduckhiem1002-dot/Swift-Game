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
