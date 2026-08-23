import SwiftUI
import AppKit

@main
struct XaritaApp: App {

    @StateObject private var state = AppState()
    @StateObject private var loc = Localization()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .environmentObject(loc)
                .frame(minWidth: 960, minHeight: 620)
                .background(Theme.background)
                .onAppear { Notifier.requestAuthorization() }
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1280, height: 820)
        .commands { menuCommands }

        Settings {
            SettingsView()
                .environmentObject(state)
                .environmentObject(loc)
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
            Button(loc.t.fitToScreen) { state.fitRequest &+= 1 }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(state.graph == nil)
            Button(loc.t.resetLayout) { state.rerunLayout() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(state.graph == nil)
            Toggle(loc.t.showLabels, isOn: $state.showLabels)
                .keyboardShortcut("t", modifiers: .command)
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
