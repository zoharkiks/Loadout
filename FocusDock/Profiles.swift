import Foundation

/// A named setup of Dock items and wallpaper that can be tied to a Focus.
struct Profile: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var changesDock = true
    /// Absolute paths to `.app` bundles, in Dock order.
    var dockApps: [String] = []
    /// Absolute paths to folders shown as stacks on the right side of the Dock.
    var dockFolders: [String] = []
    var changesWallpaper = false
    var wallpaperPath: String?
    // Optional so profiles saved before these existed still decode.
    var symbol: String?
    var tint: ProfileTint?

    var displaySymbol: String { symbol ?? "square.stack.3d.up.fill" }
    var displayTint: ProfileTint { tint ?? .blue }

    var appCountText: String { Self.count(dockApps.count, "app") }
    var folderCountText: String { Self.count(dockFolders.count, "folder") }

    private static func count(_ n: Int, _ noun: String) -> String {
        "\(n) \(noun)\(n == 1 ? "" : "s")"
    }
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
            .appendingPathComponent("FocusDock", isDirectory: true)
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
            NSLog("FocusDock: failed to save profiles: \(error)")
        }
    }
}
