import Foundation

/// Reads and rewrites the Dock's contents through the `com.apple.dock` preferences domain.
enum DockManager {
    private static let domain = "com.apple.dock" as CFString
    private static let appsKey = "persistent-apps" as CFString
    private static let othersKey = "persistent-others" as CFString

    static func currentApps() -> [String] {
        tiles(appsKey).compactMap(filePath(of:))
    }

    /// The apps side of the Dock in order, with each spacer as a new `DockSpacer` entry.
    static func currentAppsAndSpacers() -> [String] {
        tiles(appsKey).compactMap { spacer(of: $0)?.makeEntry() ?? filePath(of: $0) }
    }

    static func currentFolders() -> [String] {
        tiles(othersKey).filter(isFolder).compactMap(filePath(of:))
    }

    /// The stack settings of each folder in the Dock right now, keyed by path.
    static func currentFolderStyles() -> [String: DockFolderStyle] {
        var styles: [String: DockFolderStyle] = [:]
        for tile in tiles(othersKey) where isFolder(tile) {
            if let path = filePath(of: tile) { styles[path] = style(of: tile) }
        }
        return styles
    }

    /// Replaces the Dock's apps and folder stacks, then restarts the Dock.
    /// `apps` may contain `DockSpacer` entries. Folders listed in `folderStyles` get those stack settings;
    /// others keep the Dock's. Returns false (and leaves the Dock alone) when nothing would change.
    @discardableResult
    static func setDock(apps: [String], folders: [String], folderStyles: [String: DockFolderStyle] = [:]) -> Bool {
        let oldApps = tiles(appsKey)
        let oldOthers = tiles(othersKey)
        // Spacers have no path, so compare by tile type for them.
        let wanted = apps.map { DockSpacer(entry: $0)?.tileType ?? $0 }
        let current = oldApps.compactMap { spacer(of: $0)?.tileType ?? filePath(of: $0) }
        let oldFolders = oldOthers.filter(isFolder)
        let stylesMatch = folderStyles.allSatisfy { path, style in
            guard let tile = oldFolders.first(where: { filePath(of: $0) == path }) else { return true }
            return self.style(of: tile) == style
        }
        guard wanted != current
                || folders != oldFolders.compactMap(filePath(of:))
                || !stylesMatch
        else { return false }

        // Reuse existing tiles where possible so the Dock keeps its per-item settings.
        func tile(for path: String, in old: [[String: Any]], make: (String) -> [String: Any]) -> [String: Any] {
            old.first { filePath(of: $0) == path } ?? make(path)
        }
        let newApps = apps.map { entry in
            DockSpacer(entry: entry).map(spacerTile) ?? tile(for: entry, in: oldApps, make: appTile)
        }
        let newOthers = folders.map { path in
            let folder = tile(for: path, in: oldOthers) { folderTile($0) }
            return folderStyles[path].map { applying($0, to: folder) } ?? folder
        }
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

    private static func spacer(of tile: [String: Any]) -> DockSpacer? {
        (tile["tile-type"] as? String).flatMap(DockSpacer.init(tileType:))
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

    private static func folderTile(_ path: String, style: DockFolderStyle = DockFolderStyle()) -> [String: Any] {
        let data: [String: Any] = [
            "file-data": fileData(path),
            "file-label": label(path),
            "file-type": 2,
        ]
        return applying(style, to: ["tile-data": data, "tile-type": "directory-tile"])
    }

    private static func style(of tile: [String: Any]) -> DockFolderStyle {
        let data = tile["tile-data"] as? [String: Any] ?? [:]
        var style = DockFolderStyle()
        if let value = (data["arrangement"] as? Int).flatMap(DockFolderStyle.Arrangement.init) { style.arrangement = value }
        if let value = (data["displayas"] as? Int).flatMap(DockFolderStyle.DisplayAs.init) { style.displayAs = value }
        if let value = (data["showas"] as? Int).flatMap(DockFolderStyle.ShowAs.init) { style.showAs = value }
        return style
    }

    private static func applying(_ style: DockFolderStyle, to tile: [String: Any]) -> [String: Any] {
        var tile = tile
        var data = tile["tile-data"] as? [String: Any] ?? [:]
        data["arrangement"] = style.arrangement.rawValue
        data["displayas"] = style.displayAs.rawValue
        data["showas"] = style.showAs.rawValue
        tile["tile-data"] = data
        return tile
    }

    private static func spacerTile(_ spacer: DockSpacer) -> [String: Any] {
        ["tile-data": [String: Any](), "tile-type": spacer.tileType]
    }

    private static func restartDock() {
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/killall"), arguments: ["Dock"])
    }
}
