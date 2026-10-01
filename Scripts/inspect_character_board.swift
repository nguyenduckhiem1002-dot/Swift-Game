// Diagnostic utility: exports 40-pixel horizontal slices from a character column.
// Usage: swift Scripts/inspect_character_board.swift <board.png> <column-x> <column-width> <output-dir> [slice-height]
import AppKit
import ImageIO

let arguments = CommandLine.arguments
guard arguments.count == 5 || arguments.count == 6,
      let columnX = Int(arguments[2]), let columnWidth = Int(arguments[3]) else {
    fatalError("Usage: inspect_character_board.swift <board.png> <column-x> <column-width> <output-dir> [slice-height]")
}
let sourceURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[4], isDirectory: true)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let sliceHeight = arguments.count == 6 ? max(1, Int(arguments[5]) ?? 40) : 40
for y in stride(from: 180, to: min(840, image.height), by: sliceHeight) {
    guard let crop = image.cropping(to: CGRect(x: columnX, y: y, width: columnWidth, height: sliceHeight)) else { continue }
    let rep = NSBitmapImageRep(cgImage: crop)
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: outputURL.appendingPathComponent(String(format: "row-%03d.png", y)))
}
