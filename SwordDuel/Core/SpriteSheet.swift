import SpriteKit
import UIKit

final class SpriteSheet {
    static let shared = SpriteSheet()
    private var cache: [String: [SKTexture]] = [:]
    private var layouts: [String: [FrameLayout]] = [:]
    private var atlases: [String: AtlasData] = [:]
    private var sourceImages: [String: CGImage] = [:]
    private var placeholderKeys: Set<String> = []
    /// Until dedicated art exists, these animations reuse a drawn one with the same frame count.
    private static let aliases = ["skill3": "win"]

    private struct FrameLayout {
        let size: CGSize
        let anchor: CGPoint
    }
    private struct AtlasData: Decodable {
        let frames: [String: AtlasFrame]
        let animations: [String: [String]]
        let effects: [String: [String]]
    }
    private struct AtlasFrame: Decodable {
        let image: String
        let rect: BoxData
        let pivot: [CGFloat]
        let scale: CGFloat
    }
    private init() {}

    func frames(character: CharacterData, animation: String) -> [SKTexture] {
        let key = "\(character.id)_\(animation)"
        if let cached = cache[key] { return cached }
        let count = character.animations[animation]?.frames ?? 1
        let path = "Assets/Characters/\(character.id)/\(key)"
        if let strip = loadStrip(path: path, count: count, frameSize: CGSize(width: character.spriteSize, height: character.spriteSize)) {
            cache[key] = strip
            return strip
        }
        if let atlas = atlas(for: character.id), let names = atlas.animations[animation], names.count == count,
           let imported = atlasFrames(names, atlas: atlas, characterID: character.id) {
            cache[key] = imported.textures
            layouts[key] = imported.layouts
            return imported.textures
        }
        if let alias = Self.aliases[animation], character.animations[alias]?.frames == count {
            let borrowed = frames(character: character, animation: alias)
            let aliasKey = "\(character.id)_\(alias)"
            if !placeholderKeys.contains(aliasKey) {
                cache[key] = borrowed
                layouts[key] = layouts[aliasKey]
                return borrowed
            }
        }
        let fallback = (0..<count).map { placeholder(character: character, animation: animation, frame: $0) }
        cache[key] = fallback
        placeholderKeys.insert(key)
        return fallback
    }

    // A pose keeps its source resolution and a shared foot pivot. Broad slash effects can
    // extend beyond the 64-point body without shrinking the fighter on attack frames.
    func applyFrame(to sprite: SKSpriteNode, character: CharacterData, animation: String, index: Int) {
        let textures = frames(character: character, animation: animation)
        let safeIndex = min(max(0, index), textures.count - 1)
        sprite.texture = textures[safeIndex]
        if let frameLayouts = layouts["\(character.id)_\(animation)"] {
            let layout = frameLayouts[safeIndex]
            sprite.size = layout.size
            sprite.anchorPoint = layout.anchor
        } else {
            sprite.size = CGSize(width: character.spriteSize, height: character.spriteSize)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        }
    }

    private func atlas(for characterID: String) -> AtlasData? {
        if let existing = atlases[characterID] { return existing }
        guard let url = Bundle.main.url(forResource: "\(characterID)_atlas", withExtension: "json", subdirectory: "Assets/Characters/\(characterID)"),
              let bytes = try? Data(contentsOf: url), let atlas = try? JSONDecoder().decode(AtlasData.self, from: bytes) else { return nil }
        atlases[characterID] = atlas
        return atlas
    }

    private func atlasFrames(_ names: [String], atlas: AtlasData, characterID: String) -> (textures: [SKTexture], layouts: [FrameLayout])? {
        var textures: [SKTexture] = []
        var frameLayouts: [FrameLayout] = []
        for name in names {
            guard let frame = atlas.frames[name], frame.pivot.count == 2, frame.scale > 0 else { return nil }
            let imageKey = "\(characterID)/\(frame.image)"
            let image: CGImage
            if let cached = sourceImages[imageKey] { image = cached }
            else {
                guard let url = Bundle.main.url(forResource: frame.image, withExtension: "png", subdirectory: "Assets/Characters/\(characterID)"),
                      let loaded = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
                sourceImages[imageKey] = loaded
                image = loaded
            }
            let rect = CGRect(x: frame.rect.x, y: frame.rect.y, width: frame.rect.w, height: frame.rect.h)
            guard CGRect(x: 0, y: 0, width: image.width, height: image.height).contains(rect),
                  let crop = image.cropping(to: rect) else { return nil }
            textures.append(nearest(SKTexture(cgImage: crop)))
            frameLayouts.append(FrameLayout(size: CGSize(width: rect.width * frame.scale, height: rect.height * frame.scale),
                                            anchor: CGPoint(x: frame.pivot[0] / rect.width, y: 1 - frame.pivot[1] / rect.height)))
        }
        return textures.isEmpty ? nil : (textures, frameLayouts)
    }

