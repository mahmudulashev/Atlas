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
                        difficultySection(node: node)
                        factsSection(node: node, graph: graph)
                        glossarySection(node: node, graph: graph)
                        detailsSection(node: node, graph: graph)
                        understoodButton(id: node.id)
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

                if explainer.fellBackToEnglish && !text.isEmpty {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.gold)
                            .padding(.top, 1)
                        Text(loc.t.englishFallbackNote)
                            .font(Theme.Font.micro)
                            .foregroundStyle(Theme.textTertiary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

    // MARK: - Difficulty

    /// Tells a beginner whether to expect a fight before they start reading.
    private func difficultySection(node: GraphNode) -> some View {
        Group {
            if node.kind.isCallable, !node.isExternal {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(loc.t.howHard, count: nil)
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { step in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(step <= node.difficulty.rawValue
                                          ? Theme.color(for: node.difficulty)
                                          : Theme.border)
                                    .frame(width: 16, height: 4)
                            }
                        }
                        Text(loc.t.difficultyName(node.difficulty))
                            .font(Theme.Font.caption.weight(.medium))
                            .foregroundStyle(Theme.color(for: node.difficulty))
                        Spacer(minLength: 0)
                    }
                    Text(loc.t.difficultyReason(node))
                        .font(Theme.Font.micro)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 14)
            }
        }
    }

    // MARK: - Glossary

    /// Terms that appear in the code on screen, explained in the reader's own
    /// language. Beginners lose time to unfamiliar vocabulary at least as often
    /// as to unfamiliar logic.
    private func glossarySection(node: GraphNode, graph: CodeGraph) -> some View {
        Group {
            if let snippet = state.sourceCache.snippet(for: node, in: graph) {
                let terms = Glossary.found(in: snippet.text, language: node.language)
                if !terms.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        SectionLabel(loc.t.glossary, count: nil, hint: loc.t.glossaryHint)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(terms, id: \.key) { term in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Glossary.title(term, language: loc.language))
                                        .font(Theme.Font.monoSmall.weight(.semibold))
                                        .foregroundStyle(Theme.codeKeyword)
                                    Text(Glossary.body(term, language: loc.language))
                                        .font(Theme.Font.micro)
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineSpacing(2.5)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(9)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 7)
                                    .fill(Theme.surfaceRaised))
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                }
            }
        }
    }

    // MARK: - Progress

    private func understoodButton(id: Int) -> some View {
        let done = state.isUnderstood(id)
        return Button {
            state.toggleUnderstood(id)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(done ? Theme.color(for: .easy) : Theme.textTertiary)
                Text(done ? loc.t.understoodMark : loc.t.understood)
                    .font(Theme.Font.caption.weight(.medium))
                    .foregroundStyle(done ? Theme.color(for: .easy) : Theme.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 7)
                .fill(done ? Theme.color(for: .easy).opacity(0.11) : Theme.surfaceRaised))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .strokeBorder(done ? Theme.color(for: .easy).opacity(0.4) : Theme.border,
                              lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 2)
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
