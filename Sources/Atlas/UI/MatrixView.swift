import SwiftUI

/// The dependency matrix: rows call columns.
///
/// No crossing lines at any size, so clusters, layers and cycles are read
/// directly off the grid rather than traced through a drawing. A cycle is not
/// inferred from which side of the diagonal a mark falls on — the reciprocal
/// pair is marked in magenta outright, which is both more direct and correct
/// for a pair sitting in the same district.
struct MatrixView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    @State private var selected: Int?

    private let cell: CGFloat = 15
    private let gap: CGFloat = 9
    private let leftGutter: CGFloat = 168
    private let topGutter: CGFloat = 152
    private let barWidth: CGFloat = 62

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 16) {
                header
                Canvas { context, size in
                    draw(context: context, size: size)
                }
                .frame(width: canvas.width, height: canvas.height)
                .contentShape(Rectangle())
                .onTapGesture { point in
                    if let hit = index(at: point) { choose(hit) }
                }
                footer
            }
            .padding(26)
        }
        .background(PaperBackground())
        .onChange(of: state.fileGraph.nodes.count) { _, _ in selected = nil }
        .onChange(of: state.graph?.rootPath) { _, _ in selected = nil }
    }

    // MARK: - Ordering

    /// Grouping and row order come from `MatrixOrder` in the engine, so the
    /// Windows client lays out the same grid. Only the wording and the ink are
    /// decided here.
    private var ordered: MatrixOrder { MatrixOrder(graph: state.fileGraph) }

    private func label(_ district: MatrixOrder.District) -> String {
        switch district.key {
        case "interface": return loc.t.districtInterface
        case "data":      return loc.t.districtData
        default:          return loc.t.districtLogic
        }
    }

    private func ink(_ district: MatrixOrder.District) -> Color {
        switch district.key {
        case "interface": return Theme.inkCyan
        case "data":      return Theme.inkMagenta
        default:          return Theme.textSecondary
        }
    }

    private func position(_ rank: Int, in order: MatrixOrder) -> CGFloat {
        var gaps = 0
        for district in order.districts.dropFirst() where rank >= district.start { gaps += 1 }
        return CGFloat(rank) * cell + CGFloat(gaps) * gap
    }

    private var canvas: CGSize {
        let order = ordered
        guard !order.indices.isEmpty else { return CGSize(width: 400, height: 260) }
        let span = position(order.indices.count - 1, in: order) + cell
        return CGSize(width: leftGutter + span + barWidth + 26, height: topGutter + span + 34)
    }

    // MARK: - Drawing

    private func draw(context: GraphicsContext, size: CGSize) {
        let graph = state.fileGraph
        let order = ordered
        guard !order.indices.isEmpty else { return }
        let count = order.indices.count
        let span = position(count - 1, in: order) + cell

        var calls = Set<Int64>()
        for edge in graph.edges {
            guard let r = order.rank[edge.from], let c = order.rank[edge.to] else { continue }
            calls.insert(Int64(r) << 32 | Int64(c))
        }
        func has(_ r: Int, _ c: Int) -> Bool { calls.contains(Int64(r) << 32 | Int64(c)) }

        let selRank = selected.flatMap { order.rank[$0] }

        // ---- Bands for the selection: the row it calls in cyan, the column
        // that calls it in magenta. The same pairing as everywhere else.
        if let rank = selRank {
            context.fill(Path(CGRect(x: leftGutter, y: topGutter + position(rank, in: order),
                                     width: span, height: cell)),
                         with: .color(Theme.inkCyan.opacity(0.11)))
            context.fill(Path(CGRect(x: leftGutter + position(rank, in: order), y: topGutter,
                                     width: cell, height: span)),
                         with: .color(Theme.inkMagenta.opacity(0.09)))
        }

        // ---- Cells ----
        for r in 0..<count {
            for c in 0..<count {
                let x = leftGutter + position(c, in: order)
                let y = topGutter + position(r, in: order)

                if r == c {
                    // The file itself: a small neutral square, well inside the
                    // cell so it never reads as data.
                    context.fill(Path(CGRect(x: x + 5, y: y + 5, width: 5, height: 5)),
                                 with: .color(Theme.border))
                    continue
                }
                guard has(r, c) else { continue }

                let reciprocal = has(c, r)
                let live = selRank == r || selRank == c
                let ink = reciprocal ? Theme.inkMagenta : Theme.inkCyan
                context.fill(Path(CGRect(x: x + 1, y: y + 1, width: 13, height: 13)),
                             with: .color(ink.opacity(live ? 1 : 0.78)))
            }
        }

        // ---- Fan bars: how many files each row pulls in ----
        let outDegree = order.indices.map { graph.outgoing[$0].count }
        let maxOut = max(outDegree.max() ?? 1, 1)
        for (rank, degree) in outDegree.enumerated() {
            let width = CGFloat(degree) / CGFloat(maxOut) * barWidth
            guard width > 0.5 else { continue }
            context.fill(Path(CGRect(x: leftGutter + span + 10,
                                     y: topGutter + position(rank, in: order) + 4,
                                     width: width, height: 7)),
                         with: .color(Theme.borderStrong))
        }

        // ---- Row labels ----
        for (rank, node) in order.indices.enumerated() {
            let selectedRow = selRank == rank
            let text = Text(graph.nodes[node].name)
                .font(.system(size: 10.5, design: .serif))
                .foregroundStyle(selectedRow ? Theme.textPrimary : Theme.textSecondary)
            context.draw(context.resolve(text),
                         at: CGPoint(x: leftGutter - 10,
                                     y: topGutter + position(rank, in: order) + cell / 2),
                         anchor: .trailing)
        }

        // ---- Column labels, turned ----
        for (rank, node) in order.indices.enumerated() {
            let selectedCol = selRank == rank
            var turned = context
            turned.translateBy(x: leftGutter + position(rank, in: order) + 11, y: topGutter - 6)
            turned.rotate(by: .degrees(-90))
            let text = Text(graph.nodes[node].name)
                .font(.system(size: 10.5, design: .serif))
                .foregroundStyle(selectedCol ? Theme.textPrimary : Theme.textSecondary)
            turned.draw(turned.resolve(text), at: .zero, anchor: .leading)
        }

        // ---- District marks, below the grid ----
        for district in order.districts {
            let text = Text(label(district).uppercased())
                .font(.system(size: 10, weight: .semibold, design: .serif))
                .foregroundStyle(ink(district))
            context.draw(context.resolve(text),
                         at: CGPoint(x: leftGutter + position(district.start, in: order),
                                     y: topGutter + span + 12),
                         anchor: .topLeading)
        }
    }

    // MARK: - Interaction

    private func index(at point: CGPoint) -> Int? {
        let order = ordered
        for (rank, node) in order.indices.enumerated() {
            let o = position(rank, in: order)
            if point.x < leftGutter, point.y >= topGutter + o, point.y < topGutter + o + cell {
                return node
            }
            if point.y < topGutter, point.x >= leftGutter + o, point.x < leftGutter + o + cell {
                return node
            }
            if point.y >= topGutter + o, point.y < topGutter + o + cell, point.x >= leftGutter {
                return node
            }
        }
        return nil
    }

    private func choose(_ node: Int) {
        selected = node
        if let first = state.fileGraph.nodes[node].symbols.first { state.select(first) }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(loc.t.matrixTitle)
                    .font(Theme.Font.heading)
                    .foregroundStyle(Theme.textPrimary)
                Text(loc.t.matrixHint)
                    .font(Theme.Font.micro.weight(.regular))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 520, alignment: .leading)
            }
            Spacer(minLength: 0)
            HStack(spacing: 16) {
                key(Theme.inkCyan, loc.t.matrixCallsKey)
                key(Theme.inkMagenta, loc.t.matrixCycleKey)
                key(Theme.border, loc.t.matrixSelfKey)
            }
        }
    }

    private func key(_ ink: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(ink).frame(width: 10, height: 10)
            Text(text).font(Theme.Font.micro.weight(.regular)).foregroundStyle(Theme.textSecondary)
        }
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 34) {
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.t.selectedRow.uppercased())
                    .font(Theme.Font.label).tracking(1.0)
                    .foregroundStyle(Theme.textTertiary)
                if let sel = selected, sel < state.fileGraph.nodes.count {
                    Text(state.fileGraph.nodes[sel].name)
                        .font(Theme.Font.mono)
                        .foregroundStyle(Theme.textPrimary)
                    Text(loc.t.matrixCounts(out: state.fileGraph.outgoing[sel].count,
                                            in: state.fileGraph.incoming[sel].count))
                        .font(Theme.Font.micro.weight(.regular))
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    Text(loc.t.clickAnyFile)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(width: 250, alignment: .leading)

            Text(loc.t.matrixFooter)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 560, alignment: .leading)
        }
    }
}
