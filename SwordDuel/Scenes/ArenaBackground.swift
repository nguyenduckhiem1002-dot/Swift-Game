import SpriteKit
import UIKit

final class ArenaBackground: SKNode {
    let map: MapData
    private let clouds = SKNode()
    private var cloudX: CGFloat = 0
    private let nearArt = SKNode()
    private var nearX: CGFloat = 0
    private var usesIllustration = false
    private let particles = SKNode()
    private var particleVelocity = CGVector.zero
    private var ambientClock: CGFloat = 0
    private let flash = SKSpriteNode(color: .white, size: CGSize(width: 480, height: 270))
    /// Parallax layers: peaks scroll at 0.5, clouds at 0.3 and near art at 1.2 of the camera; the sky stays put.
    private let peaks = SKNode()
    private let midArt = SKNode()
    private var scroll: CGFloat = 0
    /// Wide arenas draw their floor here; the fight scene adds it to the camera's world so it scrolls and zooms 1:1.
    private(set) var worldGround: SKNode?

    init(map: MapData = MapLibrary.all[0], groundInWorld: Bool = false) {
        self.map = map
        super.init()
        if let name = map.painting, let painting = backgroundTexture(name) {
            buildIllustratedArena(painting)
            return
        }
        // Map art: <id>_far.png replaces the sky, <id>_mid.png the scenery and ground, <id>_near.png tiles in front.
        // The illustrated arena also accepts the legacy far/mid/near names when its painting is removed.
        let far = layerTexture("far"), mid = layerTexture("mid"), near = layerTexture("near")
        if let far {
            let sprite = SKSpriteNode(texture: far, size: CGSize(width: 480, height: 270))
            sprite.position = CGPoint(x: 240, y: 135); sprite.zPosition = 1.5; addChild(sprite)
        } else {
            buildProceduralSky()
        }
        midArt.zPosition = 3.5; addChild(midArt)
        if let mid {
            for index in 0..<2 {
                let sprite = SKSpriteNode(texture: mid, size: CGSize(width: 480, height: 270))
                sprite.position = CGPoint(x: 240 + CGFloat(index) * 480, y: 135); midArt.addChild(sprite)
            }
        }
        clouds.zPosition = 4; addChild(clouds)
        for i in 0..<12 {
            let cloud = SKShapeNode(ellipseOf: CGSize(width: 78, height: 13))
            cloud.position = CGPoint(x: CGFloat(i * 62 - 50), y: CGFloat(82 + i % 3 * 13))
            cloud.fillColor = SKColor(rgb: map.horizon).blended(with: .white, amount: 0.45).withAlphaComponent(0.19)
            cloud.strokeColor = .clear; clouds.addChild(cloud)
        }
        nearArt.zPosition = 4.5; addChild(nearArt)
        if let near {
            for index in 0..<2 {
                let sprite = SKSpriteNode(texture: near, size: CGSize(width: 480, height: 270))
                sprite.position = CGPoint(x: 240 + CGFloat(index) * 480, y: 135)
                nearArt.addChild(sprite)
            }
        }
        if groundInWorld { worldGround = makeWorldGround() }
        else if mid == nil { buildProceduralGround() }
        buildAmbient()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildProceduralSky() {
        let sky = SKSpriteNode(color: SKColor(rgb: map.sky), size: CGSize(width: 480, height: 270))
        sky.position = CGPoint(x: 240, y: 135); addChild(sky)
        // Ordered horizon bands instead of a smooth gradient, matching the pixel-art map spec.
        for band in 0..<4 {
            let amount = CGFloat(band + 1) / 5
            let strip = SKSpriteNode(color: SKColor(rgb: map.sky).blended(with: SKColor(rgb: map.horizon), amount: amount), size: CGSize(width: 480, height: 18))
            strip.anchorPoint = .zero; strip.position = CGPoint(x: 0, y: CGFloat(150 - band * 18)); strip.zPosition = 0.5; addChild(strip)
        }
        let skyColor = SKColor(rgb: map.sky)
        if skyColor.luminance < 0.2 {
            for i in 0..<75 {
                let x = CGFloat((i * 73 + 17) % 480)
                let y = CGFloat(98 + (i * 47) % 170)
                let star = SKSpriteNode(color: .white, size: CGSize(width: i % 7 == 0 ? 2 : 1, height: i % 7 == 0 ? 2 : 1))
                star.position = CGPoint(x: x, y: y); star.zPosition = 1; addChild(star)
            }
        }
        if let orbColor = map.orb {
            let orb = SKShapeNode(circleOfRadius: 47)
            orb.position = CGPoint(x: 405, y: 210)
            orb.fillColor = SKColor(rgb: orbColor)
            orb.strokeColor = SKColor(rgb: map.accent); orb.lineWidth = 2; orb.zPosition = 1; addChild(orb)
        }
        let structure = SKColor(rgb: map.structure ?? [1, 0.79, 0.38], alpha: 0.75)
        // The peak pattern repeats every three peaks (288 points), so the layer wraps seamlessly while scrolling.
        peaks.zPosition = 2; addChild(peaks)
        for i in 0..<10 {
            let x = CGFloat(i * 96 - 25)
            let peak = SKShapeNode(path: trianglePath(x: x, baseY: 56, width: 135, height: CGFloat(95 + i % 3 * 15)))
            peak.fillColor = SKColor(rgb: map.mountain)
            peak.strokeColor = SKColor(rgb: map.accent, alpha: 0.35); peak.lineWidth = 1; peaks.addChild(peak)
            let pagoda = SKSpriteNode(color: structure, size: CGSize(width: 13, height: 15))
            pagoda.position = CGPoint(x: x + 67, y: CGFloat(151 + i % 3 * 15)); pagoda.zPosition = 1; peaks.addChild(pagoda)
        }
    }

    // The fighters' physics floor is y = 42; map art must place its walkable ledge there.
    private func buildProceduralGround() {
        let ground = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 480, height: 42))
        ground.fillColor = SKColor(rgb: map.ground)
        ground.strokeColor = SKColor(rgb: map.accent); ground.lineWidth = 2; ground.zPosition = 5; addChild(ground)
        for i in 0..<32 {
            let tile = SKSpriteNode(color: SKColor(rgb: map.accent, alpha: 0.16), size: CGSize(width: 13, height: 1))
            tile.position = CGPoint(x: CGFloat(i * 16 + 4), y: CGFloat(9 + (i % 3) * 8))
            tile.zPosition = 6; addChild(tile)
        }
    }

    /// The walkable floor across the whole arena, extended below y = 0 so zooming out never shows a gap.
    /// An optional `<mapId>_ground.png` (any width, 42 high) tiles along it.
    private func makeWorldGround() -> SKNode {
        let node = SKNode()
        let width = map.arenaWidth
        let ground = SKShapeNode(rect: CGRect(x: -80, y: -90, width: width + 160, height: 132))
        ground.fillColor = SKColor(rgb: map.ground)
        ground.strokeColor = SKColor(rgb: map.accent); ground.lineWidth = 2; node.addChild(ground)
        if let tile = backgroundTexture("\(map.id)_ground") {
            let size = CGSize(width: tile.size().width * 42 / max(1, tile.size().height), height: 42)
            var x: CGFloat = -80
            while x < width + 80 {
                let sprite = SKSpriteNode(texture: tile, size: size)
                sprite.anchorPoint = .zero; sprite.position = CGPoint(x: x, y: 0); sprite.zPosition = 1; node.addChild(sprite)
                x += max(16, size.width)
            }
        } else {
            for i in 0..<Int((width + 160) / 16) {
                let tile = SKSpriteNode(color: SKColor(rgb: map.accent, alpha: 0.16), size: CGSize(width: 13, height: 1))
                tile.position = CGPoint(x: CGFloat(i * 16 - 76), y: CGFloat(9 + (i % 3) * 8))
                tile.zPosition = 1; node.addChild(tile)
            }
        }
        return node
    }

    /// Called by the fight scene's camera; `x` is the arena x at the screen center.
    func setCamera(x: CGFloat) {
        scroll = x - 240
        layoutParallax()
    }
    private func layoutParallax() {
        peaks.position.x = wrapped(-scroll * 0.5, period: 288)
        midArt.position.x = wrapped(-scroll * 0.5, period: 480)
        clouds.position.x = wrapped(cloudX - scroll * 0.3, period: usesIllustration ? 480 : 62)
        nearArt.position.x = wrapped(nearX - scroll * 1.2, period: 480)
    }
    /// Maps any offset into (-period, 0] so repeating layers always cover the screen.
    private func wrapped(_ value: CGFloat, period: CGFloat) -> CGFloat {
        let remainder = value.truncatingRemainder(dividingBy: period)
        return remainder > 0 ? remainder - period : remainder
    }

    private func buildAmbient() {
        guard let ambient = map.ambient else { return }
        let size: CGSize
        switch ambient {
        case "embers": particleVelocity = CGVector(dx: -4, dy: 16); size = CGSize(width: 2, height: 2)
        case "sand": particleVelocity = CGVector(dx: -70, dy: -6); size = CGSize(width: 3, height: 1)
        case "spores", "motes": particleVelocity = CGVector(dx: 3, dy: 7); size = CGSize(width: 2, height: 2)
        case "rain": particleVelocity = CGVector(dx: -30, dy: -190); size = CGSize(width: 1, height: 5)
        case "bubbles": particleVelocity = CGVector(dx: 0, dy: 20); size = CGSize(width: 3, height: 3)
        case "souls": particleVelocity = CGVector(dx: 2, dy: 10); size = CGSize(width: 2, height: 3)
        case "stars": particleVelocity = CGVector(dx: -6, dy: 0); size = CGSize(width: 1, height: 1)
        case "petals": particleVelocity = CGVector(dx: -14, dy: -12); size = CGSize(width: 2, height: 1)
        default: return
        }
        particles.zPosition = 4.8; addChild(particles)
        let color = ambient == "stars" ? SKColor.white : SKColor(rgb: map.accent)
        for i in 0..<(ambient == "rain" ? 40 : 26) {
            let dot = SKSpriteNode(color: color, size: size)
            dot.position = CGPoint(x: CGFloat((i * 97 + 31) % 480), y: CGFloat(44 + (i * 59) % 220))
            dot.alpha = ambient == "rain" ? 0.35 : 0.45 + CGFloat(i % 3) * 0.15
            particles.addChild(dot)
        }
        if ambient == "rain" {
            flash.position = CGPoint(x: 240, y: 135); flash.alpha = 0; flash.zPosition = 6.5; addChild(flash)
        }
    }

    private func buildIllustratedArena(_ texture: SKTexture) {
        usesIllustration = true
        // The painted ledge aligns with the physics floor at y = 42.
        // Aspect-fill preserves the painting's proportions if an artist replaces it.
        let mask = SKSpriteNode(color: .white, size: CGSize(width: 480, height: 270))
        let crop = SKCropNode()
        crop.maskNode = mask
        crop.position = CGPoint(x: 240, y: 135)
        let source = texture.size()
        let fit = max(480 / source.width, 270 / source.height)
        let painting = SKSpriteNode(texture: texture, size: CGSize(width: source.width * fit, height: source.height * fit))
        crop.addChild(painting)
        addChild(crop)

        // Two transparent washes at different speeds create depth over the painting.
        // These are behind both fighters, so mist cannot obscure the combat silhouettes.
        guard let name = map.mist, let mist = backgroundTexture(name) else { return }
        clouds.zPosition = 1
        nearArt.zPosition = 2
        addChild(clouds)
        addChild(nearArt)
        for index in 0..<2 {
            let distant = SKSpriteNode(texture: mist, size: CGSize(width: 480, height: 270))
            distant.position = CGPoint(x: 240 + CGFloat(index) * 480, y: 151)
            distant.alpha = 0.12
            clouds.addChild(distant)
            let near = SKSpriteNode(texture: mist, size: CGSize(width: 480, height: 230))
            near.position = CGPoint(x: 240 + CGFloat(index) * 480, y: 128)
            near.alpha = 0.10
            nearArt.addChild(near)
        }
    }
    func updateFixed(_ dt: CGFloat) {
        let cloudWidth: CGFloat = usesIllustration ? 480 : 62
        cloudX -= (usesIllustration ? 1.25 : 4) * dt
        if cloudX < -cloudWidth { cloudX += cloudWidth }
        nearX -= 3 * dt
        if nearX < -480 { nearX += 480 }
        layoutParallax()
        for dot in particles.children {
            var point = dot.position
            point.x += particleVelocity.dx * dt; point.y += particleVelocity.dy * dt
            if point.x < 0 { point.x += 480 } else if point.x > 480 { point.x -= 480 }
            if point.y < 42 { point.y += 228 } else if point.y > 270 { point.y -= 228 }
            dot.position = point
        }
        if flash.parent != nil {
            // Telegraph-free ambient lightning; gameplay strikes belong to the map event timeline.
            ambientClock += dt
            if ambientClock >= 7 { ambientClock = 0; flash.alpha = 0.32 }
            flash.alpha = max(0, flash.alpha - dt * 1.4)
        }
    }
    private func layerTexture(_ layer: String) -> SKTexture? {
        backgroundTexture("\(map.id)_\(layer)") ?? (map.painting != nil ? backgroundTexture(layer) : nil)
    }
    private func backgroundTexture(_ name: String) -> SKTexture? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Assets/Backgrounds"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        let texture = SKTexture(image: image); texture.filteringMode = .nearest; return texture
    }
}

private extension SKColor {
    var luminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    func blended(with other: SKColor, amount: CGFloat) -> SKColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = min(1, max(0, amount))
        return SKColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
    }
}

private func trianglePath(x: CGFloat, baseY: CGFloat, width: CGFloat, height: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: x, y: baseY))
    path.addLine(to: CGPoint(x: x + width / 2, y: baseY + height))
    path.addLine(to: CGPoint(x: x + width, y: baseY))
    path.closeSubpath()
    return path
}
