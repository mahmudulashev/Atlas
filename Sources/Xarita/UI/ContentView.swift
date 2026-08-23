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
            } else if state.mode == .orientation {
                OrientationView()
            } else {
                reading
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
