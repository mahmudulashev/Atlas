import SwiftUI
import AppKit

/// "What this does" — the panel a junior developer actually reads.
///
/// Always shows the static explanation, which is derived from the graph and so
/// is available on every machine. When Apple's on-device model is enabled, a
/// generated explanation appears above it. The app never blocks on the model
/// and never requires it.
struct ExplainPanel: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization
    @EnvironmentObject private var explainer: Explainer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let graph = state.graph, let id = state.selection,
                       id < graph.nodes.count {
                        let node = graph.nodes[id]

                        aiSection(node: node, graph: graph)
                        factsSection(node: node, graph: graph)
                        detailsSection(node: node, graph: graph)
                    } else {
                        Text(loc.t.pickSomething)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.top, 8)
                    }
                }
                .padding(.vertical, 14)
            }
            .scrollContentBackground(.hidden)
        }
        .background(Theme.surface)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 11))
                .foregroundStyle(Theme.accent)
            Text(loc.t.whatThisDoes)
                .font(Theme.Font.heading)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Generated explanation

    @ViewBuilder
    private func aiSection(node: GraphNode, graph: CodeGraph) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if explainer.modelState.canGenerate {
                let cached = explainer.cache[node.id]
                let text = cached ?? explainer.streaming

                if !text.isEmpty {
                    Text(text)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                }

                if explainer.isGenerating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(loc.t.thinking)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.horizontal, 14)
                } else if text.isEmpty {
                    Button(loc.t.explainThis) {
                        state.requestExplanation(explainer: explainer, language: loc.language)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 14)
                }

                Text(loc.t.onDeviceNote)
                    .font(Theme.Font.micro)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 14)
            } else {
                modelUnavailableCard
            }
        }
    }

    private var modelUnavailableCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.gold)
                Text(loc.t.aiOffTitle)
                    .font(Theme.Font.caption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(reasonText)
                .font(Theme.Font.micro)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if explainer.modelState == .needsAppleIntelligence {
                Button(loc.t.openSettings) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?AppleIntelligence") {
                        NSWorkspace.shared.open(url)
                    }
                    explainer.refreshAvailability()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 2)
            }
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surfaceRaised))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border, lineWidth: 1))
        .padding(.horizontal, 14)
    }

    private var reasonText: String {
        switch explainer.modelState {
        case .needsAppleIntelligence: return loc.t.aiOffNeedsEnable
        case .modelDownloading:       return loc.t.aiOffDownloading
        case .ineligibleDevice:       return loc.t.aiOffIneligible
        case .unsupportedOS:          return loc.t.aiOffOldOS
        default:                      return ""
        }
    }

    // MARK: - Static facts

    private func factsSection(node: GraphNode, graph: CodeGraph) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(loc.t.theFacts, count: nil)
            Text(Explainer.staticExplanation(node: node, graph: graph, t: loc.t))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
        }
    }

    private func detailsSection(node: GraphNode, graph: CodeGraph) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(loc.t.definedIn, count: nil)
            VStack(alignment: .leading, spacing: 3) {
                if node.fileIndex >= 0, node.fileIndex < graph.files.count {
                    Text(graph.files[node.fileIndex])
                        .font(Theme.Font.monoSmall)
                        .foregroundStyle(Theme.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 6) {
                    Chip(text: loc.t.kindName(node.kind),
                         color: Theme.color(for: node.kind, external: node.isExternal))
                    Chip(text: node.language.displayName, color: Theme.textTertiary)
                    Chip(text: "\(node.line)–\(node.endLine)", color: Theme.textTertiary)
                }
            }
            .padding(.horizontal, 14)
        }
    }
}
