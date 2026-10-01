// Deterministic extraction of supplied art plus HUD variants. Run from repo root.
import AppKit
import ImageIO

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("SwordDuel/Resources/Assets")
let sources = root.appendingPathComponent("Art/References/Imported")
func load(_ url: URL) -> CGImage {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError(url.path) }
    return img
}
func context(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4,
              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func save(_ image: CGImage, _ path: String) throws {
    let url = assets.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: url)
}
func crop(_ image: CGImage, _ x: Int, _ y: Int, _ w: Int, _ h: Int) -> CGImage {
    image.cropping(to: CGRect(x: x, y: y, width: w, height: h))!
}
func key(_ image: CGImage, dark: Bool = false) -> CGImage {
    let c = context(image.width, image.height)
    c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let bytes = c.data!.assumingMemoryBound(to: UInt8.self)
    for i in 0..<(image.width*image.height) {
        let p = i*4, r = Int(bytes[p]), g = Int(bytes[p+1]), b = Int(bytes[p+2])
        let matte = dark ? max(r,g,b) < 95 : (r > 120 && b > 85 && g < 65 && r-g > 75 && b-g > 65)
        if matte { for j in 0..<4 { bytes[p+j] = 0 } }
    }
    return c.makeImage()!
}
func strip(_ frames: [CGImage], size: Int = 96) -> CGImage {
    let c = context(size*frames.count, size)
    c.interpolationQuality = .none
    for (i,img) in frames.enumerated() {
        let scale = min(CGFloat(size-8)/CGFloat(img.width), CGFloat(size-8)/CGFloat(img.height))
        let w = CGFloat(img.width)*scale, h = CGFloat(img.height)*scale
        c.draw(img, in: CGRect(x: CGFloat(i*size)+(CGFloat(size)-w)/2, y: (CGFloat(size)-h)/2, width:w,height:h))
    }
    return c.makeImage()!
}

let board = load(sources.appendingPathComponent("maps-nine-regions-atlas.png"))
let mapPanels = [("cloudpeak",3,75,334,118),("lavahell",347,75,291,118),
                 ("greatruins",648,75,290,118),("poisonforest",948,75,285,118),
                 ("divinetemple",1243,75,289,118),("thunderplate",3,913,349,59),
                 ("underwater",359,913,406,59),("underworld",773,913,407,59),
                 ("astralvoid",1187,913,345,59)]
for (id,x,y,w,h) in mapPanels { try save(crop(board,x,y,w,h),"Backgrounds/\(id)_far.png") }

let characters = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("SwordDuel/Data/Characters.json"))) as! [[String:Any]]
for character in characters {
    let id = character["id"] as! String
    let rgb = character["accent"] as! [Double]
    let c = context(124,10)
    for y in 0..<10 {
        let shade = 0.6 + 0.4 * sin(Double(y)/9 * .pi)
        c.setFillColor(NSColor(red:rgb[0]*shade,green:rgb[1]*shade,blue:rgb[2]*shade,alpha:1).cgColor)
        c.fill(CGRect(x:0,y:y,width:124,height:1))
    }
    try save(c.makeImage()!,"UI/hp_\(id)_fill.png")
    let icon = load(assets.appendingPathComponent("UI/btn_\(id)_sk2.png"))
    let button = context(36,36)
    button.draw(icon,in:CGRect(x:0,y:0,width:36,height:36))
    button.setStrokeColor(NSColor(red:0.85,green:0.6,blue:1,alpha:1).cgColor)
    button.setLineWidth(2)
    button.strokeEllipse(in:CGRect(x:3,y:3,width:30,height:30))
    // Three gold pips distinguish awakening SK3 from SK2 at small sizes.
    button.setFillColor(NSColor(red:1,green:0.8,blue:0.4,alpha:1).cgColor)
    for x in [12,17,22] { button.fill(CGRect(x:x,y:5,width:2,height:4)) }
    for suffix in ["", "_pressed"] { try save(button.makeImage()!,"UI/btn_\(id)_sk3\(suffix).png") }
}
let awakening = context(92,4)
awakening.setFillColor(NSColor(red:0.8,green:0.52,blue:1,alpha:1).cgColor)
awakening.fill(CGRect(x:0,y:0,width:92,height:4))
try save(awakening.makeImage()!,"UI/awaken_fill.png")

// Use the explicitly separated VFX panels; never crop a character animation as a VFX.
let flame = load(sources.appendingPathComponent("flame-swordsman-atlas.png"))
for (name,x,y,w,h,count) in [("flame_projectile",12,778,369,70,4),("hit_spark",395,785,251,64,5),
                             ("dash_trail",665,780,294,68,4),("flame_ult",973,770,550,79,8)] {
    let frames = (0..<count).map { i in key(crop(flame,x+i*w/count,y,w/count,h),dark:true) }
    try save(strip(frames),"VFX/\(name).png")
}
let three = load(sources.appendingPathComponent("umbrella-tang-monk-atlases.png"))
for (index,id) in ["umbrella","tang","monk"].enumerated() {
    for (kind,x,w,count) in [("projectile",12,128,4),("ult",315,189,8)] {
        let frames=(0..<count).map { i in
            key(crop(three,index*512+x+(kind == "ult" ? 0 : i*w/count),844,kind == "ult" ? w : w/count,70),dark:true)
        }
        try save(strip(frames),"VFX/\(id)_\(kind).png")
    }
}
let four = load(sources.appendingPathComponent("herder-elder-demon-beast-atlases.png"))
for (index,id) in ["herder","elder","demon","beast"].enumerated() {
    for (kind,x,w,count) in [("projectile",8,170,4),("ult",197,180,8)] {
        let frames=(0..<count).map { i in
            // The ULT illustration is one complete effect, not eight slices of
            // a giant hand/lotus. Hold that intact image across the effect time.
            key(crop(four,index*384+x+(kind == "ult" ? 0 : i*w/count),733,kind == "ult" ? w : w/count,60),dark:true)
        }
        try save(strip(frames),"VFX/\(id)_\(kind).png")
    }
}
let spark = load(assets.appendingPathComponent("VFX/hit_spark.png"))
try save(spark,"VFX/skill1_impact.png")
// Ice projectiles share the supplied pale cyan rain-needle silhouette.
try save(load(assets.appendingPathComponent("VFX/umbrella_projectile.png")),"VFX/projectile_ice.png")
print("Exported 9 map backgrounds, 28 HUD variants and 19 VFX strips from supplied art")

// Stage archetypes use matching supplied silhouettes. Bosses use the larger
// spirit/guardian art; their windup, attacks and death remain driven by the AI.
let monsters = load(sources.appendingPathComponent("map-five-regions-atlas.png"))
for (id,x,y,w,h) in [("wolf",466,835,40,40),("archer",1374,679,36,31),
                    ("brute",142,837,37,37),("bat",139,679,35,31),
                    ("toad",1070,682,41,29),("cloudking",1374,835,39,39),
                    ("firedragon",466,835,40,40),("ghostking",773,681,29,28)] {
    let pose=key(crop(monsters,x,y,w,h))
    try save(strip([pose]),"Monsters/\(id).png")
}
print("Exported 8 stage-enemy skins (single pose; AI supplies movement and hit flash)")