    /// A character-specific strip (`<id>_<kind>.png`) wins over the shared element strip (`<kind>_<color>.png`).
    func effectName(_ kind: String, character: CharacterData) -> String {
        let own = "\(character.id)_\(kind)"
        return Bundle.main.url(forResource: own, withExtension: "png", subdirectory: "Assets/VFX") != nil ? own : "\(kind)_\(character.color)"
    }

    func effect(named name: String, count: Int, size: Int = 96, color: SKColor) -> [SKTexture] {
        let key = "vfx_\(name)"
        if let cached = cache[key] { return cached }
        if let strip = loadStrip(path: "Assets/VFX/\(name)", count: count, frameSize: CGSize(width: size, height: size)) {
            cache[key] = strip
            return strip
        }
        if let atlas = atlas(for: "frost"), let names = atlas.effects[name], names.count == count,
           let imported = atlasFrames(names, atlas: atlas, characterID: "frost") {
            cache[key] = imported.textures
            return imported.textures
        }
        let frames = (0..<count).map { index in
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
            let image = renderer.image { ctx in
                let c = ctx.cgContext
                c.setFillColor(color.withAlphaComponent(0.65).cgColor)
                let radius = CGFloat(12 + index % 3 * 3)
                c.fill(CGRect(x: CGFloat(size)/2-radius, y: CGFloat(size)/2-radius/2, width: radius*2, height: radius))
                c.setStrokeColor(UIColor.white.cgColor)
                c.setLineWidth(2)
                c.stroke(CGRect(x: CGFloat(size)/2-radius, y: CGFloat(size)/2-radius/2, width: radius*2, height: radius))
            }
            return nearest(SKTexture(image: image))
        }
        cache[key] = frames
        return frames
    }

    private func loadStrip(path: String, count: Int, frameSize: CGSize) -> [SKTexture]? {
        let parts = path.split(separator: "/").map(String.init)
        guard let filename = parts.last else { return nil }
        let folder = parts.dropLast().joined(separator: "/")
        guard let url = Bundle.main.url(forResource: filename, withExtension: "png", subdirectory: folder),
              let image = UIImage(contentsOfFile: url.path)?.cgImage,
              image.width >= Int(frameSize.width) * count, image.height >= Int(frameSize.height) else { return nil }
        return (0..<count).compactMap { index in
            guard let cut = image.cropping(to: CGRect(x: index * Int(frameSize.width), y: 0, width: Int(frameSize.width), height: Int(frameSize.height))) else { return nil }
            return nearest(SKTexture(cgImage: cut))
        }
    }
    private func nearest(_ texture: SKTexture) -> SKTexture { texture.filteringMode = .nearest; return texture }
    private func placeholder(character: CharacterData, animation: String, frame: Int) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format)
        let image = renderer.image { context in
            let c = context.cgContext
            c.interpolationQuality = .none
            let tint = character.tint
            c.setFillColor(UIColor(red: tint.red, green: tint.green, blue: tint.blue, alpha: 1).cgColor)
            c.fill(CGRect(x: 23, y: 9 + frame % 2, width: 18, height: 38))
            c.fill(CGRect(x: 18, y: 16, width: 28, height: 9))
            c.setFillColor(UIColor(white: 0.08, alpha: 1).cgColor)
            c.fill(CGRect(x: 25, y: 4, width: 14, height: 13))
            c.setFillColor(UIColor.white.cgColor)
            c.fill(CGRect(x: 26, y: 48, width: 5, height: 9))
            c.fill(CGRect(x: 34, y: 48, width: 5, height: 9))
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 6, weight: .bold), .foregroundColor: UIColor.white]
            ("\(animation.prefix(8)) \(frame+1)" as NSString).draw(at: CGPoint(x: 2, y: 57), withAttributes: attrs)
        }
        return nearest(SKTexture(image: image))
    }
}
