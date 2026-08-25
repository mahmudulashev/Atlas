import AppKit
import CoreGraphics
import Foundation

// Renders Resources/dmg-background.png and dmg-background@2x.png for the
// distributable DMG installer window.
//
// Designed to match the Atlas aesthetic: warm drafting paper, cartographic
// grid, distinct frosted pods for Atlas.app and Applications, a directional
// cyan-to-magenta bridge, and clean typography.

let width = 660, height = 420
let scale = 2

func render(scaleFactor: Int) -> Data? {
    let w = width * scaleFactor, h = height * scaleFactor
    let s = CGFloat(scaleFactor)

    guard let ctx = CGContext(
        data: nil,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // 1. Base Paper Gradient (#FAF8F4 to #F2EEE5)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let topColor = CGColor(red: 0.980, green: 0.973, blue: 0.957, alpha: 1.0)
    let bottomColor = CGColor(red: 0.949, green: 0.933, blue: 0.898, alpha: 1.0)
    guard let bgGradient = CGGradient(colorsSpace: colorSpace, colors: [topColor, bottomColor] as CFArray, locations: [0.0, 1.0]) else { return nil }
    ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: CGFloat(h)), end: CGPoint(x: 0, y: 0), options: [])

    // 2. Cartographic Drafting Grid
    let gridStep: CGFloat = 22 * s
    ctx.setStrokeColor(CGColor(red: 0.894, green: 0.875, blue: 0.835, alpha: 0.65))
    ctx.setLineWidth(0.75 * s)
    var gx: CGFloat = 0
    while gx <= CGFloat(w) {
        ctx.move(to: CGPoint(x: gx, y: 0))
        ctx.addLine(to: CGPoint(x: gx, y: CGFloat(h)))
        gx += gridStep
    }
    var gy: CGFloat = 0
    while gy <= CGFloat(h) {
        ctx.move(to: CGPoint(x: 0, y: gy))
        ctx.addLine(to: CGPoint(x: CGFloat(w), y: gy))
        gy += gridStep
    }
    ctx.strokePath()

    // 3. Target Pods (Left: Atlas.app at x=165, Right: Applications at x=495)
    // In CoreGraphics (unflipped), center Y = 215 * s
    let podWidth: CGFloat = 144 * s
    let podHeight: CGFloat = 144 * s
    let podRadius: CGFloat = 26 * s
    let podY: CGFloat = (215 * s) - (podHeight / 2)

    let leftPodX = (165 * s) - (podWidth / 2)
    let rightPodX = (495 * s) - (podWidth / 2)

    func drawPod(at origin: CGPoint, label: String, isDestination: Bool) {
        ctx.saveGState()

        let rect = CGRect(origin: origin, size: CGSize(width: podWidth, height: podHeight))
        let path = CGPath(roundedRect: rect, cornerWidth: podRadius, cornerHeight: podRadius, transform: nil)

        // Drop shadow
        ctx.setShadow(offset: CGSize(width: 0, height: -3 * s), blur: 14 * s, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.05))

        // Pod background gradient
        ctx.addPath(path)
        ctx.clip()
        let podTop = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85)
        let podBottom = CGColor(red: 0.970, green: 0.965, blue: 0.950, alpha: 0.70)
        if let podGrad = CGGradient(colorsSpace: colorSpace, colors: [podTop, podBottom] as CFArray, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(podGrad, start: CGPoint(x: origin.x, y: origin.y + podHeight), end: CGPoint(x: origin.x, y: origin.y), options: [])
        }
        ctx.restoreGState()

        // Pod Border
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setStrokeColor(CGColor(red: 0.80, green: 0.78, blue: 0.74, alpha: 0.7))
        ctx.setLineWidth(1.2 * s)
        ctx.strokePath()

        // Inner dashed guide ring
        let inset: CGFloat = 8 * s
        let innerRect = rect.insetBy(dx: inset, dy: inset)
        let innerPath = CGPath(roundedRect: innerRect, cornerWidth: podRadius - 6 * s, cornerHeight: podRadius - 6 * s, transform: nil)
        ctx.addPath(innerPath)
        ctx.setStrokeColor(isDestination ? CGColor(red: 0.839, green: 0.0, blue: 0.424, alpha: 0.25) : CGColor(red: 0.0, green: 0.533, blue: 0.690, alpha: 0.25))
        ctx.setLineWidth(1 * s)
        ctx.setLineDash(phase: 0, lengths: [4 * s, 4 * s])
        ctx.strokePath()
        ctx.restoreGState()
    }

    drawPod(at: CGPoint(x: leftPodX, y: podY), label: "Atlas.app", isDestination: false)
    drawPod(at: CGPoint(x: rightPodX, y: podY), label: "Applications", isDestination: true)

    // 4. Directional Bridge Arrow (Between pods: x=245 to x=415, y=215)
    let bridgeY = 215 * s
    let bridgeStart = 248 * s
    let bridgeEnd = 412 * s

    ctx.saveGState()
    // Arrow line
    ctx.setLineWidth(2.5 * s)
    ctx.setLineCap(.round)
    ctx.setLineDash(phase: 0, lengths: [7 * s, 5 * s])

    // Draw gradient line
    let arrowPath = CGMutablePath()
    arrowPath.move(to: CGPoint(x: bridgeStart, y: bridgeY))
    arrowPath.addLine(to: CGPoint(x: bridgeEnd - 12 * s, y: bridgeY))

    ctx.setStrokeColor(CGColor(red: 0.0, green: 0.533, blue: 0.690, alpha: 0.55))
    ctx.addPath(arrowPath)
    ctx.strokePath()

    // Arrow Tip
    ctx.setLineDash(phase: 0, lengths: [])
    let tip = CGPoint(x: bridgeEnd, y: bridgeY)
    ctx.setFillColor(CGColor(red: 0.839, green: 0.0, blue: 0.424, alpha: 0.85)) // Magenta
    ctx.move(to: tip)
    ctx.addLine(to: CGPoint(x: tip.x - 13 * s, y: bridgeY + 7 * s))
    ctx.addLine(to: CGPoint(x: tip.x - 10 * s, y: bridgeY))
    ctx.addLine(to: CGPoint(x: tip.x - 13 * s, y: bridgeY - 7 * s))
    ctx.closePath()
    ctx.fillPath()
    ctx.restoreGState()

    // 5. Instruction Pill in center of the bridge
    let pillWidth: CGFloat = 124 * s
    let pillHeight: CGFloat = 26 * s
    let pillX = ((CGFloat(w) - pillWidth) / 2)
    let pillY = bridgeY - (pillHeight / 2)
    let pillRect = CGRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)

    ctx.saveGState()
    let pillPath = CGPath(roundedRect: pillRect, cornerWidth: pillHeight / 2, cornerHeight: pillHeight / 2, transform: nil)
    ctx.setShadow(offset: CGSize(width: 0, height: -2 * s), blur: 8 * s, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.06))
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
    ctx.addPath(pillPath)
    ctx.fillPath()

    ctx.setStrokeColor(CGColor(red: 0.0, green: 0.533, blue: 0.690, alpha: 0.35))
    ctx.setLineWidth(1 * s)
    ctx.addPath(pillPath)
    ctx.strokePath()
    ctx.restoreGState()

    // 6. Typography
    let graphics = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics

    // Pill Text
    let pillAttr = NSAttributedString(string: "Drag to install →", attributes: [
        .font: NSFont.systemFont(ofSize: 11 * s, weight: .semibold),
        .foregroundColor: NSColor(srgbRed: 0.0, green: 0.45, blue: 0.60, alpha: 1.0),
    ])
    let pillTextSize = pillAttr.size()
    pillAttr.draw(at: CGPoint(x: pillX + (pillWidth - pillTextSize.width) / 2, y: pillY + (pillHeight - pillTextSize.height) / 2))

    // Title ("Atlas")
    let serifFont: NSFont = {
        let base = NSFont.systemFont(ofSize: 28 * s, weight: .bold)
        if let desc = base.fontDescriptor.withDesign(.serif),
           let f = NSFont(descriptor: desc, size: 28 * s) {
            return f
        }
        return base
    }()

    let titleAttr = NSAttributedString(string: "Atlas", attributes: [
        .font: serifFont,
        .foregroundColor: NSColor(srgbRed: 0.12, green: 0.11, blue: 0.11, alpha: 1.0),
    ])
    let titleSize = titleAttr.size()
    titleAttr.draw(at: CGPoint(x: (CGFloat(w) - titleSize.width) / 2, y: CGFloat(h) * 0.81))

    // Subtitle ("Kodning shaklini koʻr  ·  Explore code structure natively")
    let subAttr = NSAttributedString(string: "Kodning shaklini ko\u{2bb}r  \u{00B7}  Explore codebase visually", attributes: [
        .font: NSFont.systemFont(ofSize: 12.5 * s, weight: .regular),
        .foregroundColor: NSColor(srgbRed: 0.42, green: 0.40, blue: 0.38, alpha: 1.0),
    ])
    let subSize = subAttr.size()
    subAttr.draw(at: CGPoint(x: (CGFloat(w) - subSize.width) / 2, y: CGFloat(h) * 0.74))

    // Bottom Badge ("macOS 14+ • Apple Silicon • Swift 6")
    let badgeAttr = NSAttributedString(string: "macOS 14+  \u{2022}  Apple Silicon  \u{2022}  Native Swift 6", attributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 10.5 * s, weight: .medium),
        .foregroundColor: NSColor(srgbRed: 0.55, green: 0.53, blue: 0.50, alpha: 1.0),
    ])
    let badgeSize = badgeAttr.size()
    badgeAttr.draw(at: CGPoint(x: (CGFloat(w) - badgeSize.width) / 2, y: CGFloat(h) * 0.065))

    NSGraphicsContext.restoreGraphicsState()

    guard let image = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

try? FileManager.default.createDirectory(atPath: "Resources", withIntermediateDirectories: true)
guard let base = render(scaleFactor: 1), let retina = render(scaleFactor: scale) else {
    print("Error rendering background")
    exit(1)
}
try base.write(to: URL(fileURLWithPath: "Resources/dmg-background.png"))
try retina.write(to: URL(fileURLWithPath: "Resources/dmg-background@2x.png"))
print("✓ Rendered DMG backgrounds: Resources/dmg-background.png (\(width)x\(height)) & @2x (\(width*2)x\(height*2))")
