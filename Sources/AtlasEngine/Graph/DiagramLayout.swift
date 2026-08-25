#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

/// Places the file cards and routes the connectors between them.
///
/// Deliberately *not* force-directed. A physics simulation produces a different
/// picture every run and, on a real dependency graph, a hairball; an
/// architecture diagram has to be stable and readable, which means a layered
/// drawing. Columns come from what a file *is* — entry, interface, logic,
/// storage — so the drawing reads left to right the way the system runs, and
/// within each column the order is chosen to minimise crossing lines.
struct DiagramLayout {

    struct Card {
        let nodeIndex: Int
        var frame: CGRect
        var column: Int
        var row: Int
    }

    struct Connector {
        let from: Int              // card index
        let to: Int
        let weight: Int
        var points: [CGPoint]      // polyline, already orthogonal
        var isBackward: Bool
    }

    private(set) var cards: [Card] = []
    private(set) var connectors: [Connector] = []
    private(set) var columnLabels: [(x: CGFloat, layer: Layer)] = []
    private(set) var canvasSize: CGSize = .zero

    // Card metrics. Rows are sized from content so a card with eight symbols is
    // taller than one with two, exactly as a table card is in a schema diagram.
    static let cardWidth: CGFloat = 208
    static let headerHeight: CGFloat = 34
    static let rowHeight: CGFloat = 21
    static let cardPadBottom: CGFloat = 8
    static let columnGap: CGFloat = 108
    static let rowGap: CGFloat = 24
    static let margin: CGFloat = 48
    static let maxRowsShown = 6

    /// Position in `Layer.allCases`, used to settle ties predictably.
    private static func rank(_ layer: Layer) -> Int {
        Layer.allCases.firstIndex(of: layer) ?? Layer.allCases.count
    }

    static func cardHeight(symbols: Int) -> CGFloat {
        headerHeight + CGFloat(min(symbols, maxRowsShown)) * rowHeight + cardPadBottom
    }

    // MARK: - Build

    init(graph: FileGraph) {
        guard !graph.nodes.isEmpty else { return }

        // ---- 1. Columns from actual dependency depth ----
        // Semantic layers describe what a file *is*; they say nothing about
        // what calls what. Using them as columns sent seventy per cent of the
        // edges backwards, which draws as spaghetti. Depth in the dependency
        // graph puts callers left of callees so nearly every line runs forward.
        // The semantic layer survives as the card's colour, where it belongs.
        let columnOfNode = Self.topologicalColumns(graph: graph)
        let columnCount = (columnOfNode.max() ?? 0) + 1

        var columns: [[Int]] = Array(repeating: [], count: columnCount)
        for index in graph.nodes.indices {
            columns[columnOfNode[index]].append(index)
        }

        // ---- 2. Order within each column to reduce crossings ----
        // Barycentre sweep: repeatedly place each node at the average position
        // of its neighbours in the adjacent column. Four passes is enough to
        // settle a graph this size and keeps the result deterministic.
        var position: [Int: Int] = [:]
        for column in columns {
            for (row, node) in column.enumerated() { position[node] = row }
        }

        for pass in 0..<4 {
            let order = pass % 2 == 0 ? Array(columns.indices) : Array(columns.indices.reversed())
            for c in order {
                let neighbourColumn = pass % 2 == 0 ? c - 1 : c + 1
                guard neighbourColumn >= 0, neighbourColumn < columns.count else { continue }

                columns[c].sort { a, b in
                    barycentre(a, in: graph, position: position) <
                    barycentre(b, in: graph, position: position)
                }
                for (row, node) in columns[c].enumerated() { position[node] = row }
            }
        }

        // ---- 3. Coordinates ----
        var x = Self.margin
        var maxHeight: CGFloat = 0
        var frames: [Int: CGRect] = [:]
        var columnIndex: [Int: Int] = [:]
        var rowIndex: [Int: Int] = [:]

        for (c, column) in columns.enumerated() {
            var y = Self.margin + 26          // room for the column label
            for (row, nodeIndex) in column.enumerated() {
                let height = Self.cardHeight(symbols: graph.nodes[nodeIndex].symbols.count)
                frames[nodeIndex] = CGRect(x: x, y: y, width: Self.cardWidth, height: height)
                columnIndex[nodeIndex] = c
                rowIndex[nodeIndex] = row
                y += height + Self.rowGap
            }
            maxHeight = max(maxHeight, y)
            var tally: [Layer: Int] = [:]
            for nodeIndex in column { tally[graph.nodes[nodeIndex].layer, default: 0] += 1 }
            // On a tie the earlier layer wins, rather than whichever the
            // dictionary happened to yield first — Swift reseeds that per
            // process, so a column of three views and three models was labelled
            // differently on each run. `allCases` runs entry → util, so the tie
            // goes to the layer nearer the start of the system, which is the
            // more useful thing to call a column anyway.
            let dominant = tally.max { a, b in
                a.value != b.value ? a.value < b.value : Self.rank(a.key) > Self.rank(b.key)
            }?.key ?? .logic
            columnLabels.append((x: x, layer: dominant))
            x += Self.cardWidth + Self.columnGap
        }

        cards = graph.nodes.indices.compactMap { index in
            guard let frame = frames[index] else { return nil }
            return Card(nodeIndex: index, frame: frame,
                        column: columnIndex[index] ?? 0, row: rowIndex[index] ?? 0)
        }
        let cardPosition = Dictionary(uniqueKeysWithValues:
            cards.enumerated().map { ($0.element.nodeIndex, $0.offset) })

        canvasSize = CGSize(width: x - Self.columnGap + Self.margin,
                            height: maxHeight - Self.rowGap + Self.margin)

        // ---- 4. Orthogonal connectors ----
        for edge in graph.edges {
            guard let a = cardPosition[edge.from], let b = cardPosition[edge.to] else { continue }
            let source = cards[a].frame
            let target = cards[b].frame
            let backward = cards[b].column <= cards[a].column

            connectors.append(Connector(from: a, to: b, weight: edge.weight,
                                        points: route(from: source, to: target,
                                                      backward: backward),
                                        isBackward: backward))
        }
    }

