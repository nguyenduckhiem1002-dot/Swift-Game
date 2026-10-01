// Exports the three skill icons at the bottom of each supplied character atlas.
// Run from the repository root with: swift -module-cache-path /tmp/SwordDuelSwiftCache Scripts/import_character_icons.swift
import AppKit
import ImageIO

private struct SkillIcons {
    let id: String
    let board: String
    let x: [Int]
    let y: [Int]
    let size: [Int]
}

private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let source = root.appendingPathComponent("Art/References/Imported", isDirectory: true)
private let output = root.appendingPathComponent("SwordDuel/Resources/Assets/UI", isDirectory: true)
private let groups = [
    SkillIcons(id: "umbrella", board: "umbrella-tang-monk-atlases.png", x: [146, 242, 337], y: [928, 928, 928], size: [58, 58, 58]),
    SkillIcons(id: "tang", board: "umbrella-tang-monk-atlases.png", x: [642, 738, 834], y: [928, 928, 928], size: [58, 58, 58]),
    SkillIcons(id: "monk", board: "umbrella-tang-monk-atlases.png", x: [1165, 1261, 1357], y: [928, 928, 928], size: [58, 58, 58]),
    SkillIcons(id: "herder", board: "herder-elder-demon-beast-atlases.png", x: [98, 193, 288], y: [811, 811, 811], size: [48, 48, 48]),
    SkillIcons(id: "elder", board: "herder-elder-demon-beast-atlases.png", x: [482, 577, 672], y: [811, 811, 811], size: [48, 48, 48]),
    SkillIcons(id: "demon", board: "herder-elder-demon-beast-atlases.png", x: [866, 961, 1056], y: [811, 811, 811], size: [48, 48, 48]),
    SkillIcons(id: "flame", board: "flame-swordsman-atlas.png", x: [32, 420, 1290], y: [766, 766, 766], size: [72, 72, 72]),
    SkillIcons(id: "beast", board: "herder-elder-demon-beast-atlases.png", x: [1250, 1345, 1440], y: [811, 811, 811], size: [48, 48, 48])
]

private func load(_ url: URL) throws -> CGImage {
    let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}

private func buttonIcon(_ source: CGImage, width: Int, height: Int) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .none
    context.setShouldAntialias(false)
    let bounds = CGRect(x: 1, y: 1, width: width - 2, height: height - 2)
    context.saveGState()
    context.addEllipse(in: bounds)
    context.clip()
    context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    context.restoreGState()
    context.setShouldAntialias(true)
    context.setStrokeColor(NSColor(red: 0.95, green: 0.72, blue: 0.28, alpha: 1).cgColor)
    context.setLineWidth(1.5)
    context.strokeEllipse(in: bounds.insetBy(dx: 0.75, dy: 0.75))
    return context.makeImage()!
}

private func save(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

for group in groups {
    let board = try load(source.appendingPathComponent(group.board))
    let names = ["sk1", "sk2", "ult"]
    var icons: [CGImage] = []
    for index in 0..<3 {
        let cropRect = CGRect(x: group.x[index], y: group.y[index], width: group.size[index], height: group.size[index])
        guard let crop = board.cropping(to: cropRect) else { fatalError("Missing \(group.id) \(names[index]) icon") }
        let icon = buttonIcon(crop, width: index == 2 ? 44 : 36, height: index == 2 ? 44 : 36)
        icons.append(icon)
        try save(icon, to: output.appendingPathComponent("btn_\(group.id)_\(names[index]).png"))
        if index < 2 {
            // The control shrinks and brightens on touch; retaining the icon avoids swapping
            // to the old numeric placeholder while keeping both files valid for SpriteKit.
            try save(icon, to: output.appendingPathComponent("btn_\(group.id)_\(names[index])_pressed.png"))
        }
    }

    let stripContext = CGContext(data: nil, width: 176, height: 44, bitsPerComponent: 8,
                                 bytesPerRow: 176 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    stripContext.interpolationQuality = .none
    stripContext.setShouldAntialias(false)
    for frame in 0..<4 {
        stripContext.saveGState()
        stripContext.translateBy(x: CGFloat(frame * 44), y: 0)
        let brightness: CGFloat = [0.76, 0.9, 1.0, 0.9][frame]
        stripContext.setAlpha(brightness)
        stripContext.draw(icons[2], in: CGRect(x: 0, y: 0, width: 44, height: 44))
        stripContext.restoreGState()
    }
    try save(stripContext.makeImage()!, to: output.appendingPathComponent("btn_\(group.id)_ult_ready.png"))
    let lockedContext = CGContext(data: nil, width: 44, height: 44, bitsPerComponent: 8,
                                  bytesPerRow: 176, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    lockedContext.interpolationQuality = .none
    lockedContext.setShouldAntialias(false)
    lockedContext.setAlpha(0.38)
    lockedContext.draw(icons[2], in: CGRect(x: 0, y: 0, width: 44, height: 44))
    try save(lockedContext.makeImage()!, to: output.appendingPathComponent("btn_\(group.id)_ult_locked.png"))
    print("Imported \(group.id) skill icons")
}
