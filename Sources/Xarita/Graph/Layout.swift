import Foundation

/// Force-directed layout: nodes repel one another, edges pull their endpoints
/// together, and the system is cooled until it settles.
///
/// The naive form is O(n²) per step because every node repels every other, which
/// stops being usable somewhere around two thousand nodes. This uses a
/// Barnes–Hut quadtree instead: the plane is recursively subdivided, and any
/// cluster far enough away (`width / distance < theta`) is approximated by its
/// centre of mass. That drops each step to O(n log n) and keeps a
/// twenty-thousand-node graph interactive.
struct LayoutEngine {

    // Tunables, chosen to give readable spacing at typical code-graph densities.
    private let repulsion: Double = 6_000
    private let springLength: Double = 46
    private let springStrength: Double = 0.012
    private let centerPull: Double = 0.0016
    private let damping: Double = 0.85
    private let theta: Double = 0.85
    private let maxVelocity: Double = 34

    private(set) var x: [Double]
    private(set) var y: [Double]
    private var vx: [Double]
    private var vy: [Double]
    private var mass: [Double]

    private let edgesFrom: [Int32]
    private let edgesTo: [Int32]
    private let edgeWeight: [Double]

    private(set) var temperature: Double = 1.0
    private(set) var iteration: Int = 0

    var count: Int { x.count }

    // MARK: - Setup

    init(graph: CodeGraph) {
        let n = graph.nodes.count
        x = [Double](repeating: 0, count: n)
        y = [Double](repeating: 0, count: n)
        vx = [Double](repeating: 0, count: n)
        vy = [Double](repeating: 0, count: n)
        mass = [Double](repeating: 1, count: n)

        // Seed on a phyllotaxis spiral grouped by file: same-file symbols start
        // near each other, which converges far faster than random placement and
        // avoids the tangled knot a cold random start produces.
        let golden = Double.pi * (3 - (5.0).squareRoot())
        var order = Array(0..<n)
        order.sort { a, b in
            if graph.nodes[a].fileIndex != graph.nodes[b].fileIndex {
                return graph.nodes[a].fileIndex < graph.nodes[b].fileIndex
            }
            return graph.nodes[a].line < graph.nodes[b].line
        }
        let radius = 26.0 * Double(n).squareRoot()
        for (rank, idx) in order.enumerated() {
            let t = Double(rank) / Double(max(n - 1, 1))
            let r = radius * t.squareRoot()
            let a = Double(rank) * golden
            x[idx] = r * cos(a)
            y[idx] = r * sin(a)
            mass[idx] = 1 + Double(graph.nodes[idx].fanIn) * 0.35
        }

        var from: [Int32] = [], to: [Int32] = [], weight: [Double] = []
        from.reserveCapacity(graph.edges.count)
        to.reserveCapacity(graph.edges.count)
        weight.reserveCapacity(graph.edges.count)
        for e in graph.edges {
            from.append(Int32(e.from))
            to.append(Int32(e.to))
            weight.append(1 + log(Double(e.count)))
        }
        edgesFrom = from
        edgesTo = to
        edgeWeight = weight
    }

    // MARK: - Simulation

    mutating func run(iterations: Int) {
        for _ in 0..<iterations { step() }
    }

    mutating func step() {
        let n = x.count
        guard n > 1 else { return }

        var fx = [Double](repeating: 0, count: n)
        var fy = [Double](repeating: 0, count: n)

        // --- Repulsion via Barnes–Hut ---
        var tree = QuadTree(x: x, y: y, mass: mass)
        tree.build()
        for i in 0..<n {
            let f = tree.force(onIndex: i, x: x[i], y: y[i], theta: theta, strength: repulsion)
            fx[i] += f.0
            fy[i] += f.1
        }

        // --- Attraction along edges ---
        for k in 0..<edgesFrom.count {
            let a = Int(edgesFrom[k]), b = Int(edgesTo[k])
            let dx = x[b] - x[a]
            let dy = y[b] - y[a]
            let dist = max((dx * dx + dy * dy).squareRoot(), 0.01)
            let force = springStrength * edgeWeight[k] * (dist - springLength)
            let ux = dx / dist, uy = dy / dist
            fx[a] += ux * force; fy[a] += uy * force
            fx[b] -= ux * force; fy[b] -= uy * force
        }

        // --- Gentle pull to origin so islands don't drift to infinity ---
        for i in 0..<n {
            fx[i] -= x[i] * centerPull * mass[i]
            fy[i] -= y[i] * centerPull * mass[i]
        }

        // --- Integrate ---
        let cap = maxVelocity * temperature
        for i in 0..<n {
            vx[i] = (vx[i] + fx[i] / mass[i]) * damping
            vy[i] = (vy[i] + fy[i] / mass[i]) * damping
            let speed = (vx[i] * vx[i] + vy[i] * vy[i]).squareRoot()
            if speed > cap && speed > 0 {
                vx[i] *= cap / speed
                vy[i] *= cap / speed
            }
            x[i] += vx[i]
            y[i] += vy[i]
        }

        iteration += 1
        temperature = max(0.06, temperature * 0.982)
    }

    /// Bounding box of the current layout, for fitting the view.
    func bounds() -> (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        guard !x.isEmpty else { return (0, 0, 1, 1) }
        var minX = x[0], maxX = x[0], minY = y[0], maxY = y[0]
        for i in x.indices {
            minX = min(minX, x[i]); maxX = max(maxX, x[i])
            minY = min(minY, y[i]); maxY = max(maxY, y[i])
        }
        return (minX, minY, maxX, maxY)
    }
}

/// Flat-array quadtree. Children are stored as indices into `nodes` rather than
/// as references, so the whole tree is one contiguous allocation per step.
private struct QuadTree {

