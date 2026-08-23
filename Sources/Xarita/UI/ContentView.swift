import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    var body: some View {
        Group {
            if state.isAnalyzing {
                AnalysisProgressView()
            } else if state.graph == nil {
                WelcomeView()
            } else {
                workspace
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.isAnalyzing)
        .animation(.easeInOut(duration: 0.2), value: state.graph == nil)
    }

    private var workspace: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: Theme.Metric.sidebarWidth)
            Divider().overlay(Theme.border)

            GraphCanvas()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if state.selection != nil {
                Divider().overlay(Theme.border)
                InspectorView()
                    .frame(width: Theme.Metric.inspectorWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: state.selection == nil)
    }
}

/// Shown while an analysis runs. Stage names are translated; the counter uses
/// tabular figures so it doesn't shuffle as it climbs.
struct AnalysisProgressView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization

    private var stageText: String {
        switch state.progress?.stage {
        case .scanning:  return loc.t.stageScanning
        case .parsing:   return loc.t.stageParsing
        case .resolving: return loc.t.stageResolving
        case .laying:    return loc.t.stageLaying
        default:         return loc.t.analyzing
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            MarkGlyph(size: 58)
                .opacity(0.9)

            VStack(spacing: 7) {
                Text(stageText)
                    .font(Theme.Font.heading)
                    .foregroundStyle(Theme.textPrimary)

                if let p = state.progress, p.total > 0 {
                    Text("\(p.current) / \(p.total)")
                        .font(Theme.Font.mono)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            if let p = state.progress, p.total > 0 {
                ProgressView(value: Double(p.current), total: Double(p.total))
                    .progressViewStyle(.linear)
                    .tint(Theme.accent)
                    .frame(width: 260)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Theme.accent)
                    .frame(width: 260)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var loc: Localization
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

            Toggle(loc.t.showExternal, isOn: $state.includeExternal)
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding(.vertical, 6)
    }
}
