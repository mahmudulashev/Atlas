import SwiftUI

/// The dependency matrix: who depends on whom, with no lines at all.
///
/// The ladder draws arrows, and arrows are what eventually defeat every graph
/// drawing — past a certain density they cross, and no layout fixes it. A
/// matrix has no such limit: every file is a row and the same file is a column,
/// a mark at (row, column) means the row depends on the column, and the picture
/// stays exactly as readable at six hundred files as at six.
///
/// Two things fall out of it for free. Everything below the diagonal is a
/// backward dependency, so **a cycle is a pair of marks reflected across the
/// diagonal** — visible at a glance rather than traced. And sorting by district
/// puts the program's layering on the diagonal, so a block of marks off in the
/// corner is a layer reaching somewhere it should not.
struct MatrixView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    @State private var hovered: Int?
    @State private var scale: CGFloat = 1

    private let cell: CGFloat = 15
    private let groupGap: CGFloat = 9
    private let leftGutter: CGFloat = 152
    private let topGutter: CGFloat = 132

    var body: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical]) {
                Canvas { context, size in
                    draw(context: context, size: size)
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point): hovered = index(at: point)
                    case .ended:             hovered = nil
                    }
                }
                .onTapGesture { point in
                    if let i = index(at: point) { open(i) }
                }
                .padding(20)
            }
            .background(PaperBackground())
            .overlay(alignment: .bottomLeading) { key.padding(16) }
            .overlay(alignment: .bottomTrailing) { summary.padding(16) }
        }
    }

    // MARK: - Ordering

    /// Files ordered by district, then by how much they declare. The order is
    /// the whole information design: it is what puts the layering on the
    /// diagonal.
    private struct Ordered {
        var indices: [Int] = []          // into fileGraph.nodes
        var position: [Int: Int] = [:]   // node index -> rank
        var groupStarts: [Int] = []      // rank where each district begins
        var groupLabels: [String] = []
    }

    private var ordered: Ordered {
        let graph = state.fileGraph
        let buckets: [(String, [Layer])] = [
            (loc.t.districtInterface, [.ui, .entry]),
            (loc.t.districtLogic,     [.logic, .api, .util, .config]),
            (loc.t.districtData,      [.data, .model, .test]),
        ]

        var result = Ordered()
        for (label, layers) in buckets {
            let members = graph.nodes.indices
                .filter { layers.contains(graph.nodes[$0].layer) }
                .sorted { graph.nodes[$0].symbolCount > graph.nodes[$1].symbolCount }
            guard !members.isEmpty else { continue }
            result.groupStarts.append(result.indices.count)
            result.groupLabels.append(label)
            result.indices.append(contentsOf: members)
        }
        for (rank, node) in result.indices.enumerated() { result.position[node] = rank }
        return result
    }

    private func offset(forRank rank: Int, in order: Ordered) -> CGFloat {
        var gaps = 0
        for start in order.groupStarts.dropFirst() where rank >= start { gaps += 1 }
        return CGFloat(rank) * cell + CGFloat(gaps) * groupGap
    }

    private var canvasSize: CGSize {
        let order = ordered
        guard !order.indices.isEmpty else { return CGSize(width: 400, height: 300) }
        let span = offset(forRank: order.indices.count - 1, in: order) + cell
        return CGSize(width: leftGutter + span + 24, height: topGutter + span + 24)
    }

    // MARK: - Drawing

    private func draw(context: GraphicsContext, size: CGSize) {
        let graph = state.fileGraph
        let order = ordered
        guard !order.indices.isEmpty else { return }

        // Dependencies as a lookup, so each cell is a constant-time question.
        var depends = Set<Int64>()
        var weight: [Int64: Int] = [:]
        for edge in graph.edges {
            guard let r = order.position[edge.from], let c = order.position[edge.to] else { continue }
            let key = Int64(r) << 32 | Int64(c)
            depends.insert(key)
            weight[key] = edge.weight
        }

        let count = order.indices.count
        let hoverRank = hovered.flatMap { order.position[$0] }

        // ---- District bands ----
        for (i, start) in order.groupStarts.enumerated() {
            let end = i + 1 < order.groupStarts.count ? order.groupStarts[i + 1] : count
            let x0 = leftGutter + offset(forRank: start, in: order)
            let x1 = leftGutter + offset(forRank: end - 1, in: order) + cell
            let y0 = topGutter + offset(forRank: start, in: order)
            let y1 = topGutter + offset(forRank: end - 1, in: order) + cell

            // The diagonal block for this district — its own internal wiring.
            context.fill(Path(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)),
                         with: .color(Theme.surfaceRaised.opacity(0.55)))

            let label = Text(order.groupLabels[i].uppercased())
                .font(Theme.Font.label)
                .foregroundStyle(Theme.textTertiary)
            context.draw(context.resolve(label),
                         at: CGPoint(x: x0, y: topGutter - 14), anchor: .bottomLeading)
        }

        // ---- Grid ----
        var grid = Path()
        for rank in 0...count {
            let o = rank < count ? offset(forRank: rank, in: order)
                                 : offset(forRank: count - 1, in: order) + cell
            grid.move(to: CGPoint(x: leftGutter + o, y: topGutter))
            grid.addLine(to: CGPoint(x: leftGutter + o, y: topGutter + offset(forRank: count - 1, in: order) + cell))
            grid.move(to: CGPoint(x: leftGutter, y: topGutter + o))
            grid.addLine(to: CGPoint(x: leftGutter + offset(forRank: count - 1, in: order) + cell, y: topGutter + o))
        }
        context.stroke(grid, with: .color(Theme.border.opacity(0.5)), lineWidth: 0.5)

        // ---- Cross-hairs for the hovered file ----
        if let rank = hoverRank {
            let o = offset(forRank: rank, in: order)
            let span = offset(forRank: count - 1, in: order) + cell
            // The row is what this file calls — cyan. The column is what calls
            // it — magenta. Same pairing as everywhere else.
            context.fill(Path(CGRect(x: leftGutter, y: topGutter + o, width: span, height: cell)),
                         with: .color(Theme.inkCyan.opacity(0.10)))
            context.fill(Path(CGRect(x: leftGutter + o, y: topGutter, width: cell, height: span)),
                         with: .color(Theme.inkMagenta.opacity(0.10)))
        }

        // ---- Marks ----
        for r in 0..<count {
            for c in 0..<count {
                let key = Int64(r) << 32 | Int64(c)
                let x = leftGutter + offset(forRank: c, in: order)
                let y = topGutter + offset(forRank: r, in: order)

                if r == c {
                    // The diagonal is the file itself: a hairline, so the eye
                    // reads the layering blocks without mistaking it for data.
                    context.fill(Path(CGRect(x: x + cell / 2 - 0.5, y: y + 2,
                                             width: 1, height: cell - 4)),
                                 with: .color(Theme.border))
                    continue
                }
                guard depends.contains(key) else { continue }

                let below = r > c                    // a backward dependency
                let weightValue = weight[key] ?? 1
                let strength = min(1.0, 0.35 + Double(weightValue) / 14.0)

                var ink: Color = Theme.textPrimary.opacity(strength * 0.72)
                if let rank = hoverRank {
                    if r == rank { ink = Theme.inkCyan.opacity(min(1, strength + 0.25)) }
                    else if c == rank { ink = Theme.inkMagenta.opacity(min(1, strength + 0.25)) }
                    else { ink = Theme.textPrimary.opacity(strength * 0.16) }
                }

                let inset: CGFloat = below ? 3.5 : 2.5
                let rect = CGRect(x: x + inset, y: y + inset,
                                  width: cell - inset * 2, height: cell - inset * 2)
                if below {
                    // Backward dependencies are drawn hollow: they are the ones
                    // worth counting, and an outline reads as an exception.
                    context.stroke(Path(rect), with: .color(ink), lineWidth: 1.4)
                } else {
                    context.fill(Path(rect), with: .color(ink))
                }
            }
        }

        // ---- Row labels ----
        for (rank, nodeIndex) in order.indices.enumerated() {
            let node = graph.nodes[nodeIndex]
            let y = topGutter + offset(forRank: rank, in: order) + cell / 2
            let isHot = hoverRank == rank

            let label = Text(node.name)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(isHot ? Theme.textPrimary : Theme.textSecondary)
            context.draw(context.resolve(label),
                         at: CGPoint(x: leftGutter - 9, y: y), anchor: .trailing)
        }

        // ---- Column labels, turned on their side ----
        for (rank, nodeIndex) in order.indices.enumerated() {
            let node = graph.nodes[nodeIndex]
            let x = leftGutter + offset(forRank: rank, in: order) + cell / 2
            let isHot = hoverRank == rank

            var turned = context
            turned.translateBy(x: x, y: topGutter - 9)
            turned.rotate(by: .degrees(-90))
            let label = Text(node.name)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(isHot ? Theme.textPrimary : Theme.textSecondary)
            turned.draw(turned.resolve(label), at: .zero, anchor: .leading)
        }
    }

    // MARK: - Interaction

    private func index(at point: CGPoint) -> Int? {
        let order = ordered
        let local = CGPoint(x: point.x - 20, y: point.y - 20)   // undo the padding
        guard !order.indices.isEmpty else { return nil }

        // Hovering a label or a cell both select the file the pointer is over.
        for (rank, nodeIndex) in order.indices.enumerated() {
            let o = offset(forRank: rank, in: order)
            if local.x < leftGutter, local.y >= topGutter + o, local.y < topGutter + o + cell {
                return nodeIndex
            }
            if local.y < topGutter, local.x >= leftGutter + o, local.x < leftGutter + o + cell {
                return nodeIndex
            }
        }
        guard local.x >= leftGutter, local.y >= topGutter else { return nil }
        for (rank, nodeIndex) in order.indices.enumerated() {
            let o = offset(forRank: rank, in: order)
            if local.y >= topGutter + o, local.y < topGutter + o + cell { return nodeIndex }
        }
        return nil
    }

    private func open(_ nodeIndex: Int) {
        guard nodeIndex < state.fileGraph.nodes.count,
              let first = state.fileGraph.nodes[nodeIndex].symbols.first else { return }
        state.select(first)
    }

    // MARK: - Overlays

    private var key: some View {
        VStack(alignment: .leading, spacing: 5) {
            keyRow(filled: true, ink: Theme.textPrimary, text: loc.t.matrixKeyForward)
            keyRow(filled: false, ink: Theme.textPrimary, text: loc.t.matrixKeyBackward)
            HStack(spacing: 6) {
                Rectangle().fill(Theme.inkCyan.opacity(0.35)).frame(width: 9, height: 9)
                Text(loc.t.matrixKeyRow).font(Theme.Font.micro.weight(.regular))
                    .foregroundStyle(Theme.textSecondary)
                Rectangle().fill(Theme.inkMagenta.opacity(0.35)).frame(width: 9, height: 9)
                Text(loc.t.matrixKeyColumn).font(Theme.Font.micro.weight(.regular))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Rectangle().fill(Theme.surface.opacity(0.96)))
        .overlay(Rectangle().strokeBorder(Theme.border, lineWidth: 1))
    }

    private func keyRow(filled: Bool, ink: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Group {
                if filled { Rectangle().fill(ink.opacity(0.7)) }
                else { Rectangle().strokeBorder(ink.opacity(0.7), lineWidth: 1.3) }
            }
            .frame(width: 9, height: 9)
            Text(text).font(Theme.Font.micro.weight(.regular)).foregroundStyle(Theme.textSecondary)
        }
    }

    private var summary: some View {
        let backward = state.fileGraph.edges.filter { a in
            guard let r = ordered.position[a.from], let c = ordered.position[a.to] else { return false }
            return r > c
        }.count
        return HStack(spacing: 12) {
            Text("\(state.fileGraph.nodes.count) \(loc.t.files.lowercased())")
            Text("\(state.fileGraph.edges.count) \(loc.t.connections.lowercased())")
            Text("\(backward) \(loc.t.backward)")
                .foregroundStyle(backward > 0 ? Theme.inkMagentaDeep : Theme.textSecondary)
        }
        .font(Theme.Font.micro.weight(.regular))
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Rectangle().fill(Theme.surface.opacity(0.96)))
        .overlay(Rectangle().strokeBorder(Theme.border, lineWidth: 1))
    }
}
