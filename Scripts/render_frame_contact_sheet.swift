// Renders imported animation frames over a checkerboard for visual QA.
// Usage: swift Scripts/render_frame_contact_sheet.swift <character> <animation> <output.png>
import AppKit

guard CommandLine.arguments.count == 4 else {
    fatalError("Usage: render_frame_contact_sheet.swift <character> <animation> <output.png>")
}

let character = CommandLine.arguments[1]
let animation = CommandLine.arguments[2]
let output = URL(fileURLWithPath: CommandLine.arguments[3])
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let folder = root.appendingPathComponent("SwordDuel/Resources/Assets/Characters/\(character)")
let atlasURL = folder.appendingPathComponent("\(character)_atlas.json")
let object = try JSONSerialization.jsonObject(with: Data(contentsOf: atlasURL)) as! [String: Any]
let animations = object["animations"] as! [String: [String]]
let frames = object["frames"] as! [String: [String: Any]]
guard let names = animations[animation] else { fatalError("Missing \(character).\(animation)") }

let cellWidth = 132
let cellHeight = 124
let canvasWidth = cellWidth * names.count
let canvasHeight = cellHeight
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: canvasWidth, pixelsHigh: canvasHeight,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
graphics.imageInterpolation = .none

for (index, name) in names.enumerated() {
    let cell = NSRect(x: index * cellWidth, y: 0, width: cellWidth, height: cellHeight)
    NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
    cell.fill()
    let square = 12
    for y in stride(from: 0, to: cellHeight, by: square) {
        for x in stride(from: 0, to: cellWidth, by: square) where (x / square + y / square).isMultiple(of: 2) {
            NSColor(calibratedWhite: 0.3, alpha: 1).setFill()
            NSRect(x: index * cellWidth + x, y: y, width: square, height: square).fill()
        }
    }

    let frame = frames[name]!
    let imageName = frame["image"] as! String
    let imageURL = folder.appendingPathComponent("\(imageName).png")
    let image = NSImage(contentsOf: imageURL)!
    let alphaRep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    var opaque = 0
    for y in 0..<alphaRep.pixelsHigh {
        for x in 0..<alphaRep.pixelsWide where (alphaRep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.06 { opaque += 1 }
    }
    let maxWidth = CGFloat(cellWidth - 10)
    let maxHeight = CGFloat(cellHeight - 26)
    let scale = min(maxWidth / image.size.width, maxHeight / image.size.height, 3)
    let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    let destination = NSRect(x: CGFloat(index * cellWidth) + (CGFloat(cellWidth) - size.width) / 2,
                             y: 20, width: size.width, height: size.height)
    image.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1)

    let label = "\(index + 1) · \(Int(image.size.width))×\(Int(image.size.height))"
    label.draw(at: NSPoint(x: index * cellWidth + 5, y: 4), withAttributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
        .foregroundColor: NSColor.white
    ])
    print("\(character).\(animation)[\(index + 1)] \(Int(image.size.width))x\(Int(image.size.height)) alpha=\(opaque)")
}

NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
print(output.path)
