import SwiftUI
import WidgetKit

/// The Atlas: what this project is, how big, and where to start.
///
/// Set as the opening page of a printed chart — a masthead, a row of figures,
/// then the two things a newcomer actually needs: an ordered way in, and a
/// sense of how the codebase is divided.
struct OverviewView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization
    @EnvironmentObject private var explainer: Explainer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                masthead
                figures
                startHere
                driftSection
                districts
                widgetPreview
            }
            .frame(maxWidth: 780, alignment: .leading)
            .padding(.horizontal, 44)
            .padding(.vertical, 38)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .background(PaperBackground())
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            (Text(loc.t.projectIs + " ")
                .foregroundStyle(Theme.textPrimary)
             + Text(loc.language == .uz ? state.projectKind.uz : state.projectKind.en)
                .foregroundStyle(Theme.inkCyanDeep)
                .fontWeight(.semibold)
             + Text(". " + state.projectKind.explanation(language: loc.language))
                .foregroundStyle(Theme.textSecondary))
                .font(.system(size: 16, design: .serif))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shortPath: String {
        guard let path = state.graph?.rootPath else { return "" }
        return path.replacingOccurrences(of: SharedPaths.realHome.path, with: "~")
    }

    // MARK: - Figures

    private var figures: some View {
        Group {
            if let g = state.graph {
                VStack(alignment: .leading, spacing: 12) {
                    Rule(loc.t.shapeOfIt)
                    HStack(alignment: .top, spacing: 34) {
                        figure(loc.t.count(g.files.count), loc.t.files)
                        figure(loc.t.count(g.totalLines), loc.t.lines)
                        figure(loc.t.count(g.nodes.count), loc.t.symbols)
                        figure(loc.t.count(g.edges.count), loc.t.callEdges)
                        Spacer(minLength: 0)
                    }
                    Text(loc.t.everyFigure)
                        .font(Theme.Font.micro.weight(.regular))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.top, 30)
            }
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(Theme.Font.number)
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(Theme.Font.micro.weight(.regular))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - Start here

    private var startHere: some View {
        Group {
            if let graph = state.graph, !state.route.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Rule(loc.t.startHere)
                    Text(loc.t.startHereBlurb)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 560, alignment: .leading)

                    VStack(spacing: 0) {
                        ForEach(Array(state.route.steps.prefix(4).enumerated()), id: \.offset) { index, step in
                            EntryRow(number: index + 1,
                                     node: graph.nodes[step.nodeID],
                                     where_: place(step.nodeID, graph),
                                     reach: graph.reach(of: step.nodeID),
                                     isLast: index == min(3, state.route.steps.count - 1))
                                .onTapGesture { state.openStep(index) }
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 34)
            }
        }
    }

    private func place(_ id: Int, _ graph: CodeGraph) -> String {
        let node = graph.nodes[id]
        guard node.fileIndex >= 0, node.fileIndex < graph.files.count else { return "" }
        return "\(graph.files[node.fileIndex]):\(node.line)"
    }


    // MARK: - Drift

    /// The only view in the app with a memory. It opens the Atlas because
    /// "what moved since I was away" is the first question on returning to a
    /// project, and nothing else here can answer it.
    private var driftSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Rule(loc.t.driftTitle)
                if let since = state.drift.previousScan {
                    Text(loc.t.driftSince(since))
                        .font(Theme.Font.micro.weight(.regular))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize()
                }
            }

            if state.drift.entries.isEmpty {
                Text(state.drift.previousScan == nil ? loc.t.driftFirst : loc.t.driftNone)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(state.drift.entries) { entry in
                        DriftRow(entry: entry, note: loc.t.driftNote(entry))
                    }
                }
            }
        }
        .padding(.top, 34)
    }

    // MARK: - Districts

    /// How the codebase divides. Files carry a layer already — the diagram
    /// colours by it — but until now nothing said how much of the project sits
    /// in each, which is the first thing you want to know about a stranger's
    /// repository.
    private var districts: some View {
        Group {
            if !state.fileGraph.nodes.isEmpty {
                let groups = district(of: state.fileGraph)
                VStack(alignment: .leading, spacing: 10) {
                    Rule(loc.t.districts)
                    VStack(spacing: 0) {
                        ForEach(groups, id: \.title) { group in
                            DistrictRow(title: group.title, ink: group.ink,
                                        files: group.files, symbols: group.symbols,
                                        share: group.share, names: group.names)
                        }
                    }
                }
                .padding(.top, 34)
            }
        }
    }

    private struct District {
        let title: String
        let ink: Color
        let files: Int
        let symbols: Int
        let share: Double
        let names: String
    }

    private func district(of graph: FileGraph) -> [District] {
        // Three districts, not nine: the reader wants the shape, and the finer
        // layer classification is already carried by the map's colours.
        let buckets: [(String, Color, Set<Layer>)] = [
            (loc.t.districtInterface, Theme.color(for: .initializer), [.ui, .entry]),
            (loc.t.districtLogic,     Theme.textSecondary,           [.logic, .api, .util, .config]),
            (loc.t.districtData,      Theme.color(for: .type),       [.data, .model, .test]),
        ]
        let total = max(graph.nodes.reduce(0) { $0 + $1.symbolCount }, 1)

        return buckets.compactMap { title, ink, layers in
            let members = graph.nodes.filter { layers.contains($0.layer) }
            guard !members.isEmpty else { return nil }
            let symbols = members.reduce(0) { $0 + $1.symbolCount }
            let names = members
                .sorted { $0.fanIn + $0.fanOut > $1.fanIn + $1.fanOut }
                .prefix(3).map(\.name).joined(separator: " · ")
            return District(title: title, ink: ink, files: members.count,
                            symbols: symbols, share: Double(symbols) / Double(total),
                            names: names)
        }
    }

    // MARK: - Widget preview

    private var widgetPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Rule(loc.t.widgetName)
                Text(loc.t.previewBadge.uppercased())
                    .font(Theme.Font.micro.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textTertiary)
            }
            HStack(alignment: .top, spacing: 16) {
                widgetTile(width: 158, height: 158, family: .systemSmall)
                widgetTile(width: 338, height: 158, family: .systemMedium)
                Spacer(minLength: 0)
            }
            Text(loc.t.widgetNeedsSigning)
                .font(Theme.Font.micro.weight(.regular))
                .foregroundStyle(Theme.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 540, alignment: .leading)
        }
        .padding(.top, 38)
    }

    private func widgetTile(width: CGFloat, height: CGFloat, family: WidgetFamily) -> some View {
        AtlasWidgetView(entry: WidgetSnapshotEntry(date: Date(),
                                                    snapshot: state.widgetSnapshot),
                         familyOverride: family)
            .padding(14)
            .frame(width: width, height: height)
            .background(RoundedRectangle(cornerRadius: 16).fill(WidgetColor.ink))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.border, lineWidth: 1))
    }
}

