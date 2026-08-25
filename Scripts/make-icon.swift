import AppKit
import CoreGraphics
import Foundation

// Renders Resources/AppIcon.icns and the menu-bar template glyph.
//
// The mark is the app's own idea drawn once: a route of four stops with the
// second one marked — where you are. One ink stroke, three plain stops, one
// magenta marker. Flat vector, no gradient, no bevel.
//
// It simplifies as the tile shrinks, because the same drawing does not survive
// the whole range: three small dots turn to mud long before the stroke does.
// At 32pt the plain stops drop and only the marker stays; at 16pt the route
// loses a segment and the marker grows to carry the mark alone.

// MARK: - Palette

enum Ground { case paper, ink }

/// Which ground ships. The design offers both; paper matches the app, ink holds
/// its own in a dark dock. One line to switch.
let ground: Ground = .paper

let paperColour  = CGColor(red: 0.949, green: 0.933, blue: 0.894, alpha: 1)   // #F2EEE4
let inkColour    = CGColor(red: 0.125, green: 0.118, blue: 0.114, alpha: 1)   // #201E1D
let magentaOnPaper = CGColor(red: 0.839, green: 0.0, blue: 0.424, alpha: 1)   // #D6006C
let magentaOnInk   = CGColor(red: 1.0, green: 0.184, blue: 0.525, alpha: 1)   // #FF2F86

var plateColour: CGColor { ground == .paper ? paperColour : inkColour }
var markColour:  CGColor { ground == .paper ? inkColour : paperColour }
var markerColour: CGColor { ground == .paper ? magentaOnPaper : magentaOnInk }

// MARK: - Geometry
//
// All coordinates are in the design's 100 x 100 space and scaled to the tile.

struct Treatment {
    var route: [CGPoint]
    var stroke: CGFloat
    var plainStops: [CGPoint]
    var stopRadius: CGFloat
    var marker: CGPoint
    var markerKnockout: CGFloat      // ground-coloured disc behind the marker
    var markerRadius: CGFloat
}

/// Picked by the size the icon is *displayed* at, not by its pixel count: a
/// 32 pt icon at 2x is still a 32 pt icon and needs the 32 pt drawing.
func treatment(forPointSize points: Int) -> Treatment {
    switch points {
    case ...16:
        return Treatment(
            route: [CGPoint(x: 26, y: 72), CGPoint(x: 44, y: 42), CGPoint(x: 76, y: 30)],
            stroke: 12,
            plainStops: [],
            stopRadius: 0,
            marker: CGPoint(x: 44, y: 42), markerKnockout: 0, markerRadius: 17)
    case 17...32:
        return Treatment(
            route: [CGPoint(x: 24, y: 73), CGPoint(x: 43, y: 42),
                    CGPoint(x: 62, y: 56), CGPoint(x: 77, y: 28)],
            stroke: 9.5,
            plainStops: [],
            stopRadius: 0,
            marker: CGPoint(x: 43, y: 42), markerKnockout: 15, markerRadius: 11)
    case 33...64:
        return Treatment(
            route: [CGPoint(x: 23, y: 74), CGPoint(x: 42, y: 42),
                    CGPoint(x: 63, y: 57), CGPoint(x: 78, y: 27)],
            stroke: 7.5,
            plainStops: [CGPoint(x: 23, y: 74), CGPoint(x: 78, y: 27)],
            stopRadius: 8,
            marker: CGPoint(x: 42, y: 42), markerKnockout: 12.5, markerRadius: 9.5)
    case 65...128:
        return Treatment(
            route: [CGPoint(x: 22, y: 76), CGPoint(x: 42, y: 42),
                    CGPoint(x: 64, y: 58), CGPoint(x: 80, y: 26)],
            stroke: 6,
            plainStops: [CGPoint(x: 22, y: 76), CGPoint(x: 64, y: 58), CGPoint(x: 80, y: 26)],
            stopRadius: 7.5,
            marker: CGPoint(x: 42, y: 42), markerKnockout: 11, markerRadius: 8.5)
    default:
        return Treatment(
            route: [CGPoint(x: 22, y: 76), CGPoint(x: 42, y: 42),
                    CGPoint(x: 64, y: 58), CGPoint(x: 80, y: 26)],
            stroke: 5.5,
            plainStops: [CGPoint(x: 22, y: 76), CGPoint(x: 64, y: 58), CGPoint(x: 80, y: 26)],
            stopRadius: 7,
            marker: CGPoint(x: 42, y: 42), markerKnockout: 10.5, markerRadius: 8)
    }
}

