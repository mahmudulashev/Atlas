import Foundation

/// The row and column order of the dependency matrix.
///
/// Files are grouped into the same three districts the Atlas counts, and
/// within a district the busiest file comes first, so the dense corner of the
/// grid is the part worth reading. The grouping is what makes clusters and
/// layer violations legible: a mark far from the diagonal is a file reaching
/// across the system.
///
/// Lives in the engine for the same reason `LadderLayout` does — two clients
/// draw this grid, and a row order that differed between them would make the
/// same repository look like two different systems.
struct MatrixOrder: Sendable {

    /// Where a district begins in `indices`.
    struct District: Sendable {
        /// `interface`, `logic` or `data`. A key rather than a label, so each
        /// client can print it in its own language.
        let key: String
        let start: Int
    }

    /// File-graph node indices, in the order they are laid out.
    private(set) var indices: [Int] = []
    /// The reverse lookup: where a given node sits.
    private(set) var rank: [Int: Int] = [:]
    private(set) var districts: [District] = []

    var isEmpty: Bool { indices.isEmpty }

    init() {}

    init(graph: FileGraph) {
        let buckets: [(String, [Layer])] = [
            ("interface", [.ui, .entry]),
            ("logic",     [.logic, .api, .util, .config]),
            ("data",      [.data, .model, .test]),
        ]

        for (key, layers) in buckets {
            let members = graph.nodes.indices
                .filter { layers.contains(graph.nodes[$0].layer) }
                // Busiest first, and ties settled by index. Swift's sort is not
                // stable and C#'s is, so two files with the same symbol count
                // would otherwise swap places between the two clients.
                .sorted {
                    graph.nodes[$0].symbolCount != graph.nodes[$1].symbolCount
                        ? graph.nodes[$0].symbolCount > graph.nodes[$1].symbolCount
                        : $0 < $1
                }
            guard !members.isEmpty else { continue }
            districts.append(District(key: key, start: indices.count))
            indices.append(contentsOf: members)
        }

        for (rank, node) in indices.enumerated() { self.rank[node] = rank }
    }
}
