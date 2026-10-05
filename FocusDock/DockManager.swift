import Foundation

/// Reads and rewrites the Dock's contents through the `com.apple.dock` preferences domain.
enum DockManager {
    private static let domain = "com.apple.dock" as CFString
    private static let appsKey = "persistent-apps" as CFString
    private static let othersKey = "persistent-others" as CFString

    static func currentApps() -> [String] {
        tiles(appsKey).compactMap(filePath(of:))
    }

    static func currentFolders() -> [String] {
        tiles(othersKey).filter(isFolder).compactMap(filePath(of:))
    }

    /// Replaces the Dock's apps and folder stacks, then restarts the Dock.
    /// Returns false (and leaves the Dock alone) when nothing would change.
    @discardableResult
    static func setDock(apps: [String], folders: [String]) -> Bool {
        let oldApps = tiles(appsKey)
        let oldOthers = tiles(othersKey)
        guard apps != oldApps.compactMap(filePath(of:))
                || folders != oldOthers.filter(isFolder).compactMap(filePath(of:))
        else { return false }

        // Reuse existing tiles where possible so the Dock keeps its per-item settings.
        func tile(for path: String, in old: [[String: Any]], make: (String) -> [String: Any]) -> [String: Any] {
            old.first { filePath(of: $0) == path } ?? make(path)
        }
        let newApps = apps.map { tile(for: $0, in: oldApps, make: appTile) }
        let newOthers = folders.map { tile(for: $0, in: oldOthers, make: folderTile) }
            + oldOthers.filter { !isFolder($0) } // keep URL tiles etc.

        CFPreferencesSetAppValue(appsKey, newApps as CFArray, domain)
        CFPreferencesSetAppValue(othersKey, newOthers as CFArray, domain)
        CFPreferencesAppSynchronize(domain)
        restartDock()
        return true
    }

    // MARK: Tiles

    private static func tiles(_ key: CFString) -> [[String: Any]] {
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue(key, domain) as? [[String: Any]] ?? []
    }

    private static func isFolder(_ tile: [String: Any]) -> Bool {
        tile["tile-type"] as? String == "directory-tile"
    }

    private static func filePath(of tile: [String: Any]) -> String? {
        guard let data = tile["tile-data"] as? [String: Any],
              let file = data["file-data"] as? [String: Any],
              let string = file["_CFURLString"] as? String
        else { return nil }
        // Type 0 is a plain POSIX path, 15 is a file:// URL.
        let path = (file["_CFURLStringType"] as? Int) == 0 ? string : (URL(string: string)?.path ?? string)
        return (path as NSString).standardizingPath
    }

    private static func fileData(_ path: String) -> [String: Any] {
        ["_CFURLString": URL(fileURLWithPath: path, isDirectory: true).absoluteString,
         "_CFURLStringType": 15]
    }

    private static func label(_ path: String) -> String {
        FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: "")
    }

    private static func appTile(_ path: String) -> [String: Any] {
        var data: [String: Any] = [
            "file-data": fileData(path),
            "file-label": label(path),
            "file-type": 41,
        ]
        if let bundleID = Bundle(path: path)?.bundleIdentifier {
            data["bundle-identifier"] = bundleID
        }
        return ["tile-data": data, "tile-type": "file-tile"]
    }

    private static func folderTile(_ path: String) -> [String: Any] {
        let data: [String: Any] = [
            "file-data": fileData(path),
            "file-label": label(path),
            "file-type": 2,
            "arrangement": 1, // sort by name
            "displayas": 0,   // stack
            "showas": 0,      // automatic
        ]
        return ["tile-data": data, "tile-type": "directory-tile"]
    }

    private static func restartDock() {
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/killall"), arguments: ["Dock"])
    }
}
