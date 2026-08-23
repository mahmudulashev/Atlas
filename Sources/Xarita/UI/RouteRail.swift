import SwiftUI

/// The left rail during reading: the route first, everything else after.
///
/// Ordering is the whole point. The previous sidebar led with statistics, which
/// tell a newcomer nothing they can act on. This leads with the path, so the
/// first thing in view is always "here is where you are and what comes next".
struct RouteRail: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.border)
            searchField
            Divider().overlay(Theme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !state.searchText.isEmpty {
                        searchResults
                    } else {
                        routeList
                        elsewhere
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollContentBackground(.hidden)

            Divider().overlay(Theme.border)
            footer
        }
        .background(Theme.surface)
    }

    // MARK: - Header

    private var header: some View {
        Button { state.showOrientation() } label: {
            HStack(spacing: 9) {
                MarkGlyph(size: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.graph?.projectName ?? "—")
                        .font(Theme.Font.heading)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(loc.t.backToOverview)
                        .font(Theme.Font.micro)
                        .foregroundStyle(Theme.accent)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            TextField(loc.t.searchPlaceholder, text: $state.searchText)
                .textFieldStyle(.plain)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.textPrimary)
            if !state.searchText.isEmpty {
                Button { state.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: - Route

    private var routeList: some View {
        Group {
            if let graph = state.graph, !state.route.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    RailLabel(loc.t.routeLabel)
                    ForEach(Array(state.route.steps.enumerated()), id: \.offset) { index, step in
                        RailStep(index: index,
                                 node: graph.nodes[step.nodeID],
                                 isCurrent: state.selection == step.nodeID,
                                 isDone: state.isUnderstood(step.nodeID))
                            .onTapGesture { state.openStep(index) }
                    }
                }
            }
        }
    }

    private var elsewhere: some View {
        Group {
            if let graph = state.graph {
                let onRoute = Set(state.route.nodeIDs)
                let others = graph.hubs(limit: 14).filter { !onRoute.contains($0) }.prefix(8)
                if !others.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        RailLabel(loc.t.everythingElse)
                        ForEach(Array(others), id: \.self) { id in
                            SymbolRow(id: id, trailing: "\(graph.nodes[id].fanIn)")
                        }
                    }
                }
            }
        }
    }

    private var searchResults: some View {
        let results = state.searchResults
        return VStack(alignment: .leading, spacing: 2) {
            RailLabel(loc.t.search)
            if results.isEmpty {
                Text(loc.t.noResults)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 12)
            } else {
                ForEach(results.prefix(50), id: \.self) { SymbolRow(id: $0) }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        let progress = state.routeProgress
        return VStack(spacing: 8) {
            if progress.total > 0 {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(loc.t.readingProgress.uppercased())
                            .font(Theme.Font.micro)
                            .tracking(0.7)
                            .foregroundStyle(Theme.textTertiary)
                        Spacer(minLength: 4)
                        Text("\(progress.done) / \(progress.total)")
                            .font(Theme.Font.micro.monospacedDigit())
                            .foregroundStyle(Theme.textTertiary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.border).frame(height: 3)
                            Capsule()
                                .fill(Theme.accent)
                                .frame(width: geo.size.width
                                       * min(1, Double(progress.done) / Double(max(progress.total, 1))),
                                       height: 3)
                        }
                    }
                    .frame(height: 3)
                }
            }
            HStack {
                LanguageToggle(compact: true)
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    RailButton(icon: "chevron.left", help: loc.t.goBack,
                               enabled: state.canGoBack) { state.goBack() }
                    RailButton(icon: "chevron.right", help: loc.t.goForward,
                               enabled: state.canGoForward) { state.goForward() }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Pieces

struct RailLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.Font.micro)
            .tracking(0.8)
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 12)
            .padding(.bottom, 3)
    }
}

/// A route stop in the rail, keeping the station-on-a-line metaphor compact.
private struct RailStep: View {
    let index: Int
    let node: GraphNode
    let isCurrent: Bool
    let isDone: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(isCurrent ? Theme.marker
                          : (isDone ? Theme.color(for: .easy) : Theme.surface))
                    .frame(width: 9, height: 9)
                Circle()
                    .strokeBorder(isCurrent ? Theme.marker
                                  : (isDone ? Theme.color(for: .easy) : Theme.borderStrong),
                                  lineWidth: 1.5)
                    .frame(width: 9, height: 9)
            }
            .frame(width: 12)

            Text(node.name)
                .font(Theme.Font.monoSmall)
                .foregroundStyle(isCurrent ? Theme.marker : Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            TerrainMark(difficulty: node.difficulty, scale: 0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Rectangle()
                .fill(isCurrent ? Theme.markerMuted : (hovering ? Theme.surfaceRaised : Color.clear))
        )
        .overlay(alignment: .leading) {
            if isCurrent { Rectangle().fill(Theme.marker).frame(width: 2) }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

struct SymbolRow: View {
    @EnvironmentObject private var state: AppState
    let id: Int
    var trailing: String? = nil
    @State private var hovering = false

    var body: some View {
        if let g = state.graph, id < g.nodes.count {
            let node = g.nodes[id]
            Button { state.select(id) } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Theme.color(for: node.kind, external: node.isExternal))
                        .frame(width: 5, height: 5)
                    Text(node.displayName)
                        .font(Theme.Font.monoSmall)
                        .foregroundStyle(state.selection == id ? Theme.accent : Theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    if state.isUnderstood(id) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.color(for: .easy))
                    }
                    if let trailing {
                        Text(trailing)
                            .font(Theme.Font.micro.monospacedDigit())
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Rectangle()
                    .fill(state.selection == id ? Theme.accentMuted
                          : (hovering ? Theme.surfaceRaised : Color.clear)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
        }
    }
}

struct RailButton: View {
    let icon: String
    let help: String
    let enabled: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(enabled ? (hovering ? Theme.accent : Theme.textSecondary)
                                         : Theme.textTertiary.opacity(0.4))
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering = $0 }
        .help(help)
    }
}
