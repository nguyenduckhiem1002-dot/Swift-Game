import SpriteKit
import UIKit

final class ArenaBackground: SKNode {
    private let clouds = SKNode()
    private var cloudX: CGFloat = 0
    private let nearArt = SKNode()
    private var nearX: CGFloat = 0
    private var usesIllustration = false
    override init() {
        super.init()
        if let painting = backgroundTexture("xianxia_moon_dragon") {
            buildIllustratedArena(painting)
            return
        }
        let sky = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 480, height: 270))
        sky.fillColor = Theme.navy; sky.strokeColor = .clear; addChild(sky)
        let moon = SKShapeNode(circleOfRadius: 47)
        moon.position = CGPoint(x: 405, y: 210)
        moon.fillColor = SKColor(red: 0.83, green: 0.93, blue: 1, alpha: 1)
        moon.strokeColor = Theme.ice; moon.lineWidth = 2; moon.zPosition = 1; addChild(moon)
        for i in 0..<75 {
            let x = CGFloat((i * 73 + 17) % 480)
            let y = CGFloat(98 + (i * 47) % 170)
            let star = SKShapeNode(rectOf: CGSize(width: i % 7 == 0 ? 2 : 1, height: i % 7 == 0 ? 2 : 1))
            star.position = CGPoint(x: x, y: y); star.fillColor = .white; star.strokeColor = .clear; star.zPosition = 1; addChild(star)
        }
        for i in 0..<6 {
            let x = CGFloat(i * 96 - 25)
            let peak = SKShapeNode(path: trianglePath(x: x, baseY: 56, width: 135, height: CGFloat(95 + i % 3 * 15)))
            peak.fillColor = SKColor(red: 0.13, green: 0.22, blue: 0.35, alpha: 1)
            peak.strokeColor = Theme.ice.withAlphaComponent(0.35); peak.lineWidth = 1; peak.zPosition = 2; addChild(peak)
            let pagoda = SKShapeNode(rectOf: CGSize(width: 13, height: 15))
            pagoda.position = CGPoint(x: x + 67, y: CGFloat(151 + i % 3 * 15)); pagoda.fillColor = Theme.gold.withAlphaComponent(0.75); pagoda.strokeColor = .clear; pagoda.zPosition = 3; addChild(pagoda)
        }
        if let far = backgroundTexture("far") {
            let sprite = SKSpriteNode(texture: far, size: CGSize(width: 480, height: 270))
            sprite.position = CGPoint(x: 240, y: 135); sprite.zPosition = 1.5; addChild(sprite)
        }
        if let mid = backgroundTexture("mid") {
            let sprite = SKSpriteNode(texture: mid, size: CGSize(width: 480, height: 270))
            sprite.position = CGPoint(x: 240, y: 135); sprite.zPosition = 3.5; addChild(sprite)
        }
        clouds.zPosition = 4; addChild(clouds)
        for i in 0..<12 {
            let cloud = SKShapeNode(ellipseOf: CGSize(width: 78, height: 13))
            cloud.position = CGPoint(x: CGFloat(i * 62 - 50), y: CGFloat(82 + i % 3 * 13))
            cloud.fillColor = SKColor(red: 0.68, green: 0.83, blue: 0.94, alpha: 0.19)
            cloud.strokeColor = .clear; clouds.addChild(cloud)
        }
        nearArt.zPosition = 4.5; addChild(nearArt)
        if let near = backgroundTexture("near") {
            for index in 0..<2 {
                let sprite = SKSpriteNode(texture: near, size: CGSize(width: 480, height: 270))
                sprite.position = CGPoint(x: 240 + CGFloat(index) * 480, y: 135)
                nearArt.addChild(sprite)
            }
        }
        let ground = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 480, height: 42))
        ground.fillColor = SKColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1)
        ground.strokeColor = Theme.ice; ground.lineWidth = 2; ground.zPosition = 5; addChild(ground)
        for i in 0..<32 {
            let tile = SKShapeNode(rectOf: CGSize(width: 13, height: 1))
            tile.position = CGPoint(x: CGFloat(i * 16 + 4), y: CGFloat(9 + (i % 3) * 8))
            tile.fillColor = Theme.ice.withAlphaComponent(0.16); tile.strokeColor = .clear; tile.zPosition = 6; addChild(tile)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
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
        guard let mist = backgroundTexture("xianxia_mist") else { return }
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
        clouds.position.x = cloudX
        nearX -= 3 * dt
        if nearX < -480 { nearX += 480 }
        nearArt.position.x = nearX
    }
    private func backgroundTexture(_ name: String) -> SKTexture? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Assets/Backgrounds"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        let texture = SKTexture(image: image); texture.filteringMode = .nearest; return texture
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
