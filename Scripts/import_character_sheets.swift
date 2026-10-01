// Imports the character animation panels from the supplied composite sheets.
// Run from the repository root: swift -module-cache-path /tmp/SwordDuelSwiftCache Scripts/import_character_sheets.swift
import AppKit
import ImageIO

private struct Region {
    let name: String
    let x0: Int
    let x1: Int
    let y0: Int
    let y1: Int
    let count: Int
}

private struct CharacterImport {
    let id: String
    let board: String
    let columnX: Int
    let columnWidth: Int
    let scale: Double
    let regions: [Region]
    let portraitX: Int
    let portraitWidth: Int
}

private func load(_ url: URL) throws -> CGImage {
    let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}

private func context(_ width: Int, _ height: Int) -> CGContext {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

private func savePNG(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

private func keyedColumn(source: CGImage, x: Int, width: Int, yForKey: Int) -> (image: CGImage, rgba: [UInt8], key: (Int, Int, Int)) {
    let rect = CGRect(x: x, y: 0, width: width, height: source.height)
    let column = source.cropping(to: rect)!
    let c = context(width, source.height)
    c.interpolationQuality = .none
    c.setShouldAntialias(false)
    c.draw(column, in: CGRect(x: 0, y: 0, width: width, height: source.height))
    let pointer = c.data!.assumingMemoryBound(to: UInt8.self)
    let keyX = width - 8
    let keyOffset = (yForKey * width + keyX) * 4
    let key = (Int(pointer[keyOffset]), Int(pointer[keyOffset + 1]), Int(pointer[keyOffset + 2]))
    var bytes = Array(UnsafeBufferPointer(start: pointer, count: width * source.height * 4))
    // Only remove matte connected to the panel edge. A global color key damaged the
    // pink/purple magic belonging to Thiên Ma Nữ and left noisy halos around sprites.
    let pixelCount = width * source.height
    var visited = [Bool](repeating: false, count: pixelCount)
    var queue: [Int] = []
    queue.reserveCapacity(pixelCount / 2)
    func isMatte(_ pixel: Int) -> Bool {
        let p = pixel * 4
        let r = Int(bytes[p]), g = Int(bytes[p + 1]), b = Int(bytes[p + 2])
        let dr = Double(r - key.0), dg = Double(g - key.1), db = Double(b - key.2)
        return r > 135 && b > 80 && g < 90 && sqrt(dr * dr + dg * dg + db * db) < 105
    }
    func enqueue(_ pixel: Int) {
        guard !visited[pixel], isMatte(pixel) else { return }
        visited[pixel] = true
        queue.append(pixel)
    }
    for x in 0..<width { enqueue(x); enqueue((source.height - 1) * width + x) }
    for y in 0..<source.height { enqueue(y * width); enqueue(y * width + width - 1) }
    var cursor = 0
    while cursor < queue.count {
        let pixel = queue[cursor]; cursor += 1
        let x = pixel % width, y = pixel / width
        if x > 0 { enqueue(pixel - 1) }
        if x + 1 < width { enqueue(pixel + 1) }
        if y > 0 { enqueue(pixel - width) }
        if y + 1 < source.height { enqueue(pixel + width) }
    }
    for pixel in queue {
        let p = pixel * 4
        bytes[p] = 0; bytes[p + 1] = 0; bytes[p + 2] = 0; bytes[p + 3] = 0
    }
    // Divider lines can completely enclose a magenta row. Remove those large enclosed
    // matte islands too, while preserving small pink spell details inside a sprite.
    for seed in 0..<pixelCount where !visited[seed] && isMatte(seed) {
        var component = [seed]
        visited[seed] = true
        var componentCursor = 0
        while componentCursor < component.count {
            let pixel = component[componentCursor]; componentCursor += 1
            let x = pixel % width, y = pixel / width
            let neighbors = [x > 0 ? pixel - 1 : -1,
                             x + 1 < width ? pixel + 1 : -1,
                             y > 0 ? pixel - width : -1,
                             y + 1 < source.height ? pixel + width : -1]
            for neighbor in neighbors where neighbor >= 0 && !visited[neighbor] && isMatte(neighbor) {
                visited[neighbor] = true
                component.append(neighbor)
            }
        }
        if component.count >= 256 {
            for pixel in component {
                let p = pixel * 4
                bytes[p] = 0; bytes[p + 1] = 0; bytes[p + 2] = 0; bytes[p + 3] = 0
            }
        }
    }
    // Finish the chroma edge globally. Exact/near-exact matte pixels can become
    // isolated inside hair, cloth and sword gaps, so connectivity alone is not enough.
    for pixel in 0..<pixelCount where bytes[pixel * 4 + 3] > 0 {
        let p = pixel * 4
        let dr = Double(Int(bytes[p]) - key.0)
        let dg = Double(Int(bytes[p + 1]) - key.1)
        let db = Double(Int(bytes[p + 2]) - key.2)
        let distance = sqrt(dr * dr + dg * dg + db * db)
        if distance < 42 {
            bytes[p] = 0; bytes[p + 1] = 0; bytes[p + 2] = 0; bytes[p + 3] = 0
        } else if distance < 68 {
            bytes[p + 3] = UInt8(Double(bytes[p + 3]) * ((distance - 42) / 26))
        }
    }
    // Composite boards have bright one-pixel panel separators on their outer
    // edges. They are layout guides, not animation art.
    for y in 0..<source.height {
        for x in [0, 1, width - 2, width - 1] where x >= 0 && x < width {
            let p = (y * width + x) * 4
            bytes[p] = 0; bytes[p + 1] = 0; bytes[p + 2] = 0; bytes[p + 3] = 0
        }
    }
    let out = context(width, source.height)
    let byteCount = bytes.count
    _ = bytes.withUnsafeMutableBytes { storage in
        memcpy(out.data!, storage.baseAddress!, byteCount)
    }
    return (out.makeImage()!, bytes, key)
}

private func alphaBounds(_ bytes: [UInt8], width: Int, height: Int, region: Region, x0: Int, x1: Int) -> CGRect? {
    var minX = x1, minY = region.y1
    var maxX = x0 - 1, maxY = region.y0 - 1
    for y in region.y0..<region.y1 {
        for x in x0..<x1 where bytes[(y * width + x) * 4 + 3] > 16 {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY else { return nil }
    let left = max(x0, minX - 1), top = max(region.y0, minY - 1)
    let right = min(x1 - 1, maxX + 1), bottom = min(region.y1 - 1, maxY + 1)
    return CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
}

private func opaqueCount(_ bytes: [UInt8], width: Int, rect: CGRect) -> Int {
    var count = 0
    for y in Int(rect.minY)..<Int(rect.maxY) {
        for x in Int(rect.minX)..<Int(rect.maxX) where bytes[(y * width + x) * 4 + 3] > 16 { count += 1 }
    }
    return count
}

// The generated boards do not use a reliable grid: some poses are wider than
// others and several slash trails nearly touch the next pose. Find a low-alpha
// vertical seam near each expected division instead of blindly dividing a row
// into equal cells. The result is still constrained to one local cell so a bad
// seam cannot consume a neighbouring frame.
private func frameSlices(_ bytes: [UInt8], width: Int, region: Region) -> [(x0: Int, x1: Int)] {
    guard region.count > 1 else { return [(region.x0, region.x1)] }

    let rowWidth = region.x1 - region.x0
    let nominalWidth = Double(rowWidth) / Double(region.count)
    var boundaries = [region.x0]

    for index in 1..<region.count {
        let ideal = region.x0 + Int((Double(index) * nominalWidth).rounded())
        // Keep seams close enough that one output can never expand to almost
        // two cells and swallow the neighbouring pose.
        let radius = max(2, Int((nominalWidth * 0.12).rounded()))
        let minimumFrameWidth = max(4, Int((nominalWidth * 0.55).rounded()))
        let minimum = max(boundaries.last! + minimumFrameWidth, ideal - radius)
        let maximum = min(region.x1 - (region.count - index) * minimumFrameWidth, ideal + radius)
        guard minimum <= maximum else {
            boundaries.append(ideal)
            continue
        }

        var bestX = ideal
        var bestScore = Int.max
        for candidate in minimum...maximum {
            var alphaPixels = 0
            // A three-pixel seam avoids selecting a one-pixel hole inside a
            // sword, ribbon or particle trail.
            for sampleX in max(region.x0, candidate - 1)...min(region.x1 - 1, candidate + 1) {
                for y in region.y0..<region.y1 where bytes[(y * width + sampleX) * 4 + 3] > 16 {
                    alphaPixels += 1
                }
            }
            // Prefer a genuinely clear separator. Distance from the nominal
            // cadence only breaks ties between seams with the same opacity.
            let score = alphaPixels * 1_000 + abs(candidate - ideal)
            if score < bestScore {
                bestScore = score
                bestX = candidate
            }
        }
        boundaries.append(bestX)
    }
    boundaries.append(region.x1)

    // Sparse rows (especially ten-frame ultimates) may have transparent tails.
    // If a selected seam would leave an entirely empty frame, restore that
    // frame's nominal boundaries rather than silently exporting a blank PNG.
    func containsArt(from x0: Int, to x1: Int) -> Bool {
        for y in region.y0..<region.y1 {
            for x in x0..<x1 where bytes[(y * width + x) * 4 + 3] > 16 { return true }
        }
        return false
    }
    for index in 0..<region.count where !containsArt(from: boundaries[index], to: boundaries[index + 1]) {
        if index > 0 {
            boundaries[index] = region.x0 + Int((Double(index) * nominalWidth).rounded())
        }
        if index + 1 < region.count {
            boundaries[index + 1] = region.x0 + Int((Double(index + 1) * nominalWidth).rounded())
        }
    }

    return (0..<region.count).map { (boundaries[$0], boundaries[$0 + 1]) }
}

private let threeColumnRegions = [
    // The generated row contains a seventh duplicate despite its IDLE (6) label.
    Region(name: "idle", x0: 0, x1: 440, y0: 210, y1: 260, count: 6),
    Region(name: "walk", x0: 0, x1: 512, y0: 280, y1: 340, count: 8),
    Region(name: "run", x0: 0, x1: 512, y0: 360, y1: 390, count: 8),
    Region(name: "jump", x0: 0, x1: 280, y0: 430, y1: 470, count: 4),
    Region(name: "crouch_block", x0: 280, x1: 512, y0: 430, y1: 470, count: 3),
    Region(name: "attack1", x0: 0, x1: 256, y0: 520, y1: 570, count: 5),
    Region(name: "attack2", x0: 256, x1: 512, y0: 520, y1: 570, count: 5),
    Region(name: "attack3", x0: 0, x1: 256, y0: 590, y1: 640, count: 6),
    Region(name: "skill1", x0: 256, x1: 512, y0: 590, y1: 640, count: 6),
    Region(name: "skill2", x0: 0, x1: 240, y0: 680, y1: 720, count: 6),
    Region(name: "ult", x0: 240, x1: 512, y0: 680, y1: 720, count: 10),
    Region(name: "hurt", x0: 0, x1: 140, y0: 760, y1: 800, count: 3),
    Region(name: "ko", x0: 140, x1: 330, y0: 760, y1: 800, count: 6),
    Region(name: "win", x0: 330, x1: 512, y0: 760, y1: 800, count: 6)
]

private let fourColumnRegions = [
    // The generated row contains a seventh duplicate despite its IDLE (6) label.
    Region(name: "idle", x0: 0, x1: 330, y0: 220, y1: 260, count: 6),
    Region(name: "walk", x0: 0, x1: 384, y0: 280, y1: 320, count: 8),
    Region(name: "run", x0: 0, x1: 384, y0: 340, y1: 380, count: 8),
    Region(name: "jump", x0: 0, x1: 192, y0: 390, y1: 430, count: 4),
    Region(name: "crouch_block", x0: 192, x1: 384, y0: 390, y1: 430, count: 3),
    Region(name: "attack1", x0: 0, x1: 192, y0: 450, y1: 490, count: 5),
    Region(name: "attack2", x0: 192, x1: 384, y0: 450, y1: 490, count: 6),
    Region(name: "attack3", x0: 0, x1: 192, y0: 520, y1: 560, count: 6),
    Region(name: "skill1", x0: 192, x1: 384, y0: 520, y1: 560, count: 6),
    Region(name: "skill2", x0: 0, x1: 192, y0: 580, y1: 630, count: 6),
    Region(name: "ult", x0: 192, x1: 384, y0: 580, y1: 630, count: 10),
    Region(name: "hurt", x0: 0, x1: 128, y0: 650, y1: 690, count: 3),
    Region(name: "ko", x0: 128, x1: 256, y0: 650, y1: 690, count: 6),
    Region(name: "win", x0: 256, x1: 384, y0: 650, y1: 690, count: 6)
]

// Dedicated Hỏa Ma Kiếm sheet supplied after the multi-character boards.
// Coordinates intentionally exclude every heading, divider and VFX/background panel.
private let flameRegions = [
    // These two generated rows also contain one trailing duplicate beyond their labels.
    Region(name: "idle", x0: 319, x1: 740, y0: 31, y1: 128, count: 6),
    Region(name: "walk", x0: 830, x1: 1428, y0: 31, y1: 128, count: 8),
    Region(name: "jump", x0: 319, x1: 805, y0: 169, y1: 261, count: 4),
    Region(name: "crouch_block", x0: 319, x1: 544, y0: 302, y1: 390, count: 2),
    Region(name: "attack1", x0: 550, x1: 1019, y0: 302, y1: 390, count: 5),
    Region(name: "run", x0: 830, x1: 1520, y0: 169, y1: 261, count: 8),
    Region(name: "attack2", x0: 1032, x1: 1520, y0: 302, y1: 390, count: 5),
    Region(name: "attack3", x0: 319, x1: 855, y0: 425, y1: 512, count: 6),
    Region(name: "skill1", x0: 870, x1: 1520, y0: 425, y1: 512, count: 6),
    Region(name: "skill2", x0: 319, x1: 778, y0: 546, y1: 636, count: 6),
    Region(name: "ult", x0: 805, x1: 1520, y0: 546, y1: 636, count: 10),
    Region(name: "hurt", x0: 319, x1: 497, y0: 672, y1: 741, count: 3),
    Region(name: "ko", x0: 507, x1: 824, y0: 672, y1: 741, count: 6),
    Region(name: "win", x0: 846, x1: 1520, y0: 672, y1: 741, count: 6)
]

private let demonRegions = fourColumnRegions.map { region -> Region in
    switch region.name {
    case "attack2": return Region(name: "attack2", x0: 192, x1: 384, y0: 450, y1: 490, count: 5)
    case "skill1": return Region(name: "skill1", x0: 0, x1: 192, y0: 520, y1: 560, count: 6)
    case "skill2": return Region(name: "skill2", x0: 192, x1: 384, y0: 520, y1: 560, count: 6)
    case "ult": return Region(name: "ult", x0: 0, x1: 384, y0: 580, y1: 630, count: 10)
    default: return region
    }
}

private let herderRegions = fourColumnRegions.map { region -> Region in
    if region.name == "attack2" {
        return Region(name: "attack2", x0: 192, x1: 384, y0: 450, y1: 490, count: 5)
    }
    return region
}

private let elderRegions = fourColumnRegions.map { region -> Region in
    switch region.name {
    case "attack1": return Region(name: "attack1", x0: 0, x1: 192, y0: 450, y1: 490, count: 6)
    // This board supplies one named skill. Reuse a complete six-frame action
    // for the second gameplay slot instead of slicing the ultimate beneath it.
    case "skill2": return Region(name: "skill2", x0: 0, x1: 192, y0: 520, y1: 560, count: 6)
    case "ult": return Region(name: "ult", x0: 0, x1: 384, y0: 580, y1: 630, count: 10)
    default: return region
    }
}

private let beastRegions = fourColumnRegions.map { region -> Region in
    switch region.name {
    case "attack2": return Region(name: "attack2", x0: 192, x1: 384, y0: 450, y1: 490, count: 5)
    // The source has one named skill followed by a full-width ultimate.
    case "skill2": return Region(name: "skill2", x0: 0, x1: 192, y0: 520, y1: 560, count: 6)
    case "ult": return Region(name: "ult", x0: 0, x1: 384, y0: 580, y1: 630, count: 10)
    default: return region
    }
}

private let imports: [CharacterImport] = [
    CharacterImport(id: "umbrella", board: "umbrella-tang-monk-atlases.png", columnX: 0, columnWidth: 512, scale: 1.25, regions: threeColumnRegions, portraitX: 195, portraitWidth: 180),
    CharacterImport(id: "tang", board: "umbrella-tang-monk-atlases.png", columnX: 512, columnWidth: 512, scale: 1.25, regions: threeColumnRegions, portraitX: 200, portraitWidth: 180),
    CharacterImport(id: "monk", board: "umbrella-tang-monk-atlases.png", columnX: 1024, columnWidth: 512, scale: 1.25,
                    regions: threeColumnRegions.map {
                        if $0.name == "attack2" { return Region(name: $0.name, x0: $0.x0, x1: $0.x1, y0: $0.y0, y1: $0.y1, count: 5) }
                        if $0.name == "skill2" { return Region(name: $0.name, x0: 0, x1: 212, y0: $0.y0, y1: $0.y1, count: 6) }
                        if $0.name == "ult" { return Region(name: $0.name, x0: 212, x1: 512, y0: $0.y0, y1: $0.y1, count: 10) }
                        if $0.name == "hurt" { return Region(name: $0.name, x0: 0, x1: 126, y0: $0.y0, y1: $0.y1, count: 3) }
                        if $0.name == "ko" { return Region(name: $0.name, x0: 126, x1: 329, y0: $0.y0, y1: $0.y1, count: 6) }
                        if $0.name == "win" { return Region(name: $0.name, x0: 329, x1: 512, y0: $0.y0, y1: $0.y1, count: 6) }
                        return $0
                    }, portraitX: 136, portraitWidth: 180),
    CharacterImport(id: "herder", board: "herder-elder-demon-beast-atlases.png", columnX: 0, columnWidth: 384, scale: 1.2, regions: herderRegions, portraitX: 105, portraitWidth: 180),
    CharacterImport(id: "elder", board: "herder-elder-demon-beast-atlases.png", columnX: 384, columnWidth: 384, scale: 1.2, regions: elderRegions, portraitX: 106, portraitWidth: 180),
    CharacterImport(id: "demon", board: "herder-elder-demon-beast-atlases.png", columnX: 768, columnWidth: 384, scale: 1.2, regions: demonRegions, portraitX: 170, portraitWidth: 180),
    CharacterImport(id: "flame", board: "flame-swordsman-atlas.png", columnX: 0, columnWidth: 1536, scale: 0.68, regions: flameRegions, portraitX: 120, portraitWidth: 190),
    CharacterImport(id: "beast", board: "herder-elder-demon-beast-atlases.png", columnX: 1152, columnWidth: 384, scale: 1.2, regions: beastRegions, portraitX: 150, portraitWidth: 180)
]

let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceFolder = project.appendingPathComponent("Art/References/Imported", isDirectory: true)
let assetRoot = project.appendingPathComponent("SwordDuel/Resources/Assets/Characters", isDirectory: true)

for spec in imports {
    let source = try load(sourceFolder.appendingPathComponent(spec.board))
    let processed = keyedColumn(source: source, x: spec.columnX, width: spec.columnWidth, yForKey: 230)
    let folder = assetRoot.appendingPathComponent(spec.id, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let imageName = "\(spec.id)_imported"
    try savePNG(processed.image, to: folder.appendingPathComponent("\(imageName).png"))

    // Save a square face portrait from the matching illustrated character panel.
    let portraitRect = CGRect(x: spec.columnX + spec.portraitX, y: 0, width: spec.portraitWidth, height: spec.portraitWidth)
    if let portrait = source.cropping(to: portraitRect) {
        try savePNG(portrait, to: folder.appendingPathComponent("\(spec.id)_portrait.png"))
    }

    var frameTable: [String: Any] = [:]
    var animationTable: [String: [String]] = [:]
    for region in spec.regions {
        // Remove old generated outputs for this animation, including obsolete
        // row atlases and surplus numbered frames after a count correction.
        let framePrefix = "\(spec.id)_\(region.name)_"
        for oldFile in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        where oldFile.pathExtension == "png" && oldFile.deletingPathExtension().lastPathComponent.hasPrefix(framePrefix) {
            try FileManager.default.removeItem(at: oldFile)
        }

        var names: [String] = []
        let slices = frameSlices(processed.rgba, width: spec.columnWidth, region: region)
        var candidates: [(rect: CGRect, x0: Int, x1: Int, opaque: Int)] = []
        for (index, slice) in slices.enumerated() {
            // Composite panels use one-pixel white separators at many half-row
            // and column edges. Keep those guides out of the first/last pose.
            let x0 = slice.x0 + (index == 0 ? 2 : 0)
            let x1 = slice.x1 - (index == slices.count - 1 ? 2 : 0)
            guard let rect = alphaBounds(processed.rgba, width: spec.columnWidth, height: source.height, region: region, x0: x0, x1: x1) else {
                fatalError("No art found for \(spec.id).\(region.name)[\(index)] in \(x0)..<\(x1), \(region.y0)..<\(region.y1)")
            }
            candidates.append((rect, x0, x1, opaqueCount(processed.rgba, width: spec.columnWidth, rect: rect)))
        }

        // A few generated rows print a six-frame label but contain only three
        // complete body poses plus guide fragments. Regular locomotion/reaction
        // states must never blink to a stray line, so weak fragments reuse the
        // nearest complete pose. Every output remains its own PNG.
        let bodyRequired = Set(["idle", "walk", "run", "jump", "crouch_block", "hurt", "ko", "win"])
        let consistentBodySize = Set(["idle", "walk", "run", "win"])
        let sortedOpacity = candidates.map(\.opaque).sorted()
        let medianOpacity = sortedOpacity[sortedOpacity.count / 2]
        let minimumBodyOpacity = max(16, medianOpacity * 45 / 100)
        let maximumBodyOpacity = medianOpacity * 135 / 100
        let validBodyFrames = candidates.indices.filter {
            candidates[$0].opaque >= minimumBodyOpacity &&
            (!consistentBodySize.contains(region.name) || candidates[$0].opaque <= maximumBodyOpacity)
        }

        for index in candidates.indices {
            var sourceIndex = index
            let isWeakFragment = candidates[index].opaque < minimumBodyOpacity
            let containsTwoPoses = consistentBodySize.contains(region.name) && candidates[index].opaque > maximumBodyOpacity
            if bodyRequired.contains(region.name), isWeakFragment || containsTwoPoses,
               let nearest = validBodyFrames.min(by: { abs($0 - index) < abs($1 - index) }) {
                sourceIndex = nearest
            }
            let candidate = candidates[sourceIndex]
            let rect = candidate.rect
            let x0 = candidate.x0
            let x1 = candidate.x1
            let frameName = "\(region.name)_\(index + 1)"
            let frameImageName = "\(spec.id)_\(frameName)"
            guard let frameImage = processed.image.cropping(to: rect) else {
                fatalError("Cannot crop \(spec.id).\(frameName) at \(rect)")
            }
            try savePNG(frameImage, to: folder.appendingPathComponent("\(frameImageName).png"))
            names.append(frameName)
            let pivotX = min(rect.width, max(0, CGFloat(x0 + x1) / 2 - rect.minX))
            let pivotY = min(rect.height, max(0, CGFloat(region.y1 - 1) - rect.minY))
            frameTable[frameName] = [
                "image": frameImageName,
                "rect": ["x": 0, "y": 0, "w": Int(rect.width), "h": Int(rect.height)],
                "pivot": [pivotX, pivotY],
                "scale": spec.scale
            ]
        }
        animationTable[region.name] = names
    }
    let atlas: [String: Any] = ["frames": frameTable, "animations": animationTable, "effects": [String: [String]]()]
    let json = try JSONSerialization.data(withJSONObject: atlas, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: folder.appendingPathComponent("\(spec.id)_atlas.json"))
    print("Imported \(spec.id): \(frameTable.count) frames; key RGB \(processed.key); column \(spec.columnWidth)x\(source.height)")
}
