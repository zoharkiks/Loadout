import AppIntents

struct ProfileEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Loadout Profile"
    static var defaultQuery = ProfileQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(_ profile: Profile) {
        id = profile.id
        name = profile.name
    }
}

struct ProfileQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ProfileEntity] {
        ProfileStore.loadFromDisk().profiles
            .filter { identifiers.contains($0.id) }
            .map(ProfileEntity.init)
    }

    func suggestedEntities() async throws -> [ProfileEntity] {
        ProfileStore.loadFromDisk().profiles.map(ProfileEntity.init)
    }
}

/// Shows up under System Settings › Focus › (a Focus) › Focus Filters.
/// macOS runs it with the chosen profile when the Focus turns on,
/// and again with no profile when it turns off.
struct LoadoutFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Set Dock & Wallpaper"
    static var description: IntentDescription? = IntentDescription(
        "Switches your Dock apps, Dock folders and wallpaper to a Loadout profile while this Focus is on.")

    @Parameter(title: "Profile")
    var profile: ProfileEntity?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(profile?.name ?? "No profile")", subtitle: "Dock & wallpaper")
    }

    func perform() async throws -> some IntentResult {
        let id = profile?.id
        await MainActor.run { ProfileApplier.shared.focusChanged(to: id) }
        return .result()
    }
}

/// Lets Shortcuts (including "When Focus turns on" automations) apply a profile directly.
struct ApplyProfileIntent: AppIntent {
    static var title: LocalizedStringResource = "Apply Loadout Profile"

    @Parameter(title: "Profile")
    var profile: ProfileEntity

    func perform() async throws -> some IntentResult {
        let id = profile.id
        await MainActor.run {
            if let profile = ProfileStore.shared.profile(id: id) {
                ProfileApplier.shared.apply(profile, source: .shortcut)
            }
        }
        return .result()
    }
}
