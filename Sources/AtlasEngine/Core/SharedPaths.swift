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

    /// Where Atlas keeps its own state.
    ///
    /// Three platforms, three conventions, and the reason for following each
    /// one is that the engine and the client have to land in the *same*
    /// directory. The client asks .NET for `LocalApplicationData`, which is
    /// `%LOCALAPPDATA%` on Windows and `$XDG_DATA_HOME` — or `~/.local/share`
    /// — everywhere else. The engine answered `Library/Application Support`
    /// on Linux as well, so a Linux install kept its scan history in a
    /// macOS-shaped folder the client never looked in, and the README that
    /// ships in the package promised `~/.local/share/Atlas`, which was not
    /// where any of it went.
    ///
    /// macOS is the exception on purpose: there the client is the SwiftUI app
    /// and `Application Support` is the convention.
    static var supportDirectory: URL {
        #if os(Windows)
        return realHome.appendingPathComponent("Atlas", isDirectory: true)
        #elseif os(macOS)
        return realHome
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Atlas", isDirectory: true)
        #else
        // Only an absolute XDG_DATA_HOME counts, which is what the
        // specification says and what .NET checks before using it.
        if let data = ProcessInfo.processInfo.environment["XDG_DATA_HOME"],
           data.hasPrefix("/") {
            return URL(fileURLWithPath: data, isDirectory: true)
                .appendingPathComponent("Atlas", isDirectory: true)
        }
        return realHome
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("share", isDirectory: true)
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
