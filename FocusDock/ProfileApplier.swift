import AppKit

enum ActivationSource: String {
    case focus, manual, shortcut
}

@MainActor
final class ProfileApplier: ObservableObject {
    static let shared = ProfileApplier()

    @Published private(set) var activeProfileID: UUID?
    @Published private(set) var activationSource: ActivationSource?
    @Published private(set) var lastError: String?

    private var pendingTask: Task<Void, Never>?
    private var pendingProfileID: UUID?

    private enum Keys {
        static let profile = "activeProfileID"
        static let source = "activationSource"
    }

    /// Restores what was active when the app last quit, so the panel isn't blank after a relaunch.
    init() {
        let defaults = UserDefaults.standard
        activeProfileID = defaults.string(forKey: Keys.profile).flatMap(UUID.init(uuidString:))
        activationSource = defaults.string(forKey: Keys.source).flatMap(ActivationSource.init(rawValue:))
    }

    /// Called by the Focus filter. `nil` means the Focus that used FocusDock turned off.
    func focusChanged(to profileID: UUID?) {
        // Switching Focus A → B can deliver "A off" and "B on" in either order,
        // so an "off" never overrides an "on" that is still waiting to be applied.
        if profileID == nil, pendingTask != nil, pendingProfileID != nil { return }

        pendingTask?.cancel()
        pendingProfileID = profileID
        pendingTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            pendingTask = nil
            let store = ProfileStore.shared
            if let profile = store.profile(id: profileID) ?? store.defaultProfile {
                apply(profile, source: .focus)
            }
        }
    }

    func apply(_ profile: Profile, source: ActivationSource = .manual) {
        lastError = nil
        // An empty list almost always means "not set up yet", so leave the Dock alone rather than wipe it.
        if profile.changesDock, !(profile.dockApps.isEmpty && profile.dockFolders.isEmpty) {
            DockManager.setDock(apps: profile.dockApps, folders: profile.dockFolders)
        }
        if profile.changesWallpaper, let path = profile.wallpaperPath {
            do {
                try setWallpaper(URL(fileURLWithPath: path))
            } catch {
                lastError = "Couldn't set wallpaper: \(error.localizedDescription)"
            }
        }
        activeProfileID = profile.id
        activationSource = source
        persist()
    }

    #if DEBUG
    /// Sets the active state without touching the Dock or wallpaper, for previews.
    func previewActivate(_ id: UUID, source: ActivationSource) {
        activeProfileID = id
        activationSource = source
    }
    #endif

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(activeProfileID?.uuidString, forKey: Keys.profile)
        defaults.set(activationSource?.rawValue, forKey: Keys.source)
    }

    /// Sets the image on every display, keeping each display's current scaling options.
    private func setWallpaper(_ url: URL) throws {
        let workspace = NSWorkspace.shared
        for screen in NSScreen.screens {
            try workspace.setDesktopImageURL(url, for: screen,
                                             options: workspace.desktopImageOptions(for: screen) ?? [:])
        }
    }
}
