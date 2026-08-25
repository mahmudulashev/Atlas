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

    /// Kept alive for the process lifetime: `UNUserNotificationCenter.delegate`
    /// is a weak reference, and a delegate that deallocates simply stops being
    /// consulted — silently.
    private static let presenter = ForegroundPresenter()

    /// Whether the user has actually granted permission, for the settings pane.
    @MainActor
    static func authorizationStatus() async -> UNAuthorizationStatus {
        guard hasBundle else { return .denied }
        return await UNUserNotificationCenter.current().notificationSettings()
            .authorizationStatus
    }

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "uz.xarita.notify") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "uz.xarita.notify") }
    }

    static func requestAuthorization() {
        guard hasBundle else { return }
        let center = UNUserNotificationCenter.current()

        // Without a delegate, macOS delivers notifications posted while the app
        // is frontmost straight to Notification Centre and shows no banner —
        // which is exactly when this app posts, since an analysis finishes
        // while the user is looking at the window. The delegate is what asks
        // for the banner anyway.
        center.delegate = presenter

        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
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

/// Asks for the banner even when Xarita is the active application.
private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

/// Nudges WidgetKit after a fresh snapshot lands.
enum WidgetRefresher {
    static func reload() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
