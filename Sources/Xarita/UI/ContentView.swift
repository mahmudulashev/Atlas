import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization
    @EnvironmentObject private var explainer: Explainer

    var body: some View {
        Group {
            if state.isAnalyzing {
                AnalysisProgressView()
            } else if state.graph == nil {
                WelcomeView()
            } else {
                VStack(spacing: 0) {
                    ModeBar()
                    Divider().overlay(Theme.border)
                    switch state.mode {
                    case .orientation:  OrientationView()
                    case .architecture: ArchitectureView()
                    case .issues:       IssuesView()
                    case .reading:      reading
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: state.isAnalyzing)
        .animation(.easeInOut(duration: 0.18), value: state.graph == nil)
        .animation(.easeInOut(duration: 0.2), value: state.mode)
    }

    /// Route on the left, the code in the middle, what it means on the right.
    private var reading: some View {
        HStack(spacing: 0) {
            RouteRail()
                .frame(width: Theme.Metric.sidebarWidth)
            Divider().overlay(Theme.border)

            VStack(spacing: 0) {
                StepBar()
                Divider().overlay(Theme.border)
                CallTreeView()
                Divider().overlay(Theme.border)
                SourceView()
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)

            Divider().overlay(Theme.border)
            ExplainPanel()
                .frame(width: Theme.Metric.inspectorWidth)
        }
    }
}

/// Position along the route, with the only two controls that matter while
/// reading: back a step, forward a step.
struct StepBar: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    var body: some View {
        HStack(spacing: 12) {
            if let index = state.currentStepIndex {
                HStack(spacing: 7) {
                    Circle().fill(Theme.marker).frame(width: 7, height: 7)
                    Text("\(loc.t.stepWord.capitalized) \(index + 1) / \(state.route.steps.count)")
                        .font(Theme.Font.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                }
            } else {
                Text(loc.t.everythingElse)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 0)

            Button {
                state.previousStep()
            } label: {
                Label(loc.t.prevStepLabel, systemImage: "chevron.left")
                    .font(Theme.Font.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(state.canGoPreviousStep ? Theme.textSecondary : Theme.textTertiary.opacity(0.4))
            .disabled(!state.canGoPreviousStep)

            Button {
                state.nextStep()
            } label: {
                HStack(spacing: 4) {
                    Text(loc.t.nextStepLabel)
                    Image(systemName: "chevron.right")
                }
                .font(Theme.Font.caption.weight(.medium))
                .foregroundStyle(state.canGoNextStep ? Color.white : Theme.textTertiary)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(state.canGoNextStep ? Theme.accent : Theme.surfaceRaised))
            }
            .buttonStyle(.plain)
            .disabled(!state.canGoNextStep)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Theme.surface)
    }
}

/// Shown while an analysis runs.
struct AnalysisProgressView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    private var stageText: String {
        switch state.progress?.stage {
        case .scanning:  return loc.t.stageScanning
        case .parsing:   return loc.t.stageParsing
        case .resolving: return loc.t.stageResolving
        default:         return loc.t.analyzing
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            MarkGlyph(size: 54)
            VStack(spacing: 7) {
                Text(stageText)
                    .font(Theme.Font.heading)
                    .foregroundStyle(Theme.textPrimary)
                if let p = state.progress, p.total > 0 {
                    Text("\(p.current) / \(p.total)")
                        .font(Theme.Font.mono.monospacedDigit())
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Group {
                if let p = state.progress, p.total > 0 {
                    ProgressView(value: Double(p.current), total: Double(p.total))
                } else {
                    ProgressView()
                }
            }
            .progressViewStyle(.linear)
            .tint(Theme.accent)
            .frame(width: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PaperBackground())
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization
    @EnvironmentObject private var explainer: Explainer
    @State private var notify = Notifier.isEnabled

    var body: some View {
        Form {
            Picker(loc.t.interfaceLanguage, selection: $loc.language) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.segmented)

            Toggle(loc.t.notifyOnFinish, isOn: $notify)
                .onChange(of: notify) { _, value in Notifier.isEnabled = value }

            LabeledContent(loc.t.whatThisDoes) {
                Text(explainer.modelState.canGenerate ? "✓" : "—")
                    .foregroundStyle(explainer.modelState.canGenerate
                                     ? Theme.color(for: .easy) : Theme.textTertiary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .padding(.vertical, 6)
    }
}


/// Switches between the three ways of looking at a project.
struct ModeBar: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                tab(loc.t.overviewTab, icon: "square.text.square", mode: .orientation) {
                    state.showOrientation()
                }
                tab(loc.t.architecture, icon: "rectangle.3.group", mode: .architecture) {
                    state.showArchitecture()
                }
                tab(loc.t.issuesTab, icon: "exclamationmark.triangle", mode: .issues,
                    badge: state.issues.isEmpty ? nil : "\(state.issues.count)") {
                    state.showIssues()
                }
                tab(loc.t.readingTab, icon: "text.alignleft", mode: .reading) {
                    state.beginReading()
                }
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surfaceSunken))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border, lineWidth: 1))

            if state.mode == .architecture {
                Text(loc.t.architectureHint)
                    .font(Theme.Font.micro)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Toggle(loc.t.showTests, isOn: $state.showTestsInDiagram)
                    .toggleStyle(.checkbox)
                    .font(Theme.Font.micro)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Theme.surface)
    }

    private func tab(_ title: String, icon: String, mode: AppState.Mode,
                     badge: String? = nil, action: @escaping () -> Void) -> some View {
        let selected = state.mode == mode
        return Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10.5))
                Text(title).font(Theme.Font.caption.weight(selected ? .semibold : .regular))
                if let badge {
                    Text(badge)
                        .font(Theme.Font.micro.weight(.bold).monospacedDigit())
                        .foregroundStyle(selected ? Theme.accent : Color.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 0.5)
                        .background(Capsule().fill(selected ? Color.white : Theme.marker))
                }
            }
            .foregroundStyle(selected ? Color.white : Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4.5)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(selected ? Theme.accent : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
