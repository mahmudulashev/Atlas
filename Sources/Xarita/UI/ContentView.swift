import SwiftUI
import AppKit
import UserNotifications

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
                    case .atlas:  AtlasView()
                    case .map: ArchitectureView()
                    case .review:       IssuesView()
                    case .read:      reading
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
                CallChainView()
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
    @State private var authorization: UNAuthorizationStatus?

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

            // Whether macOS actually granted permission is invisible from
            // inside the app unless it is asked for and shown; without this the
            // only symptom of a denied prompt is silence.
            LabeledContent(loc.t.notifications) {
                HStack(spacing: 6) {
                    Text(loc.t.authorizationName(authorization))
                        .foregroundStyle(authorization == .authorized
                                         ? Theme.inkCyanDeep : Theme.textSecondary)
                    if authorization == .denied {
                        Button(loc.t.openSettings) {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }
                }
            }

            LabeledContent(loc.t.whatThisDoes) {
                Text(explainer.modelState.canGenerate ? "✓" : "—")
                    .foregroundStyle(explainer.modelState.canGenerate
                                     ? Theme.color(for: .easy) : Theme.textTertiary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 430)
        .padding(.vertical, 6)
        .task { authorization = await Notifier.authorizationStatus() }
    }
}


/// The four ways of looking at a project.
///
/// Set as a masthead rather than a control strip: the label in the serif, its
/// hint underneath, and the current tab marked by a rule of cyan under the
/// word. A filled pill would put a block of colour next to two inks that
/// already mean something, so the selection is drawn the way a printed page
/// marks a running head — with a rule.
struct ModeBar: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    var body: some View {
        HStack(alignment: .bottom, spacing: 26) {
            tab(loc.t.tabAtlas,  hint: loc.t.tabAtlasHint, mode: .atlas)  { state.showAtlas() }
            tab(loc.t.tabMap,    hint: loc.t.tabMapHint,   mode: .map)    { state.showMap() }
            tab(loc.t.tabRead,   hint: loc.t.tabReadHint(state.route.steps.count),
                mode: .read) { state.beginReading() }
            tab(loc.t.tabReview, hint: loc.t.tabReviewHint(state.issues.count),
                mode: .review) { state.showReview() }

            Spacer(minLength: 0)

            if state.mode == .map {
                viewSwitch
                Toggle(loc.t.showTests, isOn: $state.showTestsInDiagram)
                    .toggleStyle(.checkbox)
                    .font(Theme.Font.micro)
                    .foregroundStyle(Theme.textSecondary)
            }
            LanguageToggle(compact: true)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 0)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    /// Ladder or matrix. A hairline segmented control — print chrome, not a
    /// filled pill, for the same reason the tabs are underlined.
    private var viewSwitch: some View {
        HStack(spacing: 0) {
            segment(loc.t.viewLadder, view: .ladder)
            Rectangle().fill(Theme.border).frame(width: 1, height: 20)
            segment(loc.t.viewMatrix, view: .matrix)
        }
        .overlay(Rectangle().strokeBorder(Theme.border, lineWidth: 1))
        .padding(.bottom, 9)
    }

    private func segment(_ title: String, view: AppState.MapView) -> some View {
        let selected = state.mapView == view
        return Button { state.mapView = view } label: {
            Text(title)
                .font(Theme.Font.micro)
                .foregroundStyle(selected ? Theme.background : Theme.textSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(selected ? Theme.textPrimary : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tab(_ title: String, hint: String,
                     mode: AppState.Mode, action: @escaping () -> Void) -> some View {
        let selected = state.mode == mode
        return Button(action: action) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.Font.heading)
                    .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                Text(hint)
                    .font(Theme.Font.micro.weight(.regular))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.bottom, 9)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(selected ? Theme.inkCyan : Color.clear)
                    .frame(height: 3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
