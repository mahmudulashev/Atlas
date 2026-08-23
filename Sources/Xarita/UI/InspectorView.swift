import SwiftUI
import AppKit

/// Details for the selected declaration: where it lives, what reaches it, and
/// what it reaches. The two neighbour lists are the working end of the app —
/// they are the answer to "how did execution get here" and "what breaks if I
/// change this".
struct InspectorView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    var body: some View {
        if let graph = state.graph,
           let id = state.selection,
           id < graph.nodes.count {
            let node = graph.nodes[id]
            let (callers, callees) = graph.neighbours(of: id)

            VStack(spacing: 0) {
                header(node: node)
                Divider().overlay(Theme.border)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        location(node: node, graph: graph)
                        neighbours(title: loc.t.callers, ids: callers,
                                   empty: loc.t.noCallers, tint: Theme.edgeIncoming)
                        neighbours(title: loc.t.callees, ids: callees,
                                   empty: loc.t.noCallees, tint: Theme.edgeOutgoing)
                    }
                    .padding(.vertical, 14)
                }
                .scrollContentBackground(.hidden)
            }
            .background(Theme.surface)
        }
    }

    // MARK: - Header

    private func header(node: GraphNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(Theme.color(for: node.kind, external: node.isExternal))
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(Theme.Font.title)
                        .foregroundStyle(Theme.textPrimary)
                        .textSelection(.enabled)
                    if let container = node.container {
                        Text(container)
                            .font(Theme.Font.monoSmall)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer(minLength: 0)

                Button { state.select(nil) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                Chip(text: loc.t.kindName(node.kind),
                     color: Theme.color(for: node.kind, external: node.isExternal))
                Chip(text: node.language.displayName, color: Theme.textTertiary)
                if node.span > 1 {
                    Chip(text: "\(node.span) \(loc.t.lines.lowercased())", color: Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Location

    private func location(node: GraphNode, graph: CodeGraph) -> some View {
        Group {
            if node.fileIndex >= 0, node.fileIndex < graph.files.count {
                let relative = graph.files[node.fileIndex]
                let full = (graph.rootPath as NSString).appendingPathComponent(relative)

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(loc.t.definedIn, count: nil)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(relative)
                            .font(Theme.Font.monoSmall)
                            .foregroundStyle(Theme.textPrimary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(loc.t.lines.lowercased()) \(node.line)–\(node.endLine)")
                            .font(Theme.Font.micro)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.horizontal, 14)

                    HStack(spacing: 6) {
                        SmallAction(icon: "arrow.up.forward.square", title: loc.t.openInEditor) {
                            openInEditor(path: full, line: node.line)
                        }
                        SmallAction(icon: "doc.on.doc", title: loc.t.copyPath) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(full, forType: .string)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 2)
                }
            }
        }
    }

    /// Hands the file to whatever the user has set as their editor. `xed` would
    /// force Xcode; `open` respects the default application for the file type.
    private func openInEditor(path: String, line: Int) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }

    // MARK: - Neighbours

    private func neighbours(title: String, ids: [Int], empty: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(tint)
                    .frame(width: 2, height: 10)
                Text(title.uppercased())
                    .font(Theme.Font.micro)
                    .tracking(0.7)
                    .foregroundStyle(Theme.textTertiary)
                Text("\(ids.count)")
                    .font(Theme.Font.micro)
                    .foregroundStyle(Theme.textTertiary.opacity(0.7))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)

            if ids.isEmpty {
                Text(empty)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 14)
                    .padding(.top, 2)
            } else {
                ForEach(ids.prefix(40), id: \.self) { id in
                    NodeRow(id: id)
                }
                if ids.count > 40 {
                    Text("+\(ids.count - 40)")
                        .font(Theme.Font.micro)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 14)
                        .padding(.top, 3)
                }
            }
        }
    }
}

struct Chip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(Theme.Font.micro)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.13))
            )
    }
}

struct SmallAction: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(title).font(Theme.Font.micro)
            }
            .foregroundStyle(hovering ? Theme.accent : Theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(hovering ? Theme.accentMuted : Theme.surfaceRaised)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
