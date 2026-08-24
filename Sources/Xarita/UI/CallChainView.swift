import SwiftUI

/// The path execution takes to reach what you are reading.
///
/// Sits directly above the source, because the question it answers — "how did
/// we get here?" — is the one a reader has while looking at the code, not
/// before opening it. The caller list says who *can* call this; the chain says
/// how the program actually arrives, from a starting point downwards.
struct CallChainView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    var body: some View {
        let chain = state.callChain
        if let graph = state.graph, chain.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 9) {
                    Text(loc.t.callChain.uppercased())
                        .font(Theme.Font.label)
                        .tracking(1.0)
                        .foregroundStyle(Theme.textTertiary)
                    Text(loc.t.callChainHint)
                        .font(Theme.Font.micro.weight(.regular))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer(minLength: 0)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(chain.enumerated()), id: \.offset) { index, id in
                            if index > 0 {
                                // The arrow points the way execution runs, and
                                // takes the downstream ink to say so.
                                Text("→")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.inkCyan.opacity(0.75))
                                    .padding(.horizontal, 7)
                            }
                            ChainLink(node: graph.nodes[id],
                                      isCurrent: id == state.selection)
                                .onTapGesture { state.select(id) }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
        }
    }
}

private struct ChainLink: View {
    let node: GraphNode
    let isCurrent: Bool
    @State private var hovering = false

    var body: some View {
        Text(node.displayName)
            .font(Theme.Font.monoSmall.weight(isCurrent ? .semibold : .regular))
            .foregroundStyle(isCurrent ? Theme.textPrimary : Theme.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isCurrent ? Theme.surfaceSunken
                                  : (hovering ? Theme.surfaceRaised : Color.clear))
            .overlay(alignment: .bottom) {
                // The current link is underlined rather than tinted — the same
                // rule the tabs use, for the same reason.
                Rectangle()
                    .fill(isCurrent ? Theme.textPrimary : Color.clear)
                    .frame(height: 1.5)
            }
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}
