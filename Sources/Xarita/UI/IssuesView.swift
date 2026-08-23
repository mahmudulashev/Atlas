import SwiftUI

/// The findings list: what in this codebase is worth a second look.
///
/// Every row points at a real file and line, because a report you cannot act on
/// is just a source of guilt. Clicking one opens it.
struct IssuesView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if state.issues.isEmpty {
                    emptyState
                } else {
                    ForEach(Issue.Severity.allOrdered, id: \.self) { severity in
                        let group = state.issues.filter { $0.severity == severity }
                        if !group.isEmpty {
                            section(severity: severity, issues: group)
                        }
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .background(PaperBackground())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(loc.t.issuesTitle)
                    .font(Theme.Font.display)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(state.issues.count)")
                    .font(Theme.Font.number)
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 0)
            }
            Text(loc.t.issuesHint)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Theme.color(for: .easy))
            Text(loc.t.issuesNone)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 30)
    }

    private func section(severity: Issue.Severity, issues: [Issue]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color(for: severity))
                    .frame(width: 3, height: 12)
                Text(loc.t.severityName(severity).uppercased())
                    .font(Theme.Font.micro.weight(.bold))
                    .tracking(0.9)
                    .foregroundStyle(color(for: severity))
                Text("\(issues.count)")
                    .font(Theme.Font.micro.monospacedDigit())
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 0)
            }

            VStack(spacing: 5) {
                ForEach(issues) { issue in
                    IssueRow(issue: issue, tint: color(for: issue.severity))
                }
            }
        }
    }

    private func color(for severity: Issue.Severity) -> Color {
        switch severity {
        case .high:   return Theme.marker
        case .medium: return Theme.gold
        case .low:    return Theme.textTertiary
        }
    }
}

private struct IssueRow: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    let issue: Issue
    let tint: Color
    @State private var hovering = false
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if let id = issue.symbolID { state.select(id) } else { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 11) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tint)
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(issue.title(loc.language))
                                .font(Theme.Font.caption.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text(measurement)
                                .font(Theme.Font.micro.monospacedDigit())
                                .foregroundStyle(Theme.textTertiary)
                            Spacer(minLength: 0)
                        }
                        Text(issue.subject)
                            .font(Theme.Font.monoSmall)
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(issue.advice(loc.language))
                            .font(Theme.Font.micro)
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        if !issue.file.isEmpty {
                            Text("\(issue.file):\(issue.line)")
                                .font(Theme.Font.micro)
                                .foregroundStyle(Theme.textTertiary.opacity(0.8))
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                    }
                    .padding(.vertical, 9)
                    .padding(.trailing, 10)
                }
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(hovering ? Theme.surfaceRaised : Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(hovering ? tint.opacity(0.5) : Theme.border, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
        }
    }

    /// The numbers behind the finding, spelled out rather than left as a code.
    private var measurement: String {
        let parts = issue.detail.split(separator: "·").map { $0.trimmingCharacters(in: .whitespaces) }
        switch issue.kind {
        case .complexFunction where parts.count == 3:
            return loc.language == .uz
                ? "\(parts[0]) shart · \(parts[1]) qavat · \(parts[2]) qator"
                : "\(parts[0]) branches · \(parts[1]) deep · \(parts[2]) lines"
        case .oversizedFile:
            return loc.language == .uz ? "\(issue.detail) ta" : "\(issue.detail)"
        case .godFunction:
            return loc.language == .uz ? "\(issue.detail) ta chaqiruv" : "\(issue.detail) callers"
        case .unreachable:
            return loc.language == .uz ? "\(issue.detail) qator" : "\(issue.detail) lines"
        case .cycle:
            return loc.language == .uz ? "\(issue.detail) ta fayl" : "\(issue.detail) files"
        case .layerViolation:
            return loc.language == .uz ? "\(issue.detail) ta chaqiruv" : "\(issue.detail) calls"
        default:
            return issue.detail
        }
    }
}

extension Issue.Severity {
    static var allOrdered: [Issue.Severity] { [.high, .medium, .low] }
}
