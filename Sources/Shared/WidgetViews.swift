import WidgetKit
import SwiftUI

/// The widget's presentation layer.
///
/// Kept apart from the extension's entry point so the app can render exactly
/// the same views. macOS will not register a third-party extension signed
/// ad-hoc — it requires a Developer ID team identifier — so until the project
/// is signed properly the app shows this preview itself, and the widget code
/// stays real rather than theoretical.

/// One timeline entry: a moment, and whatever the app last recorded.
///
/// Named at length deliberately — SwiftUI ships an `@Entry` macro, and a type
/// called `Entry` collides with it the moment both are in scope.
struct WidgetSnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
}

// MARK: - Palette
//
// The widget cannot reach the app's `Theme`, which depends on AppKit. These are
// the same "Siyoh" values, resolved through SwiftUI's own light/dark handling.

enum WidgetColor {
    static let ink       = Color(.sRGB, red: 0.055, green: 0.086, blue: 0.149)
    static let inkLight  = Color(.sRGB, red: 0.890, green: 0.914, blue: 0.957)
    static let accent    = Color(.sRGB, red: 0.498, green: 0.651, blue: 0.910)
    static let marker    = Color(.sRGB, red: 0.941, green: 0.439, blue: 0.353)
    static let dim       = Color(.sRGB, red: 0.596, green: 0.651, blue: 0.745)
    static let good      = Color(.sRGB, red: 0.400, green: 0.753, blue: 0.541)
}

// MARK: - Views

struct AtlasWidgetView: View {
    /// The size WidgetKit chose, when the extension is hosting the view.
    @Environment(\.widgetFamily) private var environmentFamily

    let entry: WidgetSnapshotEntry

    /// Set when the app renders the view itself: `widgetFamily` is read-only in
    /// the environment, so a preview has to say which size it wants.
    var familyOverride: WidgetFamily? = nil

    private var family: WidgetFamily { familyOverride ?? environmentFamily }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .systemSmall: small(snapshot)
                default:           medium(snapshot)
                }
            } else {
                empty
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [WidgetColor.ink,
                                    WidgetColor.ink.opacity(0.92)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: Small

    private func small(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Mark(size: 13)
                Text(snapshot.projectName)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WidgetColor.inkLight)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            Text(compact(snapshot.symbols))
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetColor.inkLight)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("funksiya")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(WidgetColor.dim)

            Spacer(minLength: 4)

            if snapshot.routeSteps > 0 {
                progress(done: snapshot.routeDone, total: snapshot.routeSteps)
            } else if snapshot.issueCount > 0 {
                issueLine(snapshot)
            }
        }
    }

    // MARK: Medium

    private func medium(_ snapshot: Snapshot) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Mark(size: 14)
                    Text(snapshot.projectName)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(WidgetColor.inkLight)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(snapshot.languages.joined(separator: " · "))
                    .font(.system(size: 9))
                    .foregroundStyle(WidgetColor.dim)
                    .lineLimit(1)

                Spacer(minLength: 6)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    stat(compact(snapshot.symbols), "funksiya")
                    stat(compact(snapshot.files), "fayl")
                }

                Spacer(minLength: 6)

                if snapshot.routeSteps > 0 {
                    progress(done: snapshot.routeDone, total: snapshot.routeSteps)
                }
            }

            Divider().overlay(WidgetColor.dim.opacity(0.25))

            VStack(alignment: .leading, spacing: 5) {
                Text("ENG KOʻP CHAQIRILGAN")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(WidgetColor.dim)

                ForEach(snapshot.topHubs.prefix(3), id: \.name) { hub in
                    HStack(spacing: 5) {
                        Circle().fill(WidgetColor.accent).frame(width: 4, height: 4)
                        Text(hub.name)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(WidgetColor.inkLight)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 2)
                        Text("\(hub.callers)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(WidgetColor.dim)
                    }
                }

                Spacer(minLength: 0)
                if snapshot.issueCount > 0 { issueLine(snapshot) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Pieces

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetColor.inkLight)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(WidgetColor.dim)
        }
    }

    private func progress(done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text("Yoʻnalish")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(WidgetColor.dim)
                Spacer(minLength: 2)
                Text("\(done)/\(total)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(WidgetColor.dim)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(WidgetColor.dim.opacity(0.25))
                    Capsule()
                        .fill(WidgetColor.accent)
                        .frame(width: geo.size.width * min(1, Double(done) / Double(max(total, 1))))
                }
            }
            .frame(height: 3)
        }
    }

    private func issueLine(_ snapshot: Snapshot) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(snapshot.highIssueCount > 0 ? WidgetColor.marker : WidgetColor.good)
                .frame(width: 5, height: 5)
            Text(snapshot.highIssueCount > 0
                 ? "\(snapshot.highIssueCount) muhim"
                 : "\(snapshot.issueCount) eslatma")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(WidgetColor.dim)
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Mark(size: 20)
            Text("Hali loyiha ochilmagan")
                .font(.system(size: 10))
                .foregroundStyle(WidgetColor.dim)
                .multilineTextAlignment(.center)
        }
    }

    private func compact(_ value: Int) -> String {
        if value >= 10_000 { return String(format: "%.0fk", Double(value) / 1000) }
        if value >= 1_000  { return String(format: "%.1fk", Double(value) / 1000) }
        return "\(value)"
    }
}

/// The same node-and-edge mark the app draws, at widget scale.
struct Mark: View {
    var size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let nodes: [CGPoint] = [CGPoint(x: 0.50, y: 0.22), CGPoint(x: 0.20, y: 0.52),
                                    CGPoint(x: 0.80, y: 0.50), CGPoint(x: 0.38, y: 0.82),
                                    CGPoint(x: 0.66, y: 0.80)]
            for (a, b) in [(0, 1), (0, 2), (1, 3), (2, 4), (3, 4)] {
                var path = Path()
                path.move(to: CGPoint(x: nodes[a].x * s, y: nodes[a].y * s))
                path.addLine(to: CGPoint(x: nodes[b].x * s, y: nodes[b].y * s))
                context.stroke(path, with: .color(WidgetColor.accent.opacity(0.5)),
                               lineWidth: max(0.8, s * 0.05))
            }
            for (index, node) in nodes.enumerated() {
                let r = (index == 0 ? 0.13 : 0.09) * s
                let rect = CGRect(x: node.x * s - r, y: node.y * s - r, width: r * 2, height: r * 2)
                context.fill(Circle().path(in: rect),
                             with: .color(index == 0 ? WidgetColor.marker : WidgetColor.accent))
            }
        }
        .frame(width: size, height: size)
    }
}

