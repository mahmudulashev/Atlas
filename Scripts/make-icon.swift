import AppKit
import CoreGraphics
import Foundation

// Renders Resources/AppIcon.icns.
//
// Drawn in code rather than exported from a design tool so the mark stays sharp
// at every size and the whole build stays reproducible from source alone.
// macOS icons sit inside a rounded square that occupies about 80% of the
// canvas, with the remaining space as breathing room.

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16",      16), ("icon_16x16@2x",    32),
    ("icon_32x32",      32), ("icon_32x32@2x",    64),
    ("icon_128x128",   128), ("icon_128x128@2x", 256),
    ("icon_256x256",   256), ("icon_256x256@2x", 512),
    ("icon_512x512",   512), ("icon_512x512@2x", 1024),
]

// Graph mark: five nodes, six edges. The root is gold, the rest turquoise.
let nodes: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
    (0.50, 0.735, 0.108),
    (0.225, 0.475, 0.078),
    (0.775, 0.495, 0.078),
    (0.375, 0.215, 0.060),
    (0.655, 0.205, 0.060),
]
let edges: [(Int, Int)] = [(0, 1), (0, 2), (1, 3), (2, 4), (3, 4), (1, 2)]

func render(px: Int) -> Data? {
    let size = CGFloat(px)
    guard let ctx = CGContext(data: nil, width: px, height: px,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }

    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // ---- Rounded-square plate ----
    let inset = size * 0.095
    let plate = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let corner = plate.width * 0.235
    let platePath = CGPath(roundedRect: plate, cornerWidth: corner, cornerHeight: corner,
                           transform: nil)

    ctx.saveGState()
    ctx.addPath(platePath)
    ctx.clip()

    let colors = [
        CGColor(red: 0.976, green: 0.973, blue: 0.973, alpha: 1),  // #F9F8F8
        CGColor(red: 0.918, green: 0.914, blue: 0.914, alpha: 1),  // #EAE9E9
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: plate.minX, y: plate.maxY),
                               end: CGPoint(x: plate.maxX, y: plate.minY),
                               options: [])
    }
    ctx.restoreGState()

    // A printed sheet has an edge. Ink hairline, not a light rim.
    ctx.addPath(platePath)
    ctx.setStrokeColor(CGColor(red: 0.125, green: 0.118, blue: 0.114, alpha: 0.22))
    ctx.setLineWidth(max(1, size * 0.007))
    ctx.strokePath()

    // ---- Edges ----
    func point(_ n: (x: CGFloat, y: CGFloat, r: CGFloat)) -> CGPoint {
        CGPoint(x: plate.minX + n.x * plate.width,
                y: plate.minY + n.y * plate.height)
    }

    ctx.setLineCap(.round)
    ctx.setLineWidth(max(1.2, size * 0.021))

    // Downstream, in cyan: the direction the program runs.
    ctx.setStrokeColor(CGColor(red: 0.0, green: 0.533, blue: 0.690, alpha: 0.85))   // #0088B0
    for (a, b) in edges where !(a == 1 && b == 2) {
        ctx.move(to: point(nodes[a]))
        ctx.addLine(to: point(nodes[b]))
    }
    ctx.strokePath()

    // One edge running back up, in magenta — the other half of the pairing.
    ctx.setStrokeColor(CGColor(red: 0.839, green: 0.0, blue: 0.424, alpha: 0.85))   // #D6006C
    ctx.move(to: point(nodes[2]))
    ctx.addLine(to: point(nodes[1]))
    ctx.strokePath()

    // ---- Nodes ----
    for (index, node) in nodes.enumerated() {
        let c = point(node)
        let r = node.r * plate.width
        let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)

        if index == 0 {
            // The entry point is printed solid; the rest are outlined. Weight,
            // not hue — the two inks are spoken for.
            ctx.setFillColor(CGColor(red: 0.125, green: 0.118, blue: 0.114, alpha: 1)) // #201E1D
            ctx.fillEllipse(in: rect)
        } else {
            ctx.setFillColor(CGColor(red: 0.957, green: 0.953, blue: 0.953, alpha: 1))
            ctx.fillEllipse(in: rect)
            ctx.setStrokeColor(CGColor(red: 0.125, green: 0.118, blue: 0.114, alpha: 1))
            ctx.setLineWidth(max(1.2, size * 0.017))
            ctx.strokeEllipse(in: rect.insetBy(dx: size * 0.008, dy: size * 0.008))
        }
    }

    guard let image = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])
}

let iconset = URL(fileURLWithPath: "Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for entry in sizes {
    guard let data = render(px: entry.px) else {
        FileHandle.standardError.write("failed at \(entry.px)\n".data(using: .utf8)!)
        exit(1)
    }
    try data.write(to: iconset.appendingPathComponent("\(entry.name).png"))
}
print("wrote \(sizes.count) sizes")