/// Apple's rounded rectangle is a superellipse, not an arc-cornered box. The
/// difference is invisible at 16 px and obvious at 1024, so it is worth drawing
/// properly rather than reaching for `CGPath(roundedRect:)`.
func squircle(in rect: CGRect, cornerFraction: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let n: CGFloat = 5.0                        // superellipse exponent
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let steps = 256

    for step in 0...steps {
        let t = CGFloat(step) / CGFloat(steps) * 2 * .pi
        let cosT = cos(t), sinT = sin(t)
        let x = cx + a * CGFloat(sign(cosT)) * pow(abs(cosT), 2 / n)
        let y = cy + b * CGFloat(sign(sinT)) * pow(abs(sinT), 2 / n)
        step == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    _ = cornerFraction
    return path
}

func sign(_ value: CGFloat) -> CGFloat { value < 0 ? -1 : 1 }

// MARK: - Rendering

/// `points` is the size the icon is shown at; `pixels` is what we render.
func render(pixels: Int, points: Int, template: Bool = false) -> Data? {
    guard let ctx = CGContext(data: nil, width: pixels, height: pixels,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }

    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    let size = CGFloat(pixels)

    // macOS leaves room around the tile for its own shadow.
    let inset = template ? 0 : size * 0.095
    let plate = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)

    if !template {
        ctx.addPath(squircle(in: plate, cornerFraction: 0.2237))
        ctx.setFillColor(plateColour)
        ctx.fillPath()
    }

    // The mark occupies 68% of the tile, centred.
    let markSpan = plate.width * 0.68
    let markOrigin = CGPoint(x: plate.minX + (plate.width - markSpan) / 2,
                             y: plate.minY + (plate.height - markSpan) / 2)
    let unit = markSpan / 100

    // The design's y axis runs downwards; Core Graphics runs up.
    func point(_ p: CGPoint) -> CGPoint {
        CGPoint(x: markOrigin.x + p.x * unit,
                y: markOrigin.y + (100 - p.y) * unit)
    }

    let t = treatment(forPointSize: points)
    let strokeInk = template ? inkColour : markColour

    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(t.stroke * unit)
    ctx.setStrokeColor(strokeInk)
    ctx.move(to: point(t.route[0]))
    for p in t.route.dropFirst() { ctx.addLine(to: point(p)) }
    ctx.strokePath()

    ctx.setFillColor(strokeInk)
    for stop in t.plainStops {
        let c = point(stop), r = t.stopRadius * unit
        ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    // The marker: a knockout in the ground so the stroke does not run through
    // it, then the magenta disc. A template glyph has no second colour — macOS
    // tints it — so there the marker is simply solid ink.
    let centre = point(t.marker)
    if !template, t.markerKnockout > 0 {
        let r = t.markerKnockout * unit
        ctx.setFillColor(plateColour)
        ctx.fillEllipse(in: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
    }
    let r = t.markerRadius * unit
    ctx.setFillColor(template ? inkColour : markerColour)
    ctx.fillEllipse(in: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))

    guard let image = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

// MARK: - Output

let entries: [(name: String, pixels: Int, points: Int)] = [
    ("icon_16x16",       16,   16), ("icon_16x16@2x",     32,   16),
    ("icon_32x32",       32,   32), ("icon_32x32@2x",     64,   32),
    ("icon_128x128",    128,  128), ("icon_128x128@2x",  256,  128),
    ("icon_256x256",    256,  256), ("icon_256x256@2x",  512,  256),
    ("icon_512x512",    512,  512), ("icon_512x512@2x", 1024,  512),
]

let iconset = URL(fileURLWithPath: "Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for entry in entries {
    guard let data = render(pixels: entry.pixels, points: entry.points) else {
        FileHandle.standardError.write("failed at \(entry.name)\n".data(using: .utf8)!)
        exit(1)
    }
    try data.write(to: iconset.appendingPathComponent("\(entry.name).png"))
}

// The menu-bar glyph: one colour, no magenta, as a macOS template requires.
if let template = render(pixels: 36, points: 16, template: true) {
    try template.write(to: URL(fileURLWithPath: "Resources/MenuBarGlyph.png"))
}

print("wrote \(entries.count) sizes on the \(ground == .paper ? "paper" : "ink") ground, plus the template glyph")
