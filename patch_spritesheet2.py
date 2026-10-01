import re

with open('/Users/duck/Dev/Game/SwordDuel/Core/SpriteSheet.swift', 'r') as f:
    content = f.read()

new_atlasFrames = """    private func atlasFrames(_ names: [String], atlas: AtlasData, characterID: String) -> (textures: [SKTexture], layouts: [FrameLayout])? {
        var textures: [SKTexture] = []
        var frameLayouts: [FrameLayout] = []
        for name in names {
            guard let frame = atlas.frames[name], frame.pivot.count == 2, frame.scale > 0 else { return nil }
            let rect = CGRect(x: frame.rect.x, y: frame.rect.y, width: frame.rect.w, height: frame.rect.h)
            
            // Try loading individual frame first (padded to 512x512 with pivot at 256,400)
            if let frameUrl = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Assets/Characters/\\(characterID)/frames"),
               let image = UIImage(contentsOfFile: frameUrl.path)?.cgImage {
                textures.append(nearest(SKTexture(cgImage: image)))
                frameLayouts.append(FrameLayout(size: CGSize(width: 512 * frame.scale, height: 512 * frame.scale),
                                                anchor: CGPoint(x: 0.5, y: 1.0 - (400.0 / 512.0))))
            } else {
                // Fallback to atlas
                let imageKey = "\\(characterID)/\\(frame.image)"
                let image: CGImage
                if let cached = sourceImages[imageKey] { image = cached }
                else {
                    guard let url = Bundle.main.url(forResource: frame.image, withExtension: "png", subdirectory: "Assets/Characters/\\(characterID)"),
                          let loaded = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
                    sourceImages[imageKey] = loaded
                    image = loaded
                }
                guard CGRect(x: 0, y: 0, width: image.width, height: image.height).contains(rect),
                      let crop = image.cropping(to: rect) else { return nil }
                textures.append(nearest(SKTexture(cgImage: crop)))
                frameLayouts.append(FrameLayout(size: CGSize(width: rect.width * frame.scale, height: rect.height * frame.scale),
                                                anchor: CGPoint(x: frame.pivot[0] / rect.width, y: 1 - frame.pivot[1] / rect.height)))
            }
        }
        return textures.isEmpty ? nil : (textures, frameLayouts)
    }"""

# Use regex to replace the old method
content = re.sub(
    r'private func atlasFrames.*?return textures\.isEmpty \? nil : \(textures, frameLayouts\)\n    \}',
    new_atlasFrames,
    content,
    flags=re.DOTALL
)

with open('/Users/duck/Dev/Game/SwordDuel/Core/SpriteSheet.swift', 'w') as f:
    f.write(content)