// MARK: - Pieces

/// A section head set as a printed rule: small caps, then a hairline running to
/// the margin.
struct Rule: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        HStack(spacing: 11) {
            Text(title.uppercased())
                .font(Theme.Font.label)
                .tracking(1.1)
                .foregroundStyle(Theme.textSecondary)
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }
}

private struct EntryRow: View {
    @EnvironmentObject private var loc: Localization
    let number: Int
    let node: GraphNode
    let where_: String
    let reach: Int
    let isLast: Bool
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(number)")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 22, alignment: .trailing)

            VStack(alignment: .leading, spacing: 1) {
                Text(node.displayName)
                    .font(Theme.Font.mono.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(where_)
                    .font(Theme.Font.micro.weight(.regular))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer(minLength: 8)

            Text(loc.t.reaches(reach))
                .font(Theme.Font.micro.weight(.regular))
                .foregroundStyle(Theme.inkCyanDeep)
            Text(loc.t.readArrow)
                .font(Theme.Font.micro)
                .foregroundStyle(hovering ? Theme.inkCyan : Theme.textTertiary)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            if !isLast { Rectangle().fill(Theme.borderSoft).frame(height: 1) }
        }
        .background(hovering ? Theme.surfaceRaised : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

private struct DistrictRow: View {
    let title: String
    let ink: Color
    let files: Int
    let symbols: Int
    let share: Double
    let names: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(title)
                .font(Theme.Font.label)
                .tracking(1.0)
                .foregroundStyle(ink)
                .frame(width: 84, alignment: .leading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                // A share bar rather than a percentage: the comparison between
                // districts is the point, not the number.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.borderSoft).frame(height: 6)
                        Rectangle().fill(ink.opacity(0.55))
                            .frame(width: max(2, geo.size.width * share), height: 6)
                    }
                }
                .frame(height: 6)

                Text(names)
                    .font(Theme.Font.micro.weight(.regular))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Text("\(files) · \(symbols)")
                .font(Theme.Font.monoSmall)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 66, alignment: .trailing)
                .padding(.top, 1)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.borderSoft).frame(height: 1) }
    }
}


/// One movement since the last scan.
private struct DriftRow: View {
    let entry: Drift.Entry
    let note: String

    /// Structural regressions take the upstream ink, improvements the
    /// downstream one, and plain growth is set in plain ink. The same two
    /// colours as everywhere else, doing the same job: pointing a direction.
    private var ink: Color {
        if entry.isRegression { return Theme.inkMagentaDeep }
        if entry.isImprovement { return Theme.inkCyanDeep }
        return Theme.textPrimary
    }

    private var figure: String {
        entry.kind == .newCycle ? "+1"
            : (entry.delta > 0 ? "+\(entry.delta)" : "\u{2212}\(abs(entry.delta))")
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(figure)
                .font(.system(size: 17, weight: .semibold, design: .serif).monospacedDigit())
                .foregroundStyle(ink)
                .frame(width: 46, alignment: .trailing)

            VStack(alignment: .leading, spacing: 1) {
                if !entry.subject.isEmpty {
                    Text(entry.subject)
                        .font(Theme.Font.mono.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(note)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.borderSoft).frame(height: 1) }
    }
}
