import Foundation
import CoreGraphics
import AppKit

func sliceAtlas(charID: String, dir: String) {
    let jsonPath = "\(dir)/\(charID)_atlas.json"
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let frames = json["frames"] as? [String: [String: Any]] else {
        print("Failed to load \(jsonPath)")
        return
    }
    
    var images = [String: CGImage]()
    for (_, frameData) in frames {
        if let imgName = frameData["image"] as? String, images[imgName] == nil {
            let imgPath = "\(dir)/\(imgName).png"
            if let image = NSImage(contentsOfFile: imgPath)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                images[imgName] = image
            }
        }
    }
    
    let outDir = "\(dir)/frames"
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    
    for (frameName, frameData) in frames {
        guard let imgName = frameData["image"] as? String,
              let img = images[imgName],
              let rectDict = frameData["rect"] as? [String: Int],
              let x = rectDict["x"], let y = rectDict["y"], let w = rectDict["w"], let h = rectDict["h"] else {
            continue
        }
        
        let rect = CGRect(x: x, y: y, width: w, height: h)
        if let cropped = img.cropping(to: rect) {
            let bitmap = NSBitmapImageRep(cgImage: cropped)
            let outData = bitmap.representation(using: .png, properties: [:])
            try? outData?.write(to: URL(fileURLWithPath: "\(outDir)/\(frameName).png"))
        }
    }
    print("Sliced \(frames.count) frames for \(charID)")
}

let chars = try! FileManager.default.contentsOfDirectory(atPath: "/Users/duck/Dev/Game/SwordDuel/Resources/Assets/Characters")
for char in chars {
    let dir = "/Users/duck/Dev/Game/SwordDuel/Resources/Assets/Characters/\(char)"
    var isDir: ObjCBool = false
    if FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue {
        sliceAtlas(charID: char, dir: dir)
    }
}
