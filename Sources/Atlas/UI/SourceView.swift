import SwiftUI
import AppKit

/// The selected declaration's actual source, with line numbers.
struct SourceView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    var body: some View {
        if let graph = state.graph,
           let id = state.selection,
           id < graph.nodes.count,
           let snippet = state.sourceCache.snippet(for: graph.nodes[id], in: graph) {

            let node = graph.nodes[id]
            let lines = snippet.text.components(separatedBy: "\n")
            let highlighted = SyntaxHighlighter.highlight(snippet.text, language: node.language)
            let perLine = splitAttributed(highlighted, lineCount: lines.count)

            VStack(spacing: 0) {
                sourceHeader(node: node, graph: graph)
                Divider().overlay(Theme.border)

                ScrollView([.vertical, .horizontal]) {
                    HStack(alignment: .top, spacing: 0) {
                        // Gutter
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach(lines.indices, id: \.self) { i in
                                Text("\(snippet.firstLine + i)")
                                    .font(Theme.Font.monoSmall)
                                    .foregroundStyle(Theme.codeGutter)
                                    .frame(height: 17, alignment: .trailing)
                            }
                        }
                        .padding(.trailing, 10)
                        .padding(.leading, 12)

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(perLine.indices, id: \.self) { i in
                                Text(perLine[i])
                                    .font(Theme.Font.mono)
                                    .frame(height: 17, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.trailing, 20)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                }
                .background(Theme.codeBackground)
            }
        } else if state.selection == nil {
            emptyState
        }
    }

    private func sourceHeader(node: GraphNode, graph: CodeGraph) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Theme.color(for: node.kind, external: node.isExternal))
                .frame(width: 7, height: 7)
            Text(node.displayName)
                .font(Theme.Font.mono.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
            Text(node.fileIndex >= 0 ? graph.files[node.fileIndex] : "")
                .font(Theme.Font.micro)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .truncationMode(.head)
            Spacer(minLength: 8)
            if let path = state.sourceCache.absolutePath(for: node, in: graph) {
                SmallAction(icon: "arrow.up.forward.square", title: loc.t.openInEditor) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "curlybraces")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text(loc.t.pickSomething)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.codeBackground)
    }

    /// Splits one highlighted blob back into per-line pieces so the gutter and
    /// the code stay aligned row for row.
    private func splitAttributed(_ source: AttributedString, lineCount: Int) -> [AttributedString] {
        var result: [AttributedString] = []
        var current = AttributedString()

        for run in source.runs {
            let text = String(source[run.range].characters)
            let pieces = text.components(separatedBy: "\n")
            for (i, piece) in pieces.enumerated() {
                if i > 0 {
                    result.append(current)
                    current = AttributedString()
                }
                var attributed = AttributedString(piece)
                attributed.setAttributes(source[run.range].runs.first?.attributes ?? .init())
                current.append(attributed)
            }
        }
        result.append(current)

        while result.count < lineCount { result.append(AttributedString()) }
        return Array(result.prefix(max(lineCount, 1)))
    }
}
