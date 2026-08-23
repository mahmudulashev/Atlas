import Foundation
import UserNotifications
import WidgetKit

/// Local notifications.
///
/// `UNUserNotificationCenter` requires a real, code-signed bundle identity —
/// asking for it from a loose executable throws. Every entry point therefore
/// guards on having a bundle identifier, so running the binary directly during
/// development degrades quietly instead of trapping.
enum Notifier {

    private static var hasBundle: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "uz.xarita.notify") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "uz.xarita.notify") }
    }

    static func requestAuthorization() {
        guard hasBundle else { return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func analysisFinished(project: String, symbols: Int, seconds: Double) {
        guard hasBundle, isEnabled else { return }

        let language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "uz.xarita.language") ?? "")
            ?? .systemDefault
        let t = L10n(language: language)

        let content = UNMutableNotificationContent()
        content.title = t.notifDoneTitle
        content.body = t.notifDoneBody(project: project, symbols: symbols, seconds: seconds)
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

/// Nudges WidgetKit after a fresh snapshot lands.
enum WidgetRefresher {
    static func reload() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
