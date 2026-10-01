// Run from the project root: swift -module-cache-path /tmp/SwordDuelSwiftCache Scripts/export_ui.swift
// Deterministic slicing and nearest-neighbor export of the imagegen UI masters.
import AppKit

let output = URL(fileURLWithPath: "SwordDuel/Resources/Assets/UI", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let icons = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: "Art/UI/icons-source.png")))!
let panels = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: "Art/UI/panels-source.png")))!
let markers = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: "Art/UI/markers-source.png")))!
var inventory: [[String: Any]] = []
func context(_ width: Int, _ height: Int) -> CGContext {
    let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .none
    c.setShouldAntialias(false)
    return c
}
func image(_ source: NSBitmapImageRep, region: CGRect, width: Int, height: Int, fit: Bool = true) -> CGImage {
    // Trim only pixels inside this atlas cell; text is never baked into these assets.
    var minX = Int(region.maxX), minY = Int(region.maxY), maxX = Int(region.minX), maxY = Int(region.minY)
    for y in Int(region.minY)..<Int(region.maxY) {
        for x in Int(region.minX)..<Int(region.maxX) where source.colorAt(x: x, y: y)!.alphaComponent > 0.3 {
            minX = min(minX,x); minY = min(minY,y); maxX = max(maxX,x); maxY = max(maxY,y)
        }
    }
    precondition(maxX > minX && maxY > minY)
    let crop = source.cgImage!.cropping(to: CGRect(x:minX,y:minY,width:maxX-minX+1,height:maxY-minY+1))!
    let c = context(width,height)
    let factor = min(CGFloat(width)/CGFloat(crop.width),CGFloat(height)/CGFloat(crop.height))
    let w = fit ? CGFloat(crop.width) * factor : CGFloat(width)
    let h = fit ? CGFloat(crop.height) * factor : CGFloat(height)
    c.draw(crop,in:CGRect(x:(CGFloat(width)-w)/2,y:(CGFloat(height)-h)/2,width:w,height:h))
    return c.makeImage()!
}
func adjusted(_ input: CGImage, brightness: Double = 1, grey: Bool = false, warm: Bool = false) -> CGImage {
    let c = context(input.width,input.height); c.draw(input,in:CGRect(x:0,y:0,width:input.width,height:input.height))
    let data = c.data!.assumingMemoryBound(to: UInt8.self)
    for p in stride(from:0,to:input.width*input.height*4,by:4) {
        let a = Double(data[p+3]); if a == 0 { continue }
        var r=Double(data[p]),g=Double(data[p+1]),b=Double(data[p+2])
        if grey { let l = r*0.25+g*0.6+b*0.15; r=l;g=l;b=l }
        if warm { r=max(r,b);g *= 0.65;b *= 0.4 }
        data[p]=UInt8(min(a,r*brightness));data[p+1]=UInt8(min(a,g*brightness));data[p+2]=UInt8(min(a,b*brightness))
    }
    return c.makeImage()!
}
func save(_ name: String, _ frames: [CGImage]) {
    let w=frames[0].width,h=frames[0].height,c=context(w*frames.count,h)
    for (i,frame) in frames.enumerated() { c.draw(frame,in:CGRect(x:i*w,y:0,width:w,height:h)) }
    let rep=NSBitmapImageRep(cgImage:c.makeImage()!)
    try! rep.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"))
    inventory.append(["file":name+".png","width":w,"height":h,"frames":frames.count])
}
let rows=[0,310,617,951,1254]
let iconNames=["dpad_left","dpad_right","dpad_up","dpad_down","btn_atk","btn_block","btn_frost_sk1","btn_frost_sk2","btn_flame_sk1","btn_flame_sk2","btn_frost_ult","btn_flame_ult","btn_pause","btn_debug_off","btn_debug_on","portrait_frame"]
for (index,name) in iconNames.enumerated() {
    let col=index%4,row=index/4
    let size = name.hasPrefix("dpad") || name == "portrait_frame" ? 32 : name == "btn_atk" ? 40 : name.contains("ult") ? 44 : name.contains("debug") || name == "btn_pause" ? 24 : 36
    let region=CGRect(x:col*1254/4,y:rows[row],width:(col+1)*1254/4-col*1254/4,height:rows[row+1]-rows[row])
    let normal=image(icons,region:region,width:size,height:size)
    if name.contains("ult") {
        save(name+"_locked",[adjusted(normal,brightness:0.55,grey:true)])
        save(name+"_ready",[0.86,1.0,1.2,1.0].map { adjusted(normal,brightness:$0) })
    } else {
        save(name,[normal])
        if !name.contains("debug") && name != "portrait_frame" { save(name+"_pressed",[adjusted(normal,brightness:1.22)]) }
    }
}
let panelSpecs: [(String, CGRect, Int, Int)] = [
    ("btn_menu_normal",CGRect(x:0,y:0,width:724,height:246),96,28),
    ("btn_menu_pressed",CGRect(x:724,y:0,width:724,height:246),96,28),
    ("btn_menu_disabled",CGRect(x:1448,y:0,width:724,height:246),96,28),
    ("hp_frame",CGRect(x:0,y:285,width:744,height:151),128,14),
    ("hp_frost_fill",CGRect(x:760,y:302,width:660,height:118),124,10),
    ("hp_flame_fill",CGRect(x:1460,y:302,width:690,height:118),124,10),
    ("energy_frame",CGRect(x:0,y:490,width:724,height:180),96,8),
    ("energy_fill",CGRect(x:746,y:540,width:674,height:80),92,4),
    ("timer_frame",CGRect(x:1490,y:465,width:610,height:220),48,24)
]
for (name,rect,w,h) in panelSpecs { save(name,[image(panels,region:rect,width:w,height:h,fit:false)]) }
for i in 0..<2 { save(i == 0 ? "round_empty" : "round_filled",[image(markers,region:CGRect(x:i*887,y:0,width:887,height:887),width:16,height:16)]) }
let normalRect=CGRect(x:0,y:0,width:724,height:246), pressedRect=CGRect(x:724,y:0,width:724,height:246)
save("btn_difficulty_unselected",[image(panels,region:normalRect,width:64,height:24,fit:false)])
save("btn_difficulty_selected",[image(panels,region:pressedRect,width:64,height:24,fit:false)])
let banner=image(panels,region:normalRect,width:160,height:40,fit:false)
save("banner_fight",[banner]); save("banner_ko",[adjusted(banner,warm:true)])
var cooldown: [CGImage]=[]
for frame in 0..<8 {
    let c=context(36,36), data=c.data!.assumingMemoryBound(to:UInt8.self)
    for y in 0..<36 { for x in 0..<36 {
        let dx=Double(x)-17.5,dy=Double(y)-17.5,r=sqrt(dx*dx+dy*dy)
        var angle=atan2(dx,-dy);if angle<0 {angle += 2 * .pi}
        if r<=17 && frame<7 && angle >= Double(frame)/7 * 2 * .pi {
            let p=(y*36+x)*4
            data[p]=5;data[p+1]=12;data[p+2]=28;data[p+3]=195
            if r>16 {data[p]=75;data[p+1]=125;data[p+2]=170;data[p+3]=210}
        }
    }}
    cooldown.append(c.makeImage()!)
}
save("cooldown",cooldown)
try JSONSerialization.data(withJSONObject:inventory,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Art/UI/files.json"))
print("Exported \(inventory.count) UI PNG files with nearest-neighbor sampling.")
