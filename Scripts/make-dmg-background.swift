import AppKit
import CoreGraphics
import Foundation

// Draws the disk-image window background: drafting paper, the app mark, and an
// arrow pointing from where the app icon sits to the Applications alias. Made
// in code so it matches the app's palette exactly and needs no asset checked in.

let width = 600, height = 400
let scale = 2                       // @2x, so the image is crisp on Retina

func render(scaleFactor: Int) -> Data? {
    let w = width * scaleFactor, h = height * scaleFactor
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    let s = CGFloat(scaleFactor)
    ctx.setAllowsAntialiasing(true)

    // Ground
    ctx.setFillColor(CGColor(red: 0.937, green: 0.945, blue: 0.961, alpha: 1))   // #EFF1F5
    ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))

    // Drafting grid
    ctx.setStrokeColor(CGColor(red: 0.890, green: 0.910, blue: 0.945, alpha: 1)) // #E3E8F1
    ctx.setLineWidth(1 * s)
    let step: CGFloat = 26 * s
    var x: CGFloat = 0
    while x <= CGFloat(w) { ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: CGFloat(h))); x += step }
    var y: CGFloat = 0
    while y <= CGFloat(h) { ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: CGFloat(w), y: y)); y += step }
    ctx.strokePath()

    // Arrow from the app icon towards the Applications alias.
    let arrowY = CGFloat(h) * 0.52
    ctx.setStrokeColor(CGColor(red: 0.169, green: 0.298, blue: 0.529, alpha: 0.45)) // #2B4C87
    ctx.setLineWidth(2 * s)
    ctx.setLineCap(.round)
    ctx.setLineDash(phase: 0, lengths: [7 * s, 6 * s])
    ctx.move(to: CGPoint(x: CGFloat(w) * 0.38, y: arrowY))
    ctx.addLine(to: CGPoint(x: CGFloat(w) * 0.60, y: arrowY))
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])

    let tip = CGPoint(x: CGFloat(w) * 0.615, y: arrowY)
    ctx.setFillColor(CGColor(red: 0.169, green: 0.298, blue: 0.529, alpha: 0.6))
    ctx.move(to: tip)
    ctx.addLine(to: CGPoint(x: tip.x - 11 * s, y: arrowY + 6 * s))
    ctx.addLine(to: CGPoint(x: tip.x - 11 * s, y: arrowY - 6 * s))
    ctx.closePath()
    ctx.fillPath()

    // Wordmark
    let title = NSAttributedString(string: "Xarita", attributes: [
        .font: NSFont.systemFont(ofSize: 25 * s, weight: .semibold),
        .foregroundColor: NSColor(srgbRed: 0.055, green: 0.086, blue: 0.149, alpha: 1),
    ])
    let subtitle = NSAttributedString(string: "Kodning shaklini ko\u{2bb}r", attributes: [
        .font: NSFont.systemFont(ofSize: 12.5 * s, weight: .regular),
        .foregroundColor: NSColor(srgbRed: 0.290, green: 0.337, blue: 0.420, alpha: 1),
    ])

    let graphics = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let titleSize = title.size()
    title.draw(at: CGPoint(x: (CGFloat(w) - titleSize.width) / 2, y: CGFloat(h) * 0.80))
    let subtitleSize = subtitle.size()
    subtitle.draw(at: CGPoint(x: (CGFloat(w) - subtitleSize.width) / 2, y: CGFloat(h) * 0.745))
    NSGraphicsContext.restoreGraphicsState()

    guard let image = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

try? FileManager.default.createDirectory(atPath: "Resources", withIntermediateDirectories: true)
guard let base = render(scaleFactor: 1), let retina = render(scaleFactor: scale) else { exit(1) }
try base.write(to: URL(fileURLWithPath: "Resources/dmg-background.png"))
try retina.write(to: URL(fileURLWithPath: "Resources/dmg-background@2x.png"))
print("wrote dmg background \(width)x\(height) and @2x")
