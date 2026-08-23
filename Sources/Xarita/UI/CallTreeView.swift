import SwiftUI

/// A focused, readable view of one declaration's immediate neighbourhood.
///
/// This replaces the whole-codebase graph that preceded it. A force-directed
/// layout of a real project produces a hairball: technically correct, visually
/// impressive, and unreadable, because no one can follow sixteen hundred nodes.
/// Here the view never shows more than eleven — five callers, the subject, five
/// callees — laid out in fixed columns so the eye always knows where to look.
struct CallTreeView: View {

    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    private let rowHeight: CGFloat = 30
    private let columnWidth: CGFloat = 176
    private let maxPerSide = 5

    var body: some View {
        if let graph = state.graph,
           let id = state.selection,
           id < graph.nodes.count {

            let node = graph.nodes[id]
            let (allCallers, allCallees) = graph.neighbours(of: id)
            let callers = Array(allCallers.prefix(maxPerSide))
            let callees = Array(allCallees.prefix(maxPerSide))
            let rows = max(1, max(callers.count, callees.count))
            let height = CGFloat(rows) * rowHeight + 34

            ZStack {
                connectors(callers: callers, callees: callees, rows: rows)
                columns(node: node, graph: graph,
                        callers: callers, callees: callees,
                        hiddenCallers: allCallers.count - callers.count,
                        hiddenCallees: allCallees.count - callees.count,
                        rows: rows)
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.surface)
        }
    }

    // MARK: - Geometry

    /// Vertical centre of row `index` within a column holding `count` rows,
    /// centred against the tallest column.
    private func y(index: Int, count: Int, rows: Int) -> CGFloat {
        let blockHeight = CGFloat(count) * rowHeight
        let totalHeight = CGFloat(rows) * rowHeight
        let top = (totalHeight - blockHeight) / 2
        return top + CGFloat(index) * rowHeight + rowHeight / 2
    }

    private func connectors(callers: [Int], callees: [Int], rows: Int) -> some View {
        Canvas { context, size in
            let midX = size.width / 2
            let leftEdge = midX - columnWidth / 2 - 8
            let rightEdge = midX + columnWidth / 2 + 8
            let centreY = CGFloat(rows) * rowHeight / 2 + 17
            let sourceX = midX - columnWidth / 2
            let targetX = midX + columnWidth / 2

            for (i, _) in callers.enumerated() {
                let startY = y(index: i, count: callers.count, rows: rows) + 17
                var path = Path()
                path.move(to: CGPoint(x: leftEdge, y: startY))
                path.addCurve(to: CGPoint(x: sourceX, y: centreY),
                              control1: CGPoint(x: leftEdge + 34, y: startY),
                              control2: CGPoint(x: sourceX - 34, y: centreY))
                context.stroke(path, with: .color(Theme.edgeIncoming.opacity(0.55)), lineWidth: 1.3)
            }

            for (i, _) in callees.enumerated() {
                let endY = y(index: i, count: callees.count, rows: rows) + 17
                var path = Path()
                path.move(to: CGPoint(x: targetX, y: centreY))
                path.addCurve(to: CGPoint(x: rightEdge, y: endY),
                              control1: CGPoint(x: targetX + 34, y: centreY),
                              control2: CGPoint(x: rightEdge - 34, y: endY))
                context.stroke(path, with: .color(Theme.edgeOutgoing.opacity(0.55)), lineWidth: 1.3)
            }
        }
    }

    // MARK: - Columns

    private func columns(node: GraphNode, graph: CodeGraph,
                         callers: [Int], callees: [Int],
                         hiddenCallers: Int, hiddenCallees: Int,
                         rows: Int) -> some View {
        HStack(spacing: 16) {
            column(ids: callers, hidden: hiddenCallers, rows: rows,
                   title: loc.t.callers, tint: Theme.edgeIncoming,
                   empty: loc.t.noCallers, alignment: .trailing)

            CentreChip(node: node)
                .frame(width: columnWidth)

            column(ids: callees, hidden: hiddenCallees, rows: rows,
                   title: loc.t.callees, tint: Theme.edgeOutgoing,
                   empty: loc.t.noCallees, alignment: .leading)
        }
    }

    private func column(ids: [Int], hidden: Int, rows: Int,
                        title: String, tint: Color, empty: String,
                        alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(title.uppercased())
                .font(Theme.Font.micro)
                .tracking(0.6)
                .foregroundStyle(tint.opacity(0.9))
                .frame(height: 17)

            if ids.isEmpty {
                Text(empty)
                    .font(Theme.Font.micro)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(height: CGFloat(rows) * rowHeight, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ForEach(ids, id: \.self) { id in
                        NeighbourChip(id: id, alignment: alignment)
                            .frame(height: rowHeight)
                    }
                    if hidden > 0 {
                        Text("+\(hidden)")
                            .font(Theme.Font.micro)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: CGFloat(rows) * rowHeight,
                       alignment: ids.count == rows ? .top : .center)
            }
        }
        .frame(width: columnWidth)
    }
}

/// The subject of the current view.
private struct CentreChip: View {
    let node: GraphNode

    var body: some View {
        VStack(spacing: 3) {
            Text(node.name)
                .font(Theme.Font.mono.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let container = node.container {
                Text(container)
                    .font(Theme.Font.micro)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.accentMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.accent, lineWidth: 1.4)
        )
    }
}

private struct NeighbourChip: View {
    @EnvironmentObject private var state: AppState
    let id: Int
    let alignment: HorizontalAlignment
    @State private var hovering = false

    var body: some View {
        if let graph = state.graph, id < graph.nodes.count {
            let node = graph.nodes[id]
            Button {
                state.select(id)
            } label: {
                HStack(spacing: 6) {
                    if alignment == .leading {
                        dot(node)
                        label(node)
                    } else {
                        label(node)
                        dot(node)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hovering ? Theme.accentMuted : Theme.surfaceRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
        }
    }

    private func dot(_ node: GraphNode) -> some View {
        Circle()
            .fill(Theme.color(for: node.kind, external: node.isExternal))
            .frame(width: 6, height: 6)
    }

    private func label(_ node: GraphNode) -> some View {
        Text(node.name)
            .font(Theme.Font.monoSmall)
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}
