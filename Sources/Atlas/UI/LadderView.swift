import SwiftUI

/// The call ladder: what runs first, and what it leans on.
///
/// Columns are dependency depth — nothing calls the first column, and nothing
/// in the last calls anything — so every link runs left to right and a line
/// going backwards is a cycle, impossible to miss.
///
/// Rows are deliberately small. An earlier version drew each file as a card
/// listing its symbols, which put eight files on screen; at a row apiece the
/// same space holds the whole project, and seeing all of it at once is the
/// entire point of the view.
struct LadderView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    @State private var selected: Int?
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragAnchor: CGSize = .zero
    @State private var didFit = false

    // The design's grid, shared with the engine so the Windows client places
    // the same boxes in the same order.
    private let columnWidth = LadderLayout.columnWidth

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                PaperBackground(spacing: 26 * max(scale, 0.4))

                Canvas { context, size in
                    draw(context: context, size: size)
                }
                .contentShape(Rectangle())
                .gesture(pan)
                .gesture(MagnifyGesture().onChanged {
                    scale = clamp(scale * (1 + ($0.magnification - 1) * 0.16))
                })
                .onTapGesture { point in
                    if let hit = box(at: point) { choose(hit) }
                }
            }
            .onAppear { if !didFit { fit(in: geo.size); didFit = true } }
            .onChange(of: state.graph?.rootPath) { _, _ in
                selected = nil; didFit = false; fit(in: geo.size)
            }
            .onChange(of: state.fileGraph.nodes.count) { _, _ in
                selected = nil; fit(in: geo.size)
            }
            .overlay(alignment: .top) { header.padding(.horizontal, 16).padding(.top, 12) }
            .overlay(alignment: .bottom) { legend.padding(14) }
            .overlay(alignment: .bottomTrailing) { controls(in: geo.size).padding(14) }
        }
    }

    // MARK: - Model

    /// Where every file sits. Computed by `LadderLayout` in the engine — the
    /// depth pass and the barycentre sweeps used to live here, but the picture
    /// is the product, and two clients each deriving their own would draw the
    /// same repository two different ways.
    private var placed: LadderLayout { LadderLayout(graph: state.fileGraph) }

    /// Everything reachable from a file, in one direction.
    private func reach(_ index: Int, downstream: Bool) -> Set<Int> {
        let graph = state.fileGraph
        // The selection is a file index, and the file graph is rebuilt whenever
        // tests are shown or hidden. A selection made against the larger graph
        // is out of range against the smaller one, so it has to be checked here
        // rather than trusted.
        guard index >= 0, index < graph.nodes.count else { return [] }
        var seen = Set<Int>()
        var frontier = [index]
        while !frontier.isEmpty {
            var next: [Int] = []
            for current in frontier {
                for other in (downstream ? graph.outgoing[current] : graph.incoming[current])
                where other != index && seen.insert(other).inserted {
                    next.append(other)
                }
            }
            frontier = next
        }
        return seen
    }

    // MARK: - Drawing

    private func draw(context: GraphicsContext, size: CGSize) {
        let graph = state.fileGraph
        let layout = placed
        guard !layout.frame.isEmpty else { return }

        let sel = selected
        let down = sel.map { reach($0, downstream: true) } ?? []
        let up = sel.map { reach($0, downstream: false) } ?? []
        var lit = Set<Int>()
        if let sel { lit = up.union(down).union([sel]) }

        func place(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX * scale + offset.width, y: rect.minY * scale + offset.height,
                   width: rect.width * scale, height: rect.height * scale)
        }

        // ---- Column heads ----
        for (c, column) in layout.columns.enumerated() where !column.isEmpty {
            let label = c == 0 ? loc.t.columnEntry
                : (c == layout.columns.count - 1 ? loc.t.columnFoundation : loc.t.columnDepth(c))
            let text = Text("\(label) · \(column.count)")
                .font(.system(size: 9.5 * max(scale, 0.75), weight: .semibold, design: .serif))
                .foregroundStyle(Theme.textTertiary)
            let origin = place(CGRect(x: CGFloat(c) * columnWidth, y: 8, width: 1, height: 1))
            context.draw(context.resolve(text), at: origin.origin, anchor: .topLeading)
        }

        // ---- Links, quietest first so highlights land on top ----
        struct Link { var path: Path; var ink: Color; var width: CGFloat; var opacity: Double }
        var links: [Link] = []

        for edge in graph.edges {
            guard let from = layout.frame[edge.from], let to = layout.frame[edge.to] else { continue }
            let a = place(from), b = place(to)
            let start = CGPoint(x: a.maxX, y: a.midY)
            let end = CGPoint(x: b.minX, y: b.midY)
            let bend = max(26 * scale, (end.x - start.x) * 0.55)

            var path = Path()
            path.move(to: start)
            path.addCurve(to: end,
                          control1: CGPoint(x: start.x + bend, y: start.y),
                          control2: CGPoint(x: end.x - bend, y: end.y))

            var ink = Theme.connector
            var width = 1.0 * scale
            var opacity = 0.5

            if let sel {
                let isDown = edge.from == sel || (down.contains(edge.from) && down.contains(edge.to))
                let isUp = edge.to == sel || (up.contains(edge.from) && up.contains(edge.to))
                if isUp        { ink = Theme.inkMagenta; width = 1.5 * scale; opacity = 0.9 }
                else if isDown { ink = Theme.inkCyan;    width = 1.5 * scale; opacity = 0.9 }
                else           { opacity = 0.16 }
            }
            links.append(Link(path: path, ink: ink, width: max(0.6, width), opacity: opacity))
        }

        for link in links.sorted(by: { $0.opacity < $1.opacity }) {
            context.stroke(link.path, with: .color(link.ink.opacity(link.opacity)),
                           lineWidth: link.width)
        }

        // ---- Boxes ----
        for (index, rect) in layout.frame {
            let frame = place(rect)
            guard frame.intersects(CGRect(origin: .zero, size: size).insetBy(dx: -140, dy: -140))
            else { continue }

            let node = graph.nodes[index]
            let isSelected = index == sel
            let dim = sel != nil && !lit.contains(index)
            let alpha = dim ? 0.32 : 1.0

            context.fill(Path(frame),
                         with: .color(isSelected ? Theme.inkMagentaSoft
                                                 : Theme.surfaceRaised.opacity(alpha)))

            // District as a rule down the left edge, not a filled header: the
            // fill is needed for selection, and two signals in one place read
            // as neither.
            context.fill(Path(CGRect(x: frame.minX, y: frame.minY,
                                     width: 3 * scale, height: frame.height)),
                         with: .color(districtInk(node.layer).opacity(alpha)))

            guard scale > 0.45 else { continue }

            let nameColour = isSelected ? Theme.inkMagentaDeep : Theme.textPrimary
            let name = context.resolve(Text(trimmed(node.name, to: frame.width - 42 * scale,
                                                    in: context, scale: scale))
                .font(.system(size: 11.5 * scale, design: .serif))
                .foregroundStyle(nameColour.opacity(alpha)))
            context.draw(name, at: CGPoint(x: frame.minX + 10 * scale, y: frame.midY),
                         anchor: .leading)

            let count = context.resolve(Text("\(node.symbolCount)")
                .font(.system(size: 10 * scale, design: .monospaced))
                .foregroundStyle(Theme.textTertiary.opacity(alpha)))
            context.draw(count, at: CGPoint(x: frame.maxX - 8 * scale, y: frame.midY),
                         anchor: .trailing)
        }
    }

    /// Canvas draws whatever it is given, so a long file name has to be cut to
    /// fit before it is drawn.
    private func trimmed(_ text: String, to width: CGFloat,
                         in context: GraphicsContext, scale: CGFloat) -> String {
        func measure(_ s: String) -> CGFloat {
            context.resolve(Text(s).font(.system(size: 11.5 * scale, design: .serif)))
                .measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 40)).width
        }
        guard width > 20, measure(text) > width else { return text }
        var cut = text
        while cut.count > 2, measure(cut + "…") > width { cut.removeLast() }
        return cut + "…"
    }

    private func districtInk(_ layer: Layer) -> Color {
        switch layer {
        case .ui, .entry:                 return Theme.inkCyan
        case .data, .model, .test:        return Theme.inkMagenta
        default:                          return Theme.textSecondary
        }
    }

    // MARK: - Interaction

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: dragAnchor.width + value.translation.width,
                                height: dragAnchor.height + value.translation.height)
            }
            .onEnded { _ in dragAnchor = offset }
    }

    private func box(at point: CGPoint) -> Int? {
        let layout = placed
        for (index, rect) in layout.frame {
            let frame = CGRect(x: rect.minX * scale + offset.width,
                               y: rect.minY * scale + offset.height,
                               width: rect.width * scale, height: rect.height * scale)
            if frame.contains(point) { return index }
        }
        return nil
    }

    private func choose(_ index: Int) {
        selected = index
        if let first = state.fileGraph.nodes[index].symbols.first { state.select(first) }
    }

    private func clamp(_ v: CGFloat) -> CGFloat { max(0.28, min(2.4, v)) }

    private func fit(in size: CGSize) {
        let canvas = placed.canvas
        guard canvas.width > 1, size.width > 1 else { return }
        let target = clamp(min((size.width - 40) / canvas.width,
                               (size.height - 96) / max(canvas.height, 1)))
        withAnimation(.easeOut(duration: 0.35)) {
            scale = target
            offset = CGSize(width: (size.width - canvas.width * target) / 2, height: 46)
        }
        dragAnchor = CGSize(width: (size.width - canvas.width * target) / 2, height: 46)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.t.ladderTitle)
                    .font(Theme.Font.heading)
                    .foregroundStyle(Theme.textPrimary)
                Text(loc.t.ladderHint)
                    .font(Theme.Font.micro.weight(.regular))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 460, alignment: .leading)
            }
            Spacer(minLength: 0)
            if let sel = selected, sel < state.fileGraph.nodes.count {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(state.fileGraph.nodes[sel].name)
                        .font(Theme.Font.mono.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(loc.t.ladderSelection(up: reach(sel, downstream: false).count,
                                               down: reach(sel, downstream: true).count))
                        .font(Theme.Font.micro.weight(.regular))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendLine(Theme.inkMagenta, loc.t.reachesSelection)
            legendLine(Theme.inkCyan, loc.t.selectionReaches)
            legendSwatch(Theme.inkCyan, loc.t.districtInterface)
            legendSwatch(Theme.textSecondary, loc.t.districtLogic)
            legendSwatch(Theme.inkMagenta, loc.t.districtData)
            Spacer(minLength: 8)
            Text(loc.t.clickAnyFile)
                .font(Theme.Font.micro.weight(.regular))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Rectangle().fill(Theme.surface.opacity(0.96)))
        .overlay(Rectangle().strokeBorder(Theme.border, lineWidth: 1))
    }

    private func legendLine(_ ink: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(ink).frame(width: 14, height: 3)
            Text(text).font(Theme.Font.micro.weight(.regular)).foregroundStyle(Theme.textSecondary)
        }
    }

    private func legendSwatch(_ ink: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Rectangle().fill(ink).frame(width: 9, height: 9)
            Text(text.capitalized).font(Theme.Font.micro.weight(.regular))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func controls(in size: CGSize) -> some View {
        HStack(spacing: 5) {
            RailButton(icon: "minus.magnifyingglass", help: loc.t.zoomOut, enabled: true) {
                withAnimation(.easeOut(duration: 0.15)) { scale = clamp(scale / 1.3) }
            }
            RailButton(icon: "plus.magnifyingglass", help: loc.t.zoomIn, enabled: true) {
                withAnimation(.easeOut(duration: 0.15)) { scale = clamp(scale * 1.3) }
            }
            RailButton(icon: "arrow.up.left.and.arrow.down.right",
                       help: loc.t.fitToScreen, enabled: true) { fit(in: size) }
        }
        .padding(4)
        .background(Rectangle().fill(Theme.surface.opacity(0.96)))
        .overlay(Rectangle().strokeBorder(Theme.border, lineWidth: 1))
    }
}
