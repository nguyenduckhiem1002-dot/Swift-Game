import Foundation

let jsonPath = "/Users/duck/Dev/Game/SwordDuel/Resources/Assets/Characters/frost/frost_atlas.json"
guard let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let frames = json["frames"] as? [String: [String: Any]] else {
    fatalError()
}

var maxW = 0
var maxH = 0
for (_, frame) in frames {
    let rect = frame["rect"] as! [String: Int]
    maxW = max(maxW, rect["w"]!)
    maxH = max(maxH, rect["h"]!)
}
print("Max W: \(maxW), Max H: \(maxH)")
