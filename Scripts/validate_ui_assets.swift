import AppKit

let root = URL(fileURLWithPath: "SwordDuel/Resources/Assets/UI", isDirectory: true)
let entries = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: "Art/UI/files.json"))) as! [[String: Any]]
for entry in entries {
    let name = entry["file"] as! String
    let w = entry["width"] as! Int, h = entry["height"] as! Int, frames = entry["frames"] as! Int
    guard let image = NSBitmapImageRep(data: try Data(contentsOf: root.appendingPathComponent(name))) else { fatalError(name) }
    precondition(image.pixelsWide == w * frames && image.pixelsHigh == h, "Bad dimensions: \(name)")
    precondition(image.hasAlpha, "Missing alpha: \(name)")
}
let cooldown = NSBitmapImageRep(data: try Data(contentsOf: root.appendingPathComponent("cooldown.png"))))!
var coverage: [Double] = []
for frame in 0..<8 {
    var alpha = 0.0
    for y in 0..<36 { for x in 0..<36 { alpha += cooldown.colorAt(x: frame * 36 + x, y: y)!.alphaComponent } }
    coverage.append(alpha)
}
precondition(coverage.last == 0)
for i in 1..<coverage.count { precondition(coverage[i] < coverage[i-1], "Cooldown wipe must progressively clear") }
for id in ["frost", "flame"] {
    let image = NSBitmapImageRep(data: try Data(contentsOf: root.appendingPathComponent("btn_\(id)_ult_ready.png"))))!
    var light: [Double] = []
    for frame in 0..<4 {
        var sum = 0.0
        for y in 0..<44 { for x in 0..<44 {
            let c = image.colorAt(x: frame*44+x,y:y)!.usingColorSpace(.deviceRGB)!
            sum += (c.redComponent+c.greenComponent+c.blueComponent)*c.alphaComponent
        }}
        light.append(sum)
    }
    precondition(light[0] < light[1] && light[1] < light[2] && abs(light[1]-light[3]) < 0.01, "ULT must brighten then dim")
}
print("PASS: \(entries.count) UI asset dimensions and alpha channels; eight-step radial wipe; both four-frame ULT pulses.")
