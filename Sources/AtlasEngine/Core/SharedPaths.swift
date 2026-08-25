import Foundation

/// Locations shared between the app and its widget extension.
///
/// The widget runs in a separate process that may be sandboxed, where
/// `NSHomeDirectory()` resolves to a container rather than the real home
/// directory. Resolving through the password database gives both processes the
/// same answer without needing an App Group entitlement — which an ad-hoc
/// signed build cannot obtain anyway.
enum SharedPaths {

    static var realHome: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            let path = String(cString: dir)
            if !path.isEmpty { return URL(fileURLWithPath: path, isDirectory: true) }
        }
        if let home = ProcessInfo.processInfo.environment["HOME"], !home.isEmpty {
            return URL(fileURLWithPath: home, isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    static var supportDirectory: URL {
        realHome
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Atlas", isDirectory: true)
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