    private struct Cell {
        var cx = 0.0, cy = 0.0          // centre of mass
        var mass = 0.0
        var minX = 0.0, minY = 0.0, size = 0.0
        var children: (Int32, Int32, Int32, Int32) = (-1, -1, -1, -1)
        var bodyIndex: Int32 = -1       // leaf payload
        var isLeaf = true
    }

    private let x: [Double]
    private let y: [Double]
    private let mass: [Double]
    private var cells: [Cell] = []

    init(x: [Double], y: [Double], mass: [Double]) {
        self.x = x; self.y = y; self.mass = mass
    }

    mutating func build() {
        let n = x.count
        guard n > 0 else { return }

        var minX = x[0], maxX = x[0], minY = y[0], maxY = y[0]
        for i in 0..<n {
            minX = min(minX, x[i]); maxX = max(maxX, x[i])
            minY = min(minY, y[i]); maxY = max(maxY, y[i])
        }
        let size = max(maxX - minX, maxY - minY) + 1

        cells.removeAll(keepingCapacity: true)
        cells.reserveCapacity(n * 2)
        var root = Cell()
        root.minX = minX; root.minY = minY; root.size = size
        cells.append(root)

        for i in 0..<n { insert(body: i, into: 0) }
    }

    private mutating func insert(body: Int, into cellIndex: Int) {
        var index = cellIndex
        while true {
            // Accumulate centre of mass on the way down.
            let m = mass[body]
            let total = cells[index].mass + m
            cells[index].cx = (cells[index].cx * cells[index].mass + x[body] * m) / total
            cells[index].cy = (cells[index].cy * cells[index].mass + y[body] * m) / total
            cells[index].mass = total

            if cells[index].isLeaf {
                if cells[index].bodyIndex == -1 {
                    cells[index].bodyIndex = Int32(body)
                    return
                }
                // Occupied leaf: subdivide and push the resident down.
                let resident = Int(cells[index].bodyIndex)
                cells[index].bodyIndex = -1
                cells[index].isLeaf = false
                subdivide(index)
                if resident != body || true {
                    let q = quadrant(for: resident, in: index)
                    insertLeafOnly(body: resident, into: q)
                }
                let q = quadrant(for: body, in: index)
                index = q
                continue
            }

            index = quadrant(for: body, in: index)
        }
    }

    /// Places a body into an already-empty leaf without re-running accumulation
    /// from the root (its mass is already counted by every ancestor).
    private mutating func insertLeafOnly(body: Int, into cellIndex: Int) {
        var index = cellIndex
        while true {
            let m = mass[body]
            let total = cells[index].mass + m
            cells[index].cx = (cells[index].cx * cells[index].mass + x[body] * m) / total
            cells[index].cy = (cells[index].cy * cells[index].mass + y[body] * m) / total
            cells[index].mass = total

            if cells[index].isLeaf {
                if cells[index].bodyIndex == -1 {
                    cells[index].bodyIndex = Int32(body)
                    return
                }
                let resident = Int(cells[index].bodyIndex)
                cells[index].bodyIndex = -1
                cells[index].isLeaf = false
                subdivide(index)
                // Degenerate case: identical coordinates. Nudge and drop it in.
                if cells[index].size < 1e-6 {
                    cells[index].bodyIndex = Int32(resident)
                    return
                }
                insertLeafOnly(body: resident, into: quadrant(for: resident, in: index))
                index = quadrant(for: body, in: index)
                continue
            }
            index = quadrant(for: body, in: index)
        }
    }

    private mutating func subdivide(_ index: Int) {
        let half = cells[index].size / 2
        let minX = cells[index].minX, minY = cells[index].minY
        var kids: [Int32] = []
        for (ox, oy) in [(0.0, 0.0), (half, 0.0), (0.0, half), (half, half)] {
            var c = Cell()
            c.minX = minX + ox; c.minY = minY + oy; c.size = half
            cells.append(c)
            kids.append(Int32(cells.count - 1))
        }
        cells[index].children = (kids[0], kids[1], kids[2], kids[3])
    }

    private func quadrant(for body: Int, in cellIndex: Int) -> Int {
        let c = cells[cellIndex]
        let half = c.size / 2
        let right = x[body] >= c.minX + half
        let bottom = y[body] >= c.minY + half
        switch (right, bottom) {
        case (false, false): return Int(c.children.0)
        case (true, false):  return Int(c.children.1)
        case (false, true):  return Int(c.children.2)
        case (true, true):   return Int(c.children.3)
        }
    }

    /// Repulsive force on one body, approximating distant cells by centre of mass.
    func force(onIndex index: Int, x px: Double, y py: Double,
               theta: Double, strength: Double) -> (Double, Double) {
        guard !cells.isEmpty else { return (0, 0) }
        var fx = 0.0, fy = 0.0
        var stack: [Int] = [0]
        stack.reserveCapacity(64)

        while let cellIndex = stack.popLast() {
            let cell = cells[cellIndex]
            guard cell.mass > 0 else { continue }
            if cell.isLeaf && cell.bodyIndex == Int32(index) { continue }

            let dx = px - cell.cx
            let dy = py - cell.cy
            let distSq = dx * dx + dy * dy + 0.05
            let dist = distSq.squareRoot()

            if cell.isLeaf || (cell.size / dist) < theta {
                let f = strength * cell.mass / distSq
                fx += dx / dist * f
                fy += dy / dist * f
            } else {
                let kids = [cell.children.0, cell.children.1, cell.children.2, cell.children.3]
                for k in kids where k >= 0 { stack.append(Int(k)) }
            }
        }
        return (fx, fy)
    }
}