    /// Longest-path layering over the dependency graph.
    ///
    /// Cycles are broken by ignoring edges that revisit a node still open on
    /// the current path — arbitrary but stable, and unavoidable since a cyclic
    /// graph has no true layering. Depth is capped so one pathological chain
    /// cannot stretch the canvas a mile wide.
    private static func topologicalColumns(graph: FileGraph, maxDepth: Int = 7) -> [Int] {
        var depth = [Int](repeating: 0, count: graph.nodes.count)
        var state = [UInt8](repeating: 0, count: graph.nodes.count)   // 0 new, 1 open, 2 done

        func visit(_ v: Int) -> Int {
            if state[v] == 2 { return depth[v] }
            if state[v] == 1 { return 0 }
            state[v] = 1
            var best = 0
            for w in graph.incoming[v] { best = max(best, visit(w) + 1) }
            depth[v] = min(best, maxDepth)
            state[v] = 2
            return depth[v]
        }
        for v in graph.nodes.indices { _ = visit(v) }
        return depth
    }

    private func barycentre(_ node: Int, in graph: FileGraph, position: [Int: Int]) -> Double {
        let neighbours = graph.outgoing[node] + graph.incoming[node]
        let known = neighbours.compactMap { position[$0] }
        guard !known.isEmpty else { return Double(position[node] ?? 0) }
        return Double(known.reduce(0, +)) / Double(known.count)
    }

    /// An elbow from the right edge of one card to the left edge of the next.
    ///
    /// Edges that point backwards — a later layer calling an earlier one — leave
    /// and re-enter on the same sides but detour above the cards, so they read
    /// as going against the flow instead of cutting through it.
    private func route(from source: CGRect, to target: CGRect, backward: Bool) -> [CGPoint] {
        let start = CGPoint(x: source.maxX, y: source.midY)
        let end = CGPoint(x: target.minX, y: target.midY)

        if !backward {
            let midX = (start.x + end.x) / 2
            if abs(start.y - end.y) < 1 { return [start, end] }
            return [start,
                    CGPoint(x: midX, y: start.y),
                    CGPoint(x: midX, y: end.y),
                    end]
        }

        // Backward: exit right, climb above both cards, come back and enter left.
        let lift = min(source.minY, target.minY) - 22
        let outX = source.maxX + 26
        let inX = target.minX - 26
        return [start,
                CGPoint(x: outX, y: start.y),
                CGPoint(x: outX, y: lift),
                CGPoint(x: inX, y: lift),
                CGPoint(x: inX, y: end.y),
                end]
    }
}
