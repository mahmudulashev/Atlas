import SwiftUI
import AppKit

/// The architecture diagram: one card per file, wired by what calls what.
///
/// Everything is drawn into a single `Canvas` rather than composed from views.
/// Sixty cards and a hundred and thirty connectors would mean hundreds of
/// SwiftUI nodes re-laid out on every pan; drawing them directly keeps the
/// whole diagram to one pass, and hit testing against known rectangles is
/// simpler than threading gestures through a view hierarchy.
struct ArchitectureView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragAnchor: CGSize = .zero
    @State private var hoveredCard: Int?
    @State private var didFit = false

    private let minScale: CGFloat = 0.18
    private let maxScale: CGFloat = 2.2

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                PaperBackground(spacing: 26 * max(scale, 0.35))

                Canvas { context, size in
                    draw(context: context, size: size)
                }
                .contentShape(Rectangle())
                .gesture(pan)
                .gesture(MagnifyGesture().onChanged { value in
                    scale = clamp(scale * (1 + (value.magnification - 1) * 0.16))
                })
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point): hoveredCard = card(at: point, in: geo.size)
                    case .ended:             hoveredCard = nil
                    }
                }
                .onTapGesture { point in
                    if let index = card(at: point, in: geo.size) { open(card: index) }
                }

                legend.padding(14)
            }
            .onAppear { if !didFit { fit(in: geo.size); didFit = true } }
            .onChange(of: state.graph?.rootPath) { _, _ in didFit = false; fit(in: geo.size) }
            .overlay(alignment: .bottomTrailing) { controls(in: geo.size).padding(14) }
            .overlay(alignment: .bottomLeading) { summary.padding(14) }
        }
    }

    private var layout: DiagramLayout { state.diagram }
    private var fileGraph: FileGraph { state.fileGraph }

    // MARK: - Transform

    private func toScreen(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * scale + offset.width, y: point.y * scale + offset.height)
    }

    private func toDiagram(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - offset.width) / scale, y: (point.y - offset.height) / scale)
    }

    private func clamp(_ value: CGFloat) -> CGFloat { max(minScale, min(maxScale, value)) }

    // MARK: - Drawing

    private func draw(context: GraphicsContext, size: CGSize) {
        guard !layout.cards.isEmpty else { return }

        let highlighted = hoveredCard
        var linked = Set<Int>()
        if let highlighted {
            for connector in layout.connectors {
                if connector.from == highlighted { linked.insert(connector.to) }
                if connector.to == highlighted { linked.insert(connector.from) }
            }
        }

        drawColumnLabels(context: context)

        // ---- Connectors, dimmed ones first so highlights sit on top ----
        for connector in layout.connectors {
            let isLive = highlighted == nil
                || connector.from == highlighted || connector.to == highlighted
            guard isLive || scale > 0.3 else { continue }

            var path = Path()
            let points = connector.points.map(toScreen)
            guard let first = points.first else { continue }
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }

            let color: Color = {
                if highlighted == nil { return Theme.connector }
                if connector.to == highlighted { return Theme.edgeIncoming }
                if connector.from == highlighted { return Theme.edgeOutgoing }
                return Theme.edge.opacity(0.18)
            }()

            context.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: (isLive && highlighted != nil) ? 2.1 : 1.5,
                                              lineCap: .round, lineJoin: .round,
                                              dash: [6 * max(scale, 0.4), 4 * max(scale, 0.4)]))

            if let last = points.last, let previous = points.dropLast().last, isLive {
                drawArrowhead(context: context, at: last, from: previous, color: color)
            }
        }

        // ---- Cards ----
        for (index, card) in layout.cards.enumerated() {
            let node = fileGraph.nodes[card.nodeIndex]
            let frame = CGRect(x: toScreen(card.frame.origin).x,
                               y: toScreen(card.frame.origin).y,
                               width: card.frame.width * scale,
                               height: card.frame.height * scale)
            guard frame.intersects(CGRect(origin: .zero, size: size).insetBy(dx: -200, dy: -200))
            else { continue }

            let dimmed = highlighted != nil && index != highlighted && !linked.contains(index)
            drawCard(context: context, frame: frame, node: node,
                     isHovered: index == highlighted, dimmed: dimmed)
        }
    }

    private func drawCard(context: GraphicsContext, frame: CGRect,
                          node: FileGraph.Node, isHovered: Bool, dimmed: Bool) {
        let radius = 8 * scale
        let alpha = dimmed ? 0.32 : 1.0
        let shape = Path(roundedRect: frame, cornerRadius: radius)

        if isHovered {
            context.fill(Path(roundedRect: frame.insetBy(dx: -3, dy: -3),
                              cornerRadius: radius + 3),
                         with: .color(Theme.accent.opacity(0.16)))
        }
        context.fill(shape, with: .color(Theme.surface.opacity(alpha)))
        context.stroke(shape,
                       with: .color(isHovered ? Theme.accent : Theme.border.opacity(alpha)),
                       lineWidth: isHovered ? 1.8 : 1)

        // Header, tinted by what kind of file this is.
        let headerHeight = DiagramLayout.headerHeight * scale
        let header = CGRect(x: frame.minX, y: frame.minY,
                            width: frame.width, height: headerHeight)
        var headerPath = Path()
        headerPath.addRoundedRect(in: header, cornerSize: CGSize(width: radius, height: radius))
        // Clipping is a mutation, so the header is filled through its own copy
        // of the context; the rest of the card must not inherit the clip.
        var clipped = context
        clipped.clip(to: shape)
        clipped.fill(headerPath, with: .color(color(for: node.layer).opacity(alpha)))

        guard scale > 0.32 else { return }

        // Badge first, so the file name knows how much room is actually left.
        // Canvas text does not truncate itself; without measuring, a long file
        // name simply runs underneath the badge.
        let badgeFont = Font.system(size: 8.5 * scale, weight: .bold)
        let badge = context.resolve(Text(node.layer.name(loc.language))
            .font(badgeFont)
            .foregroundStyle(Color.white.opacity(0.85)))
        let badgeWidth = badge.measure(in: CGSize(width: frame.width, height: headerHeight)).width

        let padding = 10 * scale
        let available = frame.width - padding * 2 - badgeWidth - 8 * scale
        let titleFont = Font.system(size: 12 * scale, weight: .semibold, design: .monospaced)

        func resolvedTitle(_ string: String) -> GraphicsContext.ResolvedText {
            context.resolve(Text(string).font(titleFont).foregroundStyle(Color.white))
        }

        var displayName = node.name
        var title = resolvedTitle(displayName)
        if title.measure(in: CGSize(width: .infinity, height: headerHeight)).width > available,
           available > 20 {
            // Trim from the front: the extension and the distinctive tail of a
            // file name carry more meaning than its prefix.
            while displayName.count > 4,
                  resolvedTitle("…" + displayName)
                    .measure(in: CGSize(width: .infinity, height: headerHeight)).width > available {
                displayName.removeFirst()
            }
            displayName = "…" + displayName
            title = resolvedTitle(displayName)
        }

        context.draw(title, at: CGPoint(x: frame.minX + padding, y: header.midY), anchor: .leading)
        if available > 20 {
            context.draw(badge, at: CGPoint(x: frame.maxX - padding, y: header.midY),
                         anchor: .trailing)
        }

        guard scale > 0.42 else { return }

        // Rows: the most connected symbols in the file, with their caller count.
        var y = frame.minY + headerHeight
        let rowHeight = DiagramLayout.rowHeight * scale
        for symbolID in node.symbols.prefix(DiagramLayout.maxRowsShown) {
            guard let graph = state.graph, symbolID < graph.nodes.count else { break }
            let symbol = graph.nodes[symbolID]

            // Rows truncate for the same reason the header does: Canvas draws
            // whatever it is given, so a long symbol name runs straight off the
            // edge of the card unless it is measured and trimmed first.
            let rowFont = Font.system(size: 10.5 * scale, design: .monospaced)
            let countWidth: CGFloat = symbol.fanIn > 0 ? 22 * scale : 0
            let rowSpace = frame.width - padding * 2 - countWidth

            func resolvedRow(_ string: String) -> GraphicsContext.ResolvedText {
                context.resolve(Text(string).font(rowFont)
                    .foregroundStyle(Theme.textPrimary.opacity(alpha)))
            }
            var rowText = symbol.name
            var name = resolvedRow(rowText)
            if name.measure(in: CGSize(width: .infinity, height: rowHeight)).width > rowSpace,
               rowSpace > 24 {
                while rowText.count > 3,
                      resolvedRow(rowText + "…")
                        .measure(in: CGSize(width: .infinity, height: rowHeight)).width > rowSpace {
                    rowText.removeLast()
                }
                rowText += "…"
                name = resolvedRow(rowText)
            }
            context.draw(name,
                         at: CGPoint(x: frame.minX + padding, y: y + rowHeight / 2),
                         anchor: .leading)

            if symbol.fanIn > 0 {
                let count = Text("\(symbol.fanIn)")
                    .font(.system(size: 9.5 * scale, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary.opacity(alpha))
                context.draw(context.resolve(count),
                             at: CGPoint(x: frame.maxX - padding, y: y + rowHeight / 2),
                             anchor: .trailing)
            }
            y += rowHeight
        }

        if node.symbolCount > DiagramLayout.maxRowsShown, scale > 0.5 {
            let more = Text("+\(node.symbolCount - DiagramLayout.maxRowsShown)")
                .font(.system(size: 9 * scale))
                .foregroundStyle(Theme.textTertiary.opacity(alpha))
            context.draw(context.resolve(more),
                         at: CGPoint(x: frame.minX + padding, y: y + 6 * scale), anchor: .leading)
        }
    }

    private func drawArrowhead(context: GraphicsContext, at point: CGPoint,
                               from previous: CGPoint, color: Color) {
        let angle = atan2(point.y - previous.y, point.x - previous.x)
        let length = 7 * max(scale, 0.5)
        var head = Path()
        head.move(to: point)
        head.addLine(to: CGPoint(x: point.x - length * cos(angle - .pi / 7),
                                 y: point.y - length * sin(angle - .pi / 7)))
        head.addLine(to: CGPoint(x: point.x - length * cos(angle + .pi / 7),
                                 y: point.y - length * sin(angle + .pi / 7)))
        head.closeSubpath()
        context.fill(head, with: .color(color))
    }

    private func drawColumnLabels(context: GraphicsContext) {
        guard scale > 0.3 else { return }
        for (index, label) in layout.columnLabels.enumerated() {
            let point = toScreen(CGPoint(x: label.x, y: DiagramLayout.margin - 6))
            let text = Text("\(index + 1) · \(label.layer.name(loc.language).uppercased())")
                .font(.system(size: 9.5 * max(scale, 0.7), weight: .bold))
                .foregroundStyle(Theme.textTertiary)
            context.draw(context.resolve(text), at: point, anchor: .bottomLeading)
        }
    }

    private func color(for layer: Layer) -> Color {
        switch layer {
        case .entry:  return Theme.marker
        case .ui:     return Theme.dynamic(light: 0x6B4AA0, dark: 0x9B7BD4)
        case .api:    return Theme.dynamic(light: 0x1F6E7C, dark: 0x4FA8B8)
        case .logic:  return Theme.accent
        case .model:  return Theme.dynamic(light: 0xA9750F, dark: 0xC79433)
        case .data:   return Theme.dynamic(light: 0x2F7A54, dark: 0x4E9E70)
        case .util:   return Theme.dynamic(light: 0x5C6779, dark: 0x6E7C92)
        case .config: return Theme.dynamic(light: 0x8A6A2E, dark: 0xA08447)
        case .test:   return Theme.dynamic(light: 0x8E7D81, dark: 0x7A6569)
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

    private func card(at point: CGPoint, in size: CGSize) -> Int? {
        let target = toDiagram(point)
        for (index, card) in layout.cards.enumerated() where card.frame.contains(target) {
            return index
        }
        return nil
    }

    private func open(card index: Int) {
        guard index < layout.cards.count else { return }
        let node = fileGraph.nodes[layout.cards[index].nodeIndex]
        if let first = node.symbols.first { state.select(first) }
    }

    private func fit(in size: CGSize) {
        let canvas = layout.canvasSize
        guard canvas.width > 1, canvas.height > 1, size.width > 1 else { return }
        let target = min(size.width / (canvas.width + 60), size.height / (canvas.height + 60))
        withAnimation(.easeOut(duration: 0.4)) {
            scale = clamp(target)
            offset = CGSize(width: (size.width - canvas.width * clamp(target)) / 2,
                            height: 20)
        }
        dragAnchor = CGSize(width: (size.width - canvas.width * clamp(target)) / 2, height: 20)
    }

    // MARK: - Overlays

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
        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.border, lineWidth: 1))
    }

    private var summary: some View {
        HStack(spacing: 14) {
            summaryItem("\(fileGraph.nodes.count)", loc.t.files)
            summaryItem("\(fileGraph.edges.count)", loc.t.connections)
            if !fileGraph.cycles.isEmpty {
                summaryItem("\(fileGraph.cycles.count)", loc.t.cycles, tint: Theme.marker)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.border, lineWidth: 1))
    }

    private func summaryItem(_ value: String, _ label: String,
                             tint: Color = Theme.textPrimary) -> some View {
        HStack(spacing: 5) {
            Text(value)
                .font(Theme.Font.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
            Text(label.lowercased())
                .font(Theme.Font.micro)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var legend: some View {
        let shown: [Layer] = Array(Set(fileGraph.nodes.map(\.layer)))
            .sorted { $0.depth < $1.depth }
        return HStack(spacing: 10) {
            ForEach(shown, id: \.self) { layer in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: layer))
                        .frame(width: 8, height: 8)
                    Text(layer.name(loc.language))
                        .font(Theme.Font.micro)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.border, lineWidth: 1))
    }
}
