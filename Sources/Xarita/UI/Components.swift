import SwiftUI

/// A visible, one-click language switch.
///
/// The interface language lives in the app rather than following the system,
/// so it needs to be reachable without hunting through a menu — someone who
/// opened the app in the wrong language should not have to read that language
/// to find the switch.
struct LanguageToggle: View {
    @EnvironmentObject private var loc: Localization
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppLanguage.allCases, id: \.self) { lang in
                let selected = loc.language == lang
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { loc.language = lang }
                } label: {
                    Text(compact ? lang.flagless : lang.displayName)
                        .font(compact ? Theme.Font.micro.weight(.semibold)
                                      : Theme.Font.caption.weight(.medium))
                        .foregroundStyle(selected ? Color.white : Theme.textSecondary)
                        .padding(.horizontal, compact ? 8 : 12)
                        .padding(.vertical, compact ? 3.5 : 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(selected ? Theme.accent : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(lang.displayName)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surfaceSunken))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.border, lineWidth: 1))
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
            .background(RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.13)))
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
            .background(RoundedRectangle(cornerRadius: 4)
                .fill(hovering ? Theme.accentMuted : Theme.surfaceRaised))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}


/// Renders inline markdown from a runtime string.
///
/// SwiftUI only interprets markdown in `Text` when it is given a *literal*;
/// a `String` built at runtime is drawn verbatim, backticks and asterisks
/// included. Explanations are assembled at runtime, so they are parsed here and
/// their code spans and emphasis are styled explicitly.
struct RichText: View {
    let raw: String
    var font: Font = Theme.Font.body
    var color: Color = Theme.textPrimary

    var body: some View {
        Text(attributed)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    private var attributed: AttributedString {
        guard var text = try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        else {
            var plain = AttributedString(raw)
            plain.font = font
            plain.foregroundColor = color
            return plain
        }

        text.font = font
        text.foregroundColor = color

        for run in text.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            if intent.contains(.code) {
                text[run.range].font = Theme.Font.mono
                text[run.range].foregroundColor = Theme.codeFunction
            }
            if intent.contains(.stronglyEmphasized) {
                text[run.range].font = font.weight(.semibold)
                text[run.range].foregroundColor = Theme.accent
            }
            if intent.contains(.emphasized) {
                text[run.range].font = font.italic()
            }
        }
        return text
    }
}

/// A small caps section heading, optionally with a count and an explanatory line.
struct SectionLabel: View {
    let title: String
    var count: Int?
    var hint: String?

    init(_ title: String, count: Int? = nil, hint: String? = nil) {
        self.title = title
        self.count = count
        self.hint = hint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(title.uppercased())
                    .font(Theme.Font.micro)
                    .tracking(0.8)
                    .foregroundStyle(Theme.textTertiary)
                if let count {
                    Text("\(count)")
                        .font(Theme.Font.micro.monospacedDigit())
                        .foregroundStyle(Theme.textTertiary.opacity(0.7))
                }
                Spacer(minLength: 0)
            }
            if let hint {
                Text(hint)
                    .font(Theme.Font.micro)
                    .foregroundStyle(Theme.textTertiary.opacity(0.8))
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 2)
    }
}
