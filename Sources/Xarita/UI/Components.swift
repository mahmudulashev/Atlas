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
