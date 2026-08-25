import SwiftUI

/// The drafting grid the whole window sits on.
///
/// A flat fill reads as an empty container; a ruled ground reads as a working
/// surface, which is the difference between the app feeling like a dialog and
/// feeling like something you work on. Drawn rather than tiled from an image so
/// it stays crisp at any scale factor and follows the theme.
struct PaperBackground: View {
    var spacing: CGFloat = 26

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(Theme.paperGrid), lineWidth: 1)
        }
        .background(Theme.background)
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

/// The three-bar terrain mark used for difficulty.
///
/// A number ("complexity 7") means nothing without a scale to compare it to.
/// Rising bars are read instantly and need no legend.
struct TerrainMark: View {
    let difficulty: GraphNode.Difficulty
    var scale: CGFloat = 1

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5 * scale) {
            ForEach(0..<3, id: \.self) { step in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(step <= difficulty.rawValue ? Theme.color(for: difficulty) : Theme.border)
                    .frame(width: 3 * scale, height: (5 + CGFloat(step) * 3) * scale)
            }
        }
    }
}
