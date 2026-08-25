import Foundation

/// Locations shared between the app and its widget extension.
///
/// On macOS the widget runs in a separate, possibly sandboxed process where
/// `NSHomeDirectory()` resolves to a container rather than the real home
/// directory. Resolving through the password database gives both processes
/// the same answer without needing an App Group entitlement — which an
/// ad-hoc signed build cannot obtain anyway.
///
/// Windows has no such split: the engine and the UI are ordinary processes
/// that agree on `%LOCALAPPDATA%`.
enum SharedPaths {

    static var realHome: URL {
        #if os(Windows)
        let env = ProcessInfo.processInfo.environment
        if let local = env["LOCALAPPDATA"], !local.isEmpty {
            return URL(fileURLWithPath: local, isDirectory: true)
        }
        if let profile = env["USERPROFILE"], !profile.isEmpty {
            return URL(fileURLWithPath: profile, isDirectory: true)
                .appendingPathComponent("AppData", isDirectory: true)
                .appendingPathComponent("Local", isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        #else
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            let path = String(cString: dir)
            if !path.isEmpty { return URL(fileURLWithPath: path, isDirectory: true) }
        }
        if let home = ProcessInfo.processInfo.environment["HOME"], !home.isEmpty {
            return URL(fileURLWithPath: home, isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        #endif
    }

    /// Where Atlas keeps its own state. `realHome` is already the per-user
    /// application-data root on Windows, so only macOS adds the two
    /// `Library/Application Support` components.
    static var supportDirectory: URL {
        #if os(Windows)
        return realHome.appendingPathComponent("Atlas", isDirectory: true)
        #else
        return realHome
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Atlas", isDirectory: true)
        #endif
    }

    static var snapshotFile: URL {
        supportDirectory.appendingPathComponent("snapshot.json", isDirectory: false)
    }

    @discardableResult
    static func ensureDirectory() -> Bool {
        (try? FileManager.default.createDirectory(at: supportDirectory,
                                                  withIntermediateDirectories: true)) != nil
    }
}
