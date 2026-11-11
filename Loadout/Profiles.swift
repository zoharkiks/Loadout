import Foundation

/// A named setup of Dock items and wallpaper that can be tied to a Focus.
struct Profile: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var changesDock = true
    /// Absolute paths to `.app` bundles in Dock order, mixed with `DockSpacer` entries.
    var dockApps: [String] = []
    /// Absolute paths to folders shown as stacks on the right side of the Dock.
    var dockFolders: [String] = []
    /// Per-folder stack settings, keyed by folder path. A folder with no entry keeps whatever the Dock has.
    /// Optional so profiles saved before this existed still decode.
    var folderStyles: [String: DockFolderStyle]?
    var changesWallpaper = false
    var wallpaperPath: String?
    // Optional so profiles saved before these existed still decode.
    var symbol: String?
    var tint: ProfileTint?

    var displaySymbol: String { symbol ?? "square.stack.3d.up.fill" }
    var displayTint: ProfileTint { tint ?? .blue }

    /// `dockApps` without the spacers.
    var dockAppPaths: [String] { dockApps.filter { DockSpacer(entry: $0) == nil } }

    var appCountText: String { Self.count(dockAppPaths.count, "app") }
    var folderCountText: String { Self.count(dockFolders.count, "folder") }

    private static func count(_ n: Int, _ noun: String) -> String {
        "\(n) \(noun)\(n == 1 ? "" : "s")"
    }
}

/// A gap between Dock apps. Stored in `Profile.dockApps` as `spacer:<size>:<uuid>`, so old
/// profiles still decode and each spacer has its own id for the editor's list.
enum DockSpacer: String, CaseIterable {
    case normal, small

    private static let prefix = "spacer:"

    init?(entry: String) {
        guard entry.hasPrefix(Self.prefix) else { return nil }
        let size = entry.dropFirst(Self.prefix.count).prefix { $0 != ":" }
        self.init(rawValue: String(size))
    }

    /// A new, unique entry for `Profile.dockApps`.
    func makeEntry() -> String { "\(Self.prefix)\(rawValue):\(UUID().uuidString)" }

    /// The `tile-type` the Dock uses for this spacer.
    var tileType: String { self == .small ? "small-spacer-tile" : "spacer-tile" }

    init?(tileType: String) {
        guard let match = Self.allCases.first(where: { $0.tileType == tileType }) else { return nil }
        self = match
    }

    var title: String { self == .small ? "Small Spacer" : "Spacer" }
}

/// How a folder stack looks in the Dock: the same three choices as the Dock's right-click menu.
/// Raw values are the ones the Dock stores in `com.apple.dock`.
struct DockFolderStyle: Codable, Hashable {
    enum Arrangement: Int, Codable, CaseIterable {
        case name = 1, dateAdded, dateModified, dateCreated, kind

        var title: String {
            switch self {
            case .name: "Name"
            case .dateAdded: "Date Added"
            case .dateModified: "Date Modified"
            case .dateCreated: "Date Created"
            case .kind: "Kind"
            }
        }
    }

    enum DisplayAs: Int, Codable, CaseIterable {
        case stack = 0, folder

        var title: String { self == .stack ? "Stack" : "Folder" }
    }

    enum ShowAs: Int, Codable, CaseIterable {
        case automatic = 0, fan, grid, list

        var title: String {
            switch self {
            case .automatic: "Automatic"
            case .fan: "Fan"
            case .grid: "Grid"
            case .list: "List"
            }
        }
    }

    var arrangement = Arrangement.name
    var displayAs = DisplayAs.stack
    var showAs = ShowAs.automatic
}

struct ProfileLibrary: Codable {
    var profiles: [Profile] = []
    /// Profile restored when no Focus is on.
    var defaultProfileID: UUID?
}

@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published var library: ProfileLibrary {
        didSet { save() }
    }

    private let persists: Bool

    private init() {
        library = Self.loadFromDisk()
        persists = true
    }

    #if DEBUG
    /// In-memory store for SwiftUI previews.
    init(preview library: ProfileLibrary) {
        self.library = library
        persists = false
    }
    #endif

    func profile(id: UUID?) -> Profile? {
        library.profiles.first { $0.id == id }
    }

    var defaultProfile: Profile? {
        profile(id: library.defaultProfileID)
    }

    // MARK: Persistence

    nonisolated static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Loadout", isDirectory: true)
            .appendingPathComponent("profiles.json")
    }

    /// Read straight from disk so App Intents can list profiles without touching the main actor.
    nonisolated static func loadFromDisk() -> ProfileLibrary {
        guard let data = try? Data(contentsOf: fileURL),
              let library = try? JSONDecoder().decode(ProfileLibrary.self, from: data)
        else { return ProfileLibrary() }
        return library
    }

    private func save() {
        guard persists else { return }
        do {
            try FileManager.default.createDirectory(at: Self.fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(library).write(to: Self.fileURL, options: .atomic)
        } catch {
            NSLog("Loadout: failed to save profiles: \(error)")
        }
    }
}
