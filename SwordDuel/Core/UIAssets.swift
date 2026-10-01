import SpriteKit
import UIKit

/// File-backed UI textures. Every missing or malformed file has a runtime pixel fallback.
final class UIAssets {
    static let shared = UIAssets()
    private var cache: [String: [SKTexture]] = [:]
    private(set) var missingAssets: Set<String> = []
    private init() {}

    func texture(_ name: String, size: CGSize) -> SKTexture {
        frames(name, frameSize: size, count: 1)[0]
    }
    func frames(_ name: String, frameSize: CGSize, count: Int) -> [SKTexture] {
        let key = "\(name):\(Int(frameSize.width))x\(Int(frameSize.height)):\(count)"
        if let textures = cache[key] { return textures }
        let width = Int(frameSize.width), height = Int(frameSize.height)
        var result: [SKTexture] = []
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Assets/UI"),
           let image = UIImage(contentsOfFile: url.path)?.cgImage,
           image.width == width * count, image.height == height {
            for index in 0..<count {
                if let crop = image.cropping(to: CGRect(x: index * width, y: 0, width: width, height: height)) {
                    let texture = SKTexture(cgImage: crop); texture.filteringMode = .nearest; result.append(texture)
                }
            }
        }
        if result.count != count {
            missingAssets.insert(name)
            result = (0..<count).map { fallback(name, size: frameSize, frame: $0, count: count) }
        }
        cache[key] = result
        return result
    }
    func sprite(_ name: String, size: CGSize) -> SKSpriteNode {
        SKSpriteNode(texture: texture(name, size: size), size: size)
    }
    private func fallback(_ name: String, size: CGSize, frame: Int, count: Int) -> SKTexture {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let c = renderer.cgContext; c.setShouldAntialias(false)
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            let dim = name.contains("disabled") || name.contains("locked") || name.contains("unselected")
            let owner = CharacterLibrary.all.first { name.contains("_\($0.id)_") }
            let accent: UIColor = owner?.accentColor ?? (name.contains("ko") ? Theme.fire : Theme.ice)
            if name == "cooldown" {
                guard frame < count - 1 else { return }
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                c.setFillColor(Theme.navy.withAlphaComponent(0.78).cgColor)
                c.move(to: center)
                c.addArc(center: center, radius: size.width / 2 - 1, startAngle: -.pi / 2 + CGFloat(frame) / CGFloat(count-1) * 2 * .pi, endAngle: 1.5 * .pi, clockwise: false)
                c.closePath(); c.fillPath(); return
            }
            if name.contains("fill") {
                c.setFillColor((name.contains("energy") ? Theme.gold : name.contains("awaken") ? Theme.awaken : accent).cgColor)
                c.fill(CGRect(origin: .zero, size: size)); return
            }
            let round = name.hasPrefix("dpad") || name.hasPrefix("round") || (name.hasPrefix("btn") && !name.contains("menu") && !name.contains("difficulty") && !name.contains("debug"))
            c.setFillColor((dim ? UIColor.darkGray : Theme.navy).cgColor)
            c.setStrokeColor((dim ? UIColor.gray : Theme.gold).cgColor); c.setLineWidth(1)
            if round { c.fillEllipse(in: rect); c.strokeEllipse(in: rect) }
            else {
                if !name.contains("frame") || name == "timer_frame" { c.fill(rect) }
                c.stroke(rect)
            }
            var glyph = ""
            if name.hasPrefix("dpad") { glyph = name.contains("left") ? "◀" : name.contains("right") ? "▶" : name.contains("up") ? "▲" : "▼" }
            else if name.contains("pause") { glyph = "Ⅱ" }
            else if name.contains("debug") { glyph = "◎" }
            else if name == "round_filled" { glyph = "◆" }
            else if name.contains("ult") { glyph = "ULT" }
            else if name.hasSuffix("_sk1") || name.hasSuffix("_sk1_pressed") { glyph = "1" }
            else if name.hasSuffix("_sk2") || name.hasSuffix("_sk2_pressed") { glyph = "2" }
            else if name.hasSuffix("_sk3") || name.hasSuffix("_sk3_pressed") { glyph = "3" }
            if !glyph.isEmpty {
                let font = UIFont(name: "PlayfairDisplay-Black", size: min(11, size.height * 0.4)) ?? UIFont.monospacedSystemFont(ofSize: min(11, size.height * 0.4), weight: .bold)
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: accent]
                let label = glyph as NSString; let measured = label.size(withAttributes: attributes)
                label.draw(at: CGPoint(x: (size.width-measured.width)/2, y: (size.height-measured.height)/2), withAttributes: attributes)
            }
        }
        let texture = SKTexture(image: image); texture.filteringMode = .nearest; return texture
    }
}

/// The mask changes width; the fill texture itself never stretches as HP changes.
final class UIResourceBar: SKNode {
    private let mask: SKSpriteNode
    private let innerSize: CGSize
    init(frame: String, fill: String, nativeFrame: CGSize, nativeFill: CGSize, displayWidth: CGFloat, outsideIsLeft: Bool) {
        innerSize = CGSize(width: displayWidth - (nativeFrame.width-nativeFill.width), height: nativeFill.height)
        mask = SKSpriteNode(color: .white, size: innerSize)
        super.init()
        let backing = SKSpriteNode(color: Theme.navy, size: innerSize); addChild(backing)
        let crop = SKCropNode(); crop.maskNode = mask; addChild(crop)
        let fillSprite = SKSpriteNode(texture: UIAssets.shared.texture(fill, size: nativeFill), size: innerSize)
        crop.addChild(fillSprite)
        mask.anchorPoint = CGPoint(x: outsideIsLeft ? 1 : 0, y: 0.5)
        mask.position.x = outsideIsLeft ? innerSize.width / 2 : -innerSize.width / 2
        let border = UIAssets.shared.sprite(frame, size: nativeFrame)
        border.centerRect = CGRect(x: 0.22, y: 0.3, width: 0.56, height: 0.4)
        border.size.width = displayWidth
        border.zPosition = 1
        addChild(border)
    }
    required init?(coder: NSCoder) { fatalError() }
    func setFraction(_ value: CGFloat) {
        let fraction = min(1, max(0, value))
        mask.isHidden = fraction <= 0
        mask.size.width = max(0.001, innerSize.width * fraction)
    }
}
