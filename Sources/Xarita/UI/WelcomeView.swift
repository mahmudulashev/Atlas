import SwiftUI
import UniformTypeIdentifiers

/// First run, and the state after closing a project.
struct WelcomeView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            VStack(spacing: 18) {
                MarkGlyph(size: 76)

                VStack(spacing: 6) {
                    Text("Xarita")
                        .font(Theme.Font.display)
                        .foregroundStyle(Theme.textPrimary)
                    Text(loc.t.appTagline)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer(minLength: 30)

            dropZone
                .frame(maxWidth: 460)
                .padding(.horizontal, 40)

            Text(loc.t.welcomeBody)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 420)
                .padding(.top, 16)

            if !state.recentProjects.isEmpty {
                recents.padding(.top, 30)
            }

            Spacer(minLength: 30)

            languageStrip.padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    // MARK: - Drop zone

    private var dropZone: some View {
        VStack(spacing: 14) {
            Image(systemName: isTargeted ? "folder.fill" : "folder")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(isTargeted ? Theme.accent : Theme.textTertiary)

            Text(isTargeted ? loc.t.dropHere : loc.t.welcomeTitle)
                .font(Theme.Font.heading)
                .foregroundStyle(Theme.textPrimary)

            Button(loc.t.chooseFolder) { state.chooseProject() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isTargeted ? Theme.accentMuted : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.4, dash: [7, 5]))
                .foregroundStyle(isTargeted ? Theme.accent : Theme.border)
        )
        .animation(.easeOut(duration: 0.15), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path,
                                                        isDirectory: &isDirectory)
            guard exists else { return }
            let target = isDirectory.boolValue ? url : url.deletingLastPathComponent()
            Task { @MainActor in state.open(target) }
        }
        return true
    }

    // MARK: - Recents

    private var recents: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(loc.t.recentProjects.uppercased())
                .font(Theme.Font.micro)
                .tracking(0.7)
                .foregroundStyle(Theme.textTertiary)

            VStack(spacing: 2) {
                ForEach(state.recentProjects.prefix(5), id: \.self) { url in
                    Button {
                        state.open(url)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textTertiary)
                            Text(url.lastPathComponent)
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.textPrimary)
                            Text(url.deletingLastPathComponent().path
                                    .replacingOccurrences(of: SharedPaths.realHome.path, with: "~"))
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.head)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(RowButtonStyle())
                }
            }
        }
        .frame(width: 460, alignment: .leading)
    }

    // MARK: - Language strip

    private var languageStrip: some View {
        VStack(spacing: 8) {
            Text(loc.t.supportedLanguages.uppercased())
                .font(Theme.Font.micro)
                .tracking(0.7)
                .foregroundStyle(Theme.textTertiary)

            Text(Language.allCases.map(\.displayName).joined(separator: " · "))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
    }
}

/// The app mark: a small node-and-edge cluster, drawn rather than shipped as an
/// image so it stays crisp at any size and follows the theme.
struct MarkGlyph: View {
    var size: CGFloat = 64

    private static let nodes: [(CGPoint, CGFloat)] = [
        (CGPoint(x: 0.50, y: 0.22), 0.115),
        (CGPoint(x: 0.20, y: 0.52), 0.082),
        (CGPoint(x: 0.80, y: 0.50), 0.082),
        (CGPoint(x: 0.38, y: 0.82), 0.062),
        (CGPoint(x: 0.66, y: 0.80), 0.062),
    ]
    private static let links: [(Int, Int)] = [(0, 1), (0, 2), (1, 3), (2, 4), (3, 4), (1, 2)]

    var body: some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            func p(_ n: CGPoint) -> CGPoint { CGPoint(x: n.x * s, y: n.y * s) }

            for (a, b) in Self.links {
                var path = Path()
                path.move(to: p(Self.nodes[a].0))
                path.addLine(to: p(Self.nodes[b].0))
                context.stroke(path, with: .color(Theme.accent.opacity(0.42)),
                               lineWidth: max(1, s * 0.016))
            }
            for (index, node) in Self.nodes.enumerated() {
                let r = node.1 * s
                let center = p(node.0)
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                context.fill(Circle().path(in: rect),
                             with: .color(index == 0 ? Theme.gold : Theme.accent))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Button styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.body.weight(.medium))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metric.radiusSmall)
                    .fill(Theme.accent.opacity(configuration.isPressed ? 0.78 : 1))
            )
            .contentShape(Rectangle())
    }
}

struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: Theme.Metric.radiusSmall)
                    .fill(configuration.isPressed ? Theme.accentMuted : Color.clear)
            )
    }
}
