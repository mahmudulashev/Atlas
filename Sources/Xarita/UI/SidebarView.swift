import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.border)
            searchField
            Divider().overlay(Theme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !state.searchText.isEmpty {
                        searchSection
                    } else {
                        statsSection
                        hubsSection
                        unreachableSection
                    }
                }
                .padding(.vertical, 14)
            }
            .scrollContentBackground(.hidden)
        }
        .background(Theme.surface)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 9) {
            MarkGlyph(size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(state.graph?.projectName ?? "—")
                    .font(Theme.Font.heading)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let g = state.graph {
                    Text(g.languageCounts
                            .sorted { $0.value > $1.value }
                            .prefix(3)
                            .map(\.key.displayName)
                            .joined(separator: " · "))
                        .font(Theme.Font.micro)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            TextField(loc.t.searchPlaceholder, text: $state.searchText)
                .textFieldStyle(.plain)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.textPrimary)
            if !state.searchText.isEmpty {
                Button { state.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var searchSection: some View {
        let results = state.searchResults
        return VStack(alignment: .leading, spacing: 4) {
            SectionLabel(loc.t.search, count: results.count)
            if results.isEmpty {
                Text(loc.t.noResults)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 12)
            } else {
                ForEach(results.prefix(60), id: \.self) { id in
                    NodeRow(id: id)
                }
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        Group {
            if let g = state.graph {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(loc.t.overview, count: nil)
                    VStack(spacing: 0) {
                        StatRow(label: loc.t.files,       value: loc.t.count(g.files.count))
                        StatRow(label: loc.t.lines,       value: loc.t.count(g.totalLines))
                        StatRow(label: loc.t.symbols,     value: loc.t.count(g.nodes.count))
                        StatRow(label: loc.t.connections, value: loc.t.count(g.edges.count))
                        StatRow(label: loc.t.parseTime,   value: loc.t.seconds(g.parseSeconds),
                                accent: true)
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }

    // MARK: - Hubs

    private var hubsSection: some View {
        Group {
            if let g = state.graph {
                let hubs = g.hubs(limit: 10)
                if !hubs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(loc.t.hubs, count: nil, hint: loc.t.hubsHint)
                        ForEach(hubs, id: \.self) { id in
                            NodeRow(id: id, trailing: "\(g.nodes[id].fanIn)")
                        }
                    }
                }
            }
        }
    }

    private var unreachableSection: some View {
        Group {
            if let g = state.graph {
                let dead = g.unreachable
                if !dead.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(loc.t.unreachable, count: dead.count,
                                     hint: loc.t.unreachableHint)
                        ForEach(dead.prefix(12), id: \.self) { id in
                            NodeRow(id: id)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Pieces

struct SectionLabel: View {
    let title: String
    var count: Int?
    var hint: String?

    init(_ title: String, count: Int?, hint: String? = nil) {
        self.title = title
        self.count = count
        self.hint = hint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(title.uppercased())
                    .font(Theme.Font.micro)
                    .tracking(0.7)
                    .foregroundStyle(Theme.textTertiary)
                if let count {
                    Text("\(count)")
                        .font(Theme.Font.micro)
                        .foregroundStyle(Theme.textTertiary.opacity(0.7))
                }
                Spacer(minLength: 0)
            }
            if let hint {
                Text(hint)
                    .font(Theme.Font.micro)
                    .foregroundStyle(Theme.textTertiary.opacity(0.75))
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var accent: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(Theme.Font.mono)
                .foregroundStyle(accent ? Theme.accent : Theme.textPrimary)
        }
        .padding(.vertical, 3)
    }
}

struct NodeRow: View {
    @EnvironmentObject private var state: AppState
    let id: Int
    var trailing: String? = nil
    @State private var hovering = false

    var body: some View {
        if let g = state.graph, id < g.nodes.count {
            let node = g.nodes[id]
            Button {
                state.select(id)
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Theme.color(for: node.kind, external: node.isExternal))
                        .frame(width: 6, height: 6)
                    Text(node.displayName)
                        .font(Theme.Font.monoSmall)
                        .foregroundStyle(state.selection == id ? Theme.accent : Theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    if let trailing {
                        Text(trailing)
                            .font(Theme.Font.micro)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Rectangle()
                        .fill(state.selection == id ? Theme.accentMuted
                              : (hovering ? Theme.surfaceRaised : Color.clear))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
        }
    }
}
