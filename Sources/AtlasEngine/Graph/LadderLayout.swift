#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

/// Places the files of the call ladder.
///
/// Columns are dependency depth — nothing calls the first column, and nothing
/// in the last calls anything — so every link runs left to right and a line
/// going backwards is a cycle, impossible to miss.
///
/// Rows are deliberately small. An earlier version drew each file as a card
/// listing its symbols, which put eight files on screen; at a row apiece the
/// same space holds the whole project, and seeing all of it at once is the
/// entire point of the view.
///
/// This lives in the engine rather than in a view because two clients draw it
/// now. The picture is the product — if macOS and Windows each computed their
/// own depths and sweeps, the same repository would be two different diagrams
/// and neither could be trusted as *the* map.
struct LadderLayout: Sendable {

    // The design's grid.
    static let columnWidth: CGFloat = 156
    static let boxWidth: CGFloat = 132
    static let boxHeight: CGFloat = 21
    static let verticalGap: CGFloat = 5
    static let headRoom: CGFloat = 36

    /// Node indices per column, in the order they are stacked.
    private(set) var columns: [[Int]] = []
    /// Where each node sits, keyed by its index in the file graph.
    private(set) var frame: [Int: CGRect] = [:]
    private(set) var canvas: CGSize = .zero

    var isEmpty: Bool { frame.isEmpty }

    init() {}

    init(graph: FileGraph) {
        guard !graph.nodes.isEmpty else { return }

        // ---- 1. Depth by longest path, capped ----
        let maxDepth = 5
        var depth = [Int](repeating: 0, count: graph.nodes.count)
        for _ in 0..<12 {
            for edge in graph.edges where depth[edge.to] < depth[edge.from] + 1 {
                depth[edge.to] = min(maxDepth, depth[edge.from] + 1)
            }
        }

        var columns: [[Int]] = Array(repeating: [], count: maxDepth + 1)
        for index in graph.nodes.indices { columns[depth[index]].append(index) }

        // ---- 2. Seed the order by district, then by size ----
        let districtRank: [Layer: Int] = [
            .entry: 0, .ui: 0, .api: 1, .logic: 1, .util: 1, .config: 1,
            .model: 2, .data: 2, .test: 2,
        ]
        func rank(_ i: Int) -> Int { districtRank[graph.nodes[i].layer] ?? 1 }

        for c in columns.indices {
            columns[c].sort {
                rank($0) != rank($1) ? rank($0) < rank($1)
                                     : graph.nodes[$0].symbolCount > graph.nodes[$1].symbolCount
            }
        }

        // ---- 3. Barycentre sweeps to reduce crossings ----
        var row: [Int: Int] = [:]
        for column in columns { for (i, node) in column.enumerated() { row[node] = i } }

        for sweep in 0..<6 {
            let downward = sweep % 2 == 0
            for c in columns.indices {
                if downward && c == 0 { continue }
                if !downward && c == columns.count - 1 { continue }
                var scores: [Int: Double] = [:]
                for node in columns[c] {
                    let related = downward ? graph.incoming[node] : graph.outgoing[node]
                    let rows = related.compactMap { row[$0] }
                    scores[node] = rows.isEmpty ? Double(row[node] ?? 0)
                        : Double(rows.reduce(0, +)) / Double(rows.count)
                }
                columns[c].sort {
                    (scores[$0] ?? 0) != (scores[$1] ?? 0) ? (scores[$0] ?? 0) < (scores[$1] ?? 0)
                                                           : rank($0) < rank($1)
                }
                for (i, node) in columns[c].enumerated() { row[node] = i }
            }
        }

        // ---- 4. Place ----
        // Columns are centred against the tallest, so the drawing reads as a
        // band rather than hanging from the top edge.
        let tallest = columns.map(\.count).max() ?? 0
        let fullHeight = CGFloat(tallest) * (Self.boxHeight + Self.verticalGap) - Self.verticalGap

        self.columns = columns
        for (c, column) in columns.enumerated() {
            let height = CGFloat(column.count) * (Self.boxHeight + Self.verticalGap) - Self.verticalGap
            let top = Self.headRoom + (fullHeight - height) / 2
            for (i, node) in column.enumerated() {
                frame[node] = CGRect(x: CGFloat(c) * Self.columnWidth,
                                     y: top + CGFloat(i) * (Self.boxHeight + Self.verticalGap),
                                     width: Self.boxWidth, height: Self.boxHeight)
            }
        }
        canvas = CGSize(width: CGFloat(columns.count) * Self.columnWidth,
                        height: Self.headRoom + fullHeight + 20)
    }
}
