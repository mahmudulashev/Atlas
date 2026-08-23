import SwiftUI
import WidgetKit

/// What the reader sees the moment a project finishes analysing.
///
/// Answers the three questions a newcomer actually has, in order: what is this,
/// how big is it, and where do I start. Dropping someone straight into a
/// function answers none of them.
struct OrientationView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization
    @EnvironmentObject private var explainer: Explainer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heading
                facts
                routeSection
                widgetPreview
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 44)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .background(PaperBackground())
    }

    // MARK: - Heading

    private var heading: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(state.graph?.projectName ?? "—")
                    .font(Theme.Font.display)
                    .foregroundStyle(Theme.textPrimary)
                Text(shortPath)
                    .font(Theme.Font.monoSmall)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
                Spacer(minLength: 0)
            }

            // The category, then a sentence explaining the category itself —
            // "framework" is not a word a beginner necessarily knows either.
            (Text(loc.t.projectIs + " ")
                .foregroundStyle(Theme.textPrimary)
             + Text(loc.language == .uz ? state.projectKind.uz : state.projectKind.en)
                .foregroundStyle(Theme.accent)
                .fontWeight(.semibold)
             + Text(". " + state.projectKind.explanation(language: loc.language))
                .foregroundStyle(Theme.textSecondary))
                .font(.system(size: 17))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shortPath: String {
        guard let path = state.graph?.rootPath else { return "" }
        return path.replacingOccurrences(of: SharedPaths.realHome.path, with: "~")
    }

    // MARK: - Facts

    private var facts: some View {
        Group {
            if let g = state.graph {
                HStack(alignment: .top, spacing: 30) {
                    fact(loc.t.count(g.files.count), loc.t.files)
                    fact(loc.t.count(g.totalLines), loc.t.lines)
                    fact(loc.t.count(g.nodes.count), loc.t.symbols)
                    fact(loc.t.seconds(g.parseSeconds), loc.t.parseTime)
                    if !state.route.isEmpty {
                        fact("\(state.route.steps.count)", loc.t.stepWord)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 20)
                .overlay(alignment: .top) { Rectangle().fill(Theme.borderSoft).frame(height: 1) }
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.borderSoft).frame(height: 1) }
                .padding(.top, 28)
            }
        }
    }

    private func fact(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.Font.number)
                .foregroundStyle(Theme.textPrimary)
            Text(label.uppercased())
                .font(Theme.Font.micro)
                .tracking(0.8)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - Route

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Text(loc.t.suggestedRoute)
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 0)
                if !state.route.isEmpty {
                    Button(loc.t.beginReading) { state.beginReading() }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.top, 30)

            Text(state.route.isEmpty ? loc.t.routeEmpty : loc.t.routeHint)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textTertiary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .padding(.bottom, 18)

            if let graph = state.graph {
                VStack(spacing: 0) {
                    ForEach(Array(state.route.steps.enumerated()), id: \.offset) { index, step in
                        RouteRow(index: index,
                                 node: graph.nodes[step.nodeID],
                                 file: fileName(step.nodeID, graph),
                                 isCurrent: state.selection == step.nodeID,
                                 isDone: state.isUnderstood(step.nodeID),
                                 isLast: index == state.route.steps.count - 1)
                            .onTapGesture { state.openStep(index) }
                    }
                }
            }
        }
    }


    // MARK: - Widget preview

    /// Renders the real widget views at their real sizes.
    ///
    /// macOS will not register a third-party extension signed ad-hoc — it wants
    /// a Developer ID team identifier — so the widget cannot appear in
    /// Notification Centre on an unsigned build. The extension is built and
    /// embedded regardless; this shows exactly what it renders, using the same
    /// view code the extension runs.
    private var widgetPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(loc.t.widgetName)
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.textPrimary)
                Text(loc.t.previewBadge.uppercased())
                    .font(Theme.Font.micro.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Theme.gold, lineWidth: 1))
                Spacer(minLength: 0)
            }

            HStack(alignment: .top, spacing: 16) {
                widgetTile(width: 158, height: 158, family: .systemSmall)
                widgetTile(width: 338, height: 158, family: .systemMedium)
                Spacer(minLength: 0)
            }

            Text(loc.t.widgetNeedsSigning)
                .font(Theme.Font.micro)
                .foregroundStyle(Theme.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 520, alignment: .leading)
        }
        .padding(.top, 34)
    }

    private func widgetTile(width: CGFloat, height: CGFloat,
                            family: WidgetFamily) -> some View {
        XaritaWidgetView(entry: WidgetSnapshotEntry(date: Date(),
                                                    snapshot: state.widgetSnapshot),
                         familyOverride: family)
            .padding(14)
            .frame(width: width, height: height)
            .background(RoundedRectangle(cornerRadius: 18).fill(WidgetColor.ink))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func fileName(_ id: Int, _ graph: CodeGraph) -> String {
        let node = graph.nodes[id]
        guard node.fileIndex >= 0, node.fileIndex < graph.files.count else { return "" }
        return graph.files[node.fileIndex]
    }
}

/// One stop on the route, drawn as a station on a line.
private struct RouteRow: View {
    @EnvironmentObject private var loc: Localization

    let index: Int
    let node: GraphNode
    let file: String
    let isCurrent: Bool
    let isDone: Bool
    let isLast: Bool

    @State private var hovering = false

    private var dotColor: Color {
        if isCurrent { return Theme.marker }
        if isDone { return Theme.color(for: .easy) }
        return Theme.surface
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // The line and its station marker.
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 13, height: 13)
                    Circle()
                        .strokeBorder(isCurrent ? Theme.marker
                                      : (isDone ? Theme.color(for: .easy) : Theme.borderStrong),
                                      lineWidth: 2)
                        .frame(width: 13, height: 13)
                    if isCurrent {
                        Circle()
                            .stroke(Theme.marker.opacity(0.25), lineWidth: 4)
                            .frame(width: 19, height: 19)
                    }
                }
                .frame(height: 20)

                if !isLast {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(node.displayName)
                        .font(Theme.Font.mono.weight(.medium))
                        .foregroundStyle(isCurrent ? Theme.marker : Theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if isCurrent {
                        Text(loc.t.youAreHere.uppercased())
                            .font(Theme.Font.micro.weight(.bold))
                            .tracking(0.9)
                            .foregroundStyle(Theme.marker)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .overlay(RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(Theme.marker, lineWidth: 1))
                    }
                    Spacer(minLength: 4)
                    TerrainMark(difficulty: node.difficulty)
                }

                Text(subtitle)
                    .font(Theme.Font.micro)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hovering ? Theme.surfaceRaised : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    /// Facts rather than prose: the counts are always true, and they are what
    /// tells the reader whether this stop is a detour or the main road.
    private var subtitle: String {
        var bits: [String] = ["\(node.span) \(loc.t.lines.lowercased())"]
        if node.fanOut > 0 {
            bits.append(loc.language == .uz ? "\(node.fanOut) ta chaqiruv"
                                            : "\(node.fanOut) calls")
        }
        if !file.isEmpty { bits.append(file) }
        return bits.joined(separator: "  ·  ")
    }
}
