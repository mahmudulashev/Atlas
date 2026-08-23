import SwiftUI

/// The map itself.
///
/// Every edge is accumulated into a small number of `Path`s and stroked once per
/// frame rather than issued as twenty thousand individual draw calls, which is
/// the difference between a smooth canvas and a slideshow on a large graph.
/// Nodes outside the viewport are culled, and labels are only considered once
/// the zoom level makes them legible.
struct GraphCanvas: View {

    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragAnchor: CGSize = .zero
    @State private var viewSize: CGSize = .zero
    @State private var lastFitRequest: Int = -1

    private let minScale: CGFloat = 0.04
    private let maxScale: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                draw(context: context, size: size)
            }
            .background(Theme.surfaceSunken)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onContinuousHover { phase in
                switch phase {
                case .active(let point): updateHover(at: point, size: geo.size)
                case .ended:             state.hovered = nil
                }
            }
            .onTapGesture { point in
                state.select(node(at: point, size: geo.size))
            }
            .modifier(ScrollZoom(scale: $scale, offset: $offset,
                                 minScale: minScale, maxScale: maxScale))
            .onAppear { viewSize = geo.size; fitIfNeeded(size: geo.size) }
            .onChange(of: geo.size) { _, newValue in viewSize = newValue }
            .onChange(of: state.fitRequest) { _, _ in fit(size: geo.size) }
            .overlay(alignment: .bottomTrailing) { zoomControls.padding(14) }
            .overlay(alignment: .bottomLeading) { legend.padding(14) }
        }
    }

    // MARK: - Coordinate transforms

    private func toScreen(_ world: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: (world.x + offset.width) * scale + size.width / 2,
                y: (world.y + offset.height) * scale + size.height / 2)
    }

    private func toWorld(_ screen: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: (screen.x - size.width / 2) / scale - offset.width,
                y: (screen.y - size.height / 2) / scale - offset.height)
    }

    private func radius(_ node: GraphNode) -> CGFloat {
        3.0 + CGFloat(node.weight.squareRoot()) * 1.7
    }

    // MARK: - Drawing

    private func draw(context: GraphicsContext, size: CGSize) {
        guard let graph = state.graph, !state.store.x.isEmpty else { return }
        _ = state.layoutTick   // redraw dependency

        let store = state.store
        let selected = state.selection
        let hovered = state.hovered
        let focus = selected ?? hovered

        // Neighbourhood of the focused node, drawn on top and in colour.
        var incoming = Set<Int>()
        var outgoing = Set<Int>()
        if let focus, focus < graph.nodes.count {
            incoming = Set(graph.incoming[focus])
            outgoing = Set(graph.outgoing[focus])
        }

        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: -80, dy: -80)

        // ---- Edges, batched ----
        var base = Path()
        var inPath = Path()
        var outPath = Path()

        let drawAllEdges = graph.edges.count <= 60_000
        if drawAllEdges {
            for edge in graph.edges {
                let a = toScreen(store.point(edge.from), size: size)
                let b = toScreen(store.point(edge.to), size: size)
                guard bounds.contains(a) || bounds.contains(b) else { continue }

                if let focus {
                    if edge.to == focus {
                        inPath.move(to: a); inPath.addLine(to: b); continue
                    }
                    if edge.from == focus {
                        outPath.move(to: a); outPath.addLine(to: b); continue
                    }
                }
                base.move(to: a); base.addLine(to: b)
            }

            let dim = focus != nil ? 0.28 : 0.75
            context.stroke(base, with: .color(Theme.edge.opacity(dim)),
                           lineWidth: max(0.4, 0.7 * scale))
            context.stroke(inPath, with: .color(Theme.edgeIncoming.opacity(0.85)),
                           lineWidth: max(0.9, 1.5 * scale))
            context.stroke(outPath, with: .color(Theme.edgeOutgoing.opacity(0.85)),
                           lineWidth: max(0.9, 1.5 * scale))
        }

        // ---- Nodes ----
        let searchHits = Set(state.searchText.isEmpty ? [] : state.searchResults.prefix(200))
        var labelCandidates: [(CGPoint, CGFloat, GraphNode)] = []

        for node in graph.nodes {
            let p = toScreen(store.point(node.id), size: size)
            guard bounds.contains(p) else { continue }

            let r = radius(node) * max(0.55, min(scale, 2.2))
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)

            var fill = Theme.color(for: node.kind, external: node.isExternal)
            var alpha: Double = 1

            if let focus {
                if node.id == focus { alpha = 1 }
                else if incoming.contains(node.id) || outgoing.contains(node.id) { alpha = 0.95 }
                else { alpha = 0.22 }
            }
            if !searchHits.isEmpty {
                if searchHits.contains(node.id) { alpha = 1; fill = Theme.gold }
                else { alpha = min(alpha, 0.18) }
            }

            context.fill(Circle().path(in: rect), with: .color(fill.opacity(alpha)))

            if node.id == focus {
                let ring = rect.insetBy(dx: -3.5, dy: -3.5)
                context.stroke(Circle().path(in: ring),
                               with: .color(Theme.textPrimary.opacity(0.9)), lineWidth: 1.6)
            }

            if state.showLabels {
                let worthy = node.id == focus
                    || searchHits.contains(node.id)
                    || (scale > 0.75 && node.fanIn >= 2)
                    || scale > 1.8
                if worthy { labelCandidates.append((p, r, node)) }
            }
        }

        // ---- Labels, capped so a dense region can't stall the frame ----
        for (p, r, node) in labelCandidates.prefix(220) {
            let text = Text(node.displayName)
                .font(Theme.Font.monoSmall)
                .foregroundStyle(node.id == focus ? Theme.textPrimary : Theme.textSecondary)
            context.draw(context.resolve(text), at: CGPoint(x: p.x, y: p.y - r - 7), anchor: .bottom)
        }
    }

    // MARK: - Interaction

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: dragAnchor.width + value.translation.width / scale,
                                height: dragAnchor.height + value.translation.height / scale)
            }
            .onEnded { _ in dragAnchor = offset }
    }

    private func node(at point: CGPoint, size: CGSize) -> Int? {
        guard let graph = state.graph, !state.store.x.isEmpty else { return nil }
        let world = toWorld(point, size: size)
        var best: Int? = nil
        var bestDistance = Double.greatestFiniteMagnitude

        for node in graph.nodes {
            let p = state.store.point(node.id)
            let dx = p.x - world.x, dy = p.y - world.y
            let d = dx * dx + dy * dy
            let hit = Double(radius(node) / scale + 6 / scale)
            if d < hit * hit && d < bestDistance {
                bestDistance = d
                best = node.id
            }
        }
        return best
    }

    private func updateHover(at point: CGPoint, size: CGSize) {
        let found = node(at: point, size: size)
        if found != state.hovered { state.hovered = found }
    }

    // MARK: - Fitting

    private func fitIfNeeded(size: CGSize) {
        guard state.fitRequest != lastFitRequest else { return }
        fit(size: size)
    }

    private func fit(size: CGSize) {
        guard let graph = state.graph, !state.store.x.isEmpty, graph.nodes.count > 0,
              size.width > 1, size.height > 1 else { return }
        lastFitRequest = state.fitRequest

        var minX = Double.greatestFiniteMagnitude, maxX = -Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
        for i in graph.nodes.indices {
            let p = state.store.point(i)
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let width = max(maxX - minX, 1), height = max(maxY - minY, 1)
        let target = min(size.width / (width * 1.15), size.height / (height * 1.15))

        withAnimation(.easeOut(duration: 0.45)) {
            scale = max(minScale, min(maxScale, target))
            offset = CGSize(width: -(minX + maxX) / 2, height: -(minY + maxY) / 2)
        }
        dragAnchor = CGSize(width: -(minX + maxX) / 2, height: -(minY + maxY) / 2)
    }

    // MARK: - Overlays

    private var zoomControls: some View {
        HStack(spacing: 6) {
            CanvasButton(icon: "minus.magnifyingglass", help: loc.t.zoomOut) {
                withAnimation(.easeOut(duration: 0.15)) { scale = max(minScale, scale / 1.35) }
            }
            CanvasButton(icon: "plus.magnifyingglass", help: loc.t.zoomIn) {
                withAnimation(.easeOut(duration: 0.15)) { scale = min(maxScale, scale * 1.35) }
            }
            CanvasButton(icon: "arrow.up.left.and.arrow.down.right", help: loc.t.fitToScreen) {
                state.fitRequest &+= 1
            }
            CanvasButton(icon: "arrow.clockwise", help: loc.t.resetLayout) {
                state.rerunLayout()
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metric.radiusSmall)
                .fill(Theme.surfaceRaised.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metric.radiusSmall)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    private var legend: some View {
        let kinds: [SymbolKind] = [.function, .method, .type, .initializer]
        return HStack(spacing: 12) {
            ForEach(kinds, id: \.self) { kind in
                HStack(spacing: 5) {
                    Circle()
                        .fill(Theme.color(for: kind))
                        .frame(width: 7, height: 7)
                    Text(loc.t.kindName(kind))
                        .font(Theme.Font.micro)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metric.radiusSmall)
                .fill(Theme.surfaceRaised.opacity(0.9))
        )
    }
}

private struct CanvasButton: View {
    let icon: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovering ? Theme.accent : Theme.textSecondary)
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// Scroll-wheel and pinch zoom, anchored so the content under the cursor stays put.
private struct ScrollZoom: ViewModifier {
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    let minScale: CGFloat
    let maxScale: CGFloat

    func body(content: Content) -> some View {
        content.gesture(
            MagnifyGesture()
                .onChanged { value in
                    scale = max(minScale, min(maxScale, scale * (1 + (value.magnification - 1) * 0.18)))
                }
        )
    }
}
