import SwiftUI
import AppKit

@main
struct XaritaApp: App {

    @StateObject private var state = AppState()
    @StateObject private var loc = Localization()
    @StateObject private var explainer = Explainer()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .environmentObject(loc)
                .environmentObject(explainer)
                .frame(minWidth: 1040, minHeight: 640)
                .background(Theme.background)
                .onAppear {
                    Notifier.requestAuthorization()
                    explainer.refreshAvailability()
                }
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1280, height: 820)
        .commands { menuCommands }

        Settings {
            SettingsView()
                .environmentObject(state)
                .environmentObject(loc)
                .environmentObject(explainer)
        }
    }

    @CommandsBuilder
    private var menuCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(loc.t.openProject) { state.chooseProject() }
                .keyboardShortcut("o", modifiers: .command)
        }
        CommandGroup(after: .newItem) {
            Button(loc.t.reanalyze) { state.reanalyze() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(state.graph == nil)
            Divider()
            Button(loc.t.close) { state.closeProject() }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(state.graph == nil)
        }
        CommandMenu(loc.t.overview) {
            Button(loc.t.explainThis) {
                state.requestExplanation(explainer: explainer, language: loc.language)
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(state.selection == nil || !explainer.modelState.canGenerate)

            Button(loc.t.understood) {
                if let id = state.selection { state.toggleUnderstood(id) }
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(state.selection == nil)

            Divider()
            Button(loc.t.goBack) { state.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!state.canGoBack)
            Button(loc.t.goForward) { state.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!state.canGoForward)
            Divider()
            Picker(loc.t.interfaceLanguage, selection: $loc.language) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
        }
    }
}

/// Standard desktop-app behaviours SwiftUI doesn't provide on its own.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
