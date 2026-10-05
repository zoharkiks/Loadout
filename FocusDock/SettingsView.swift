import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// Profile editor window, styled like the menu bar panel: tinted glass with white text.
struct SettingsView: View {
    @EnvironmentObject private var store: ProfileStore
    @EnvironmentObject private var applier: ProfileApplier
    @ObservedObject private var theme = ThemeModel.shared
    @State private var selection: UUID?
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled

    init(selection: UUID? = nil) {
        _selection = State(initialValue: selection)
    }

    private var selectedProfile: Profile? { store.profile(id: selection) }

    private var tint: Color { selectedProfile?.themeColor ?? theme.tint }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
            detail
        }
        .background(EditorBackground(tint: tint))
        .animation(.smooth(duration: 0.5), value: tint)
        .environment(\.colorScheme, .dark)
        .onAppear {
            if selection == nil { selection = applier.activeProfileID ?? store.library.profiles.first?.id }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newProfileRequested)) { _ in addProfile() }
        .onReceive(NotificationCenter.default.publisher(for: .editProfileRequested)) { note in
            selection = note.object as? UUID
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Profiles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(store.library.profiles) { profile in
                        SidebarRow(profile: profile,
                                   isSelected: profile.id == selection,
                                   isActive: profile.id == applier.activeProfileID) {
                            selection = profile.id
                        }
                        .contextMenu {
                            Button("Apply Now") { applier.apply(profile) }
                            Divider()
                            Button("Delete", role: .destructive) { delete(profile.id) }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }

            VStack(alignment: .leading, spacing: 12) {
                Button(action: addProfile) {
                    Label("New Profile", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassCapsuleStyle(prominent: true))

                Toggle("Open at login", isOn: $opensAtLogin)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .onChange(of: opensAtLogin) { _, on in
                        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
            }
            .padding(14)
        }
        .padding(.top, 52) // clear the traffic lights
        .frame(width: 230)
        .background(.black.opacity(0.2))
    }

    // MARK: Detail

    @ViewBuilder private var detail: some View {
        if let id = selection, selectedProfile != nil {
            ProfileEditor(profile: binding(for: id), delete: { delete(id) })
                .id(id)
        } else {
            SetupGuide(addProfile: addProfile)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func binding(for id: UUID) -> Binding<Profile> {
        Binding(
            get: { store.profile(id: id) ?? Profile(name: "") },
            set: { updated in
                if let index = store.library.profiles.firstIndex(where: { $0.id == id }) {
                    store.library.profiles[index] = updated
                }
            })
    }

    private func addProfile() {
        // Cycle through colours so new profiles are easy to tell apart.
        let tints = ProfileTint.allCases
        var profile = Profile(name: "New Profile")
        profile.tint = tints[store.library.profiles.count % tints.count]
        store.library.profiles.append(profile)
        selection = profile.id
    }

    private func delete(_ id: UUID) {
        selection = nil
        store.library.profiles.removeAll { $0.id == id }
        if store.library.defaultProfileID == id { store.library.defaultProfileID = nil }
        selection = store.library.profiles.first?.id
    }
}

private struct SidebarRow: View {
    let profile: Profile
    let isSelected: Bool
    let isActive: Bool
    let select: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                IconSquare(symbol: profile.displaySymbol, tint: profile.displayTint.color, size: 26)
                Text(profile.name.isEmpty ? "Untitled" : profile.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                if isActive {
                    Circle().fill(.green).frame(width: 7, height: 7).help("Active")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.16 : hovering ? 0.07 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Editor

struct ProfileEditor: View {
    @Binding var profile: Profile
    let delete: () -> Void
    @EnvironmentObject private var store: ProfileStore
    @EnvironmentObject private var applier: ProfileApplier

    @State private var showingDockPicker = false
    @State private var wallpaperDropTargeted = false

    private var isActive: Bool { applier.activeProfileID == profile.id }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                focusCard
                appearanceCard
                dockCard
                wallpaperCard

                HStack {
                    Text("Applying restarts the Dock for a moment if its contents change.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Button("Delete Profile", role: .destructive, action: delete)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red.mix(with: .white, by: 0.25))
                }
            }
            .frame(maxWidth: 600)
            .padding(.horizontal, 36)
            .padding(.top, 48)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.automatic)
        .sheet(isPresented: $showingDockPicker) {
            CurrentDockPicker(profile: profile) { apps, folders in
                add(to: \.dockApps, apps)
                add(to: \.dockFolders, folders)
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        HStack(spacing: 16) {
            IconSquare(symbol: profile.displaySymbol, tint: profile.displayTint.color, size: 64)
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 4) {
                TextField("Profile name", text: $profile.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Group {
                    if let error = applier.lastError {
                        Text(error).foregroundStyle(.red.mix(with: .white, by: 0.3))
                    } else {
                        Text(isActive ? "Active · \(summary)" : summary)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 12)
            Button(isActive ? "Reapply" : "Apply Now") { applier.apply(profile) }
                .buttonStyle(GlassCapsuleStyle(prominent: true))
        }
    }

    private var summary: String {
        var parts: [String] = []
        if profile.changesDock {
            parts.append(profile.dockFolders.isEmpty
                         ? profile.appCountText
                         : "\(profile.appCountText), \(profile.folderCountText)")
        }
        if profile.changesWallpaper && profile.wallpaperPath != nil { parts.append("custom wallpaper") }
        return parts.isEmpty ? "Doesn't change anything yet" : parts.joined(separator: " · ")
    }

    // MARK: Cards

    private var focusCard: some View {
        GlassCard {
            CardHeader(symbol: "moon.fill", tint: ProfileTint.purple.color,
                       title: "Use when no Focus is on",
                       subtitle: "Restored whenever a Focus that uses FocusDock ends.",
                       isOn: Binding(
                           get: { store.library.defaultProfileID == profile.id },
                           set: { store.library.defaultProfileID = $0 ? profile.id : nil }))
        }
    }

    private var appearanceCard: some View {
        GlassCard {
            CardHeader(symbol: "paintpalette.fill", tint: ProfileTint.orange.color, title: "Appearance")
            CardDivider()
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ForEach(ProfileTint.allCases) { tint in
                        Circle()
                            .fill(tint.color)
                            .frame(width: 22, height: 22)
                            .overlay {
                                if tint == profile.displayTint {
                                    Circle().strokeBorder(.white, lineWidth: 2).frame(width: 30, height: 30)
                                }
                            }
                            .frame(width: 30, height: 30)
                            .contentShape(Circle())
                            .onTapGesture { withAnimation(.snappy) { profile.tint = tint } }
                            .help(tint.rawValue.capitalized)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 8), count: 8), alignment: .leading, spacing: 8) {
                    ForEach(ProfileSymbols.all, id: \.self) { symbol in
                        let selected = symbol == profile.displaySymbol
                        IconSquare(symbol: symbol,
                                   tint: selected ? profile.displayTint.color : .white.opacity(0.12),
                                   size: 34)
                            .overlay {
                                if selected {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                                        .padding(-3)
                                }
                            }
                            .onTapGesture { withAnimation(.snappy) { profile.symbol = symbol } }
                    }
                }
            }
            .padding(14)
        }
    }

    private var dockCard: some View {
        GlassCard {
            CardHeader(symbol: "dock.rectangle", tint: ProfileTint.yellow.color,
                       title: "Dock", subtitle: "Apps and folders shown while this profile is active.",
                       isOn: $profile.changesDock)
            if profile.changesDock {
                CardDivider()
                SubsectionHeader(title: "Apps") {
                    Button("Add from Current Dock…") { showingDockPicker = true }
                        .buttonStyle(GlassCapsuleStyle())
                    Button("Add Apps…") { add(to: \.dockApps, pick(types: [.application])) }
                        .buttonStyle(GlassCapsuleStyle())
                }
                PathList(paths: $profile.dockApps, emptyText: "No apps yet, so applying leaves your Dock as it is. Add apps, or pick them from your current Dock.")
                CardDivider()
                SubsectionHeader(title: "Folders") {
                    Button("Add Folders…") { add(to: \.dockFolders, pick(types: nil)) }
                        .buttonStyle(GlassCapsuleStyle())
                }
                PathList(paths: $profile.dockFolders, emptyText: "No folders. They appear as stacks next to the Trash.")
            }
        }
    }

    private var wallpaperCard: some View {
        GlassCard {
            CardHeader(symbol: "photo.fill", tint: ProfileTint.pink.color,
                       title: "Wallpaper", subtitle: "Set on every display when this profile turns on.",
                       isOn: $profile.changesWallpaper)
            if profile.changesWallpaper {
                CardDivider()
                HStack(alignment: .center, spacing: 18) {
                    WallpaperThumbnail(path: profile.wallpaperPath,
                                       size: CGSize(width: 208, height: 130), pixelSize: 520, cornerRadius: 12)
                        .overlay {
                            if profile.wallpaperPath == nil {
                                VStack(spacing: 6) {
                                    Image(systemName: "photo.badge.plus").font(.system(size: 22))
                                    Text("Drop an image here").font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(profile.wallpaperPath.map { ($0 as NSString).lastPathComponent } ?? "No image chosen")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(profile.wallpaperPath == nil ? 0.5 : 0.9))
                            .lineLimit(2)
                            .truncationMode(.middle)
                        Button("Choose Image…") {
                            if let path = pick(types: [.image], multiple: false).first {
                                profile.wallpaperPath = path
                            }
                        }
                        .buttonStyle(GlassCapsuleStyle())
                        Button("Use Current Wallpaper") {
                            if let screen = NSScreen.main,
                               let url = NSWorkspace.shared.desktopImageURL(for: screen) {
                                profile.wallpaperPath = url.path
                            }
                        }
                        .buttonStyle(GlassCapsuleStyle())
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
            }
        }
        .overlay {
            if wallpaperDropTargeted {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .strokeBorder(.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                    .overlay {
                        Label("Drop to use as wallpaper", systemImage: "photo.badge.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.black.opacity(0.35)))
                    }
                    .allowsHitTesting(false)
            }
        }
        // The whole card accepts a dropped image, and dropping one turns the wallpaper on.
        .dropDestination(for: URL.self) { urls, _ in
            guard let image = urls.first(where: isImage) else { return false }
            withAnimation(.snappy) {
                profile.wallpaperPath = image.path
                profile.changesWallpaper = true
            }
            return true
        } isTargeted: { targeted in
            withAnimation(.snappy(duration: 0.2)) { wallpaperDropTargeted = targeted }
        }
    }

    private func isImage(_ url: URL) -> Bool {
        url.isFileURL && ((try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.conforms(to: .image) ?? false)
    }

    // MARK: Helpers

    private func add(to keyPath: WritableKeyPath<Profile, [String]>, _ paths: [String]) {
        for path in paths where !profile[keyPath: keyPath].contains(path) {
            profile[keyPath: keyPath].append(path)
        }
    }

    /// `types == nil` picks folders.
    private func pick(types: [UTType]?, multiple: Bool = true) -> [String] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = multiple
        if let types {
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = types
            if types == [.application] {
                panel.directoryURL = URL(fileURLWithPath: "/Applications")
            }
        } else {
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
        }
        return panel.runModal() == .OK ? panel.urls.map(\.path) : []
    }
}

// MARK: - Building blocks

private struct EditorBackground: View {
    let tint: Color

    var body: some View {
        ZStack {
            Color.black
            LinearGradient(colors: [tint, tint.mix(with: .black, by: 0.55)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [.white.opacity(0.09), .clear],
                           center: UnitPoint(x: 0.1, y: 0), startRadius: 0, endRadius: 600)
        }
        .ignoresSafeArea()
    }
}

private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }
}

private struct CardHeader: View {
    let symbol: String
    let tint: Color
    let title: String
    var subtitle: String?
    var isOn: Binding<Bool>?

    var body: some View {
        HStack(spacing: 12) {
            IconSquare(symbol: symbol, tint: tint, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                }
            }
            Spacer()
            if let isOn {
                Toggle(title, isOn: isOn.animation(.snappy)).labelsHidden().toggleStyle(.switch)
            }
        }
        .padding(14)
    }
}

private struct SubsectionHeader<Actions: View>: View {
    let title: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
            Spacer()
            actions
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}

private struct CardDivider: View {
    var body: some View {
        Rectangle().fill(.white.opacity(0.08)).frame(height: 1).padding(.leading, 14)
    }
}

/// Dock items with their Finder icons. Drag rows to reorder.
struct PathList: View {
    @Binding var paths: [String]
    let emptyText: String
    @State private var dragging: String?

    var body: some View {
        if paths.isEmpty {
            Text(emptyText)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .padding(.top, 2)
        } else {
            VStack(spacing: 2) {
                ForEach(paths, id: \.self) { path in
                    PathRow(path: path) { withAnimation(.snappy) { paths.removeAll { $0 == path } } }
                        .opacity(dragging == path ? 0.4 : 1)
                        .onDrag {
                            dragging = path
                            return NSItemProvider(object: path as NSString)
                        }
                        .onDrop(of: [.text], delegate: ReorderDropDelegate(target: path, paths: $paths, dragging: $dragging))
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
    }
}

private struct PathRow: View {
    let path: String
    let remove: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(hovering ? 0.5 : 0.2))
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: 24, height: 24)
            Text(FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: ""))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
            if !FileManager.default.fileExists(atPath: path) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help("Not found at \(path)")
            }
            Spacer()
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .help("Remove")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.white.opacity(hovering ? 0.07 : 0))
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

private struct ReorderDropDelegate: DropDelegate {
    let target: String
    @Binding var paths: [String]
    @Binding var dragging: String?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target,
              let from = paths.firstIndex(of: dragging),
              let to = paths.firstIndex(of: target)
        else { return }
        withAnimation(.snappy) {
            paths.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

// MARK: - Current Dock picker

/// Lists what's in the Dock right now — saved apps, open apps and folders — so the user can
/// tick exactly which ones this profile should keep.
struct CurrentDockPicker: View {
    let profile: Profile
    let add: (_ apps: [String], _ folders: [String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []

    private let savedApps: [String]
    private let openApps: [String]
    private let folders: [String]

    init(profile: Profile, add: @escaping (_ apps: [String], _ folders: [String]) -> Void) {
        self.profile = profile
        self.add = add
        let saved = DockManager.currentApps()
        savedApps = saved
        folders = DockManager.currentFolders()
        // Running apps appear in the Dock too, even though they aren't saved in it.
        var seen = Set(saved)
        openApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular
                && $0.bundleIdentifier != "com.apple.finder"
                && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { $0.bundleURL.map { ($0.path as NSString).standardizingPath } }
            .filter { seen.insert($0).inserted }
    }

    private var alreadyInProfile: Set<String> { Set(profile.dockApps + profile.dockFolders) }
    private var choosable: [String] { (savedApps + openApps + folders).filter { !alreadyInProfile.contains($0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add from Current Dock")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Tick the apps you want in \(profile.name.isEmpty ? "this profile" : "“\(profile.name)”"). When it's applied, the Dock keeps only the apps in its list.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("Saved in your Dock", savedApps)
                    section("Open right now", openApps)
                    section("Folders", folders)
                    if savedApps.isEmpty && openApps.isEmpty && folders.isEmpty {
                        Text("Your Dock is empty.").foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }

            HStack(spacing: 8) {
                Button(selected.count == choosable.count && !choosable.isEmpty ? "Select None" : "Select All") {
                    selected = selected.count == choosable.count ? [] : Set(choosable)
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .disabled(choosable.isEmpty)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(GlassCapsuleStyle())
                    .keyboardShortcut(.cancelAction)
                Button(selected.isEmpty ? "Add" : "Add \(selected.count)") {
                    // Keep the Dock's own order rather than the order things were ticked.
                    add((savedApps + openApps).filter(selected.contains), folders.filter(selected.contains))
                    dismiss()
                }
                .buttonStyle(GlassCapsuleStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
                .disabled(selected.isEmpty)
                .opacity(selected.isEmpty ? 0.5 : 1)
            }
            .padding(16)
            .background(.black.opacity(0.15))
        }
        .frame(width: 440, height: 540)
        .foregroundStyle(.white)
        .background(EditorBackground(tint: profile.themeColor))
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func section(_ title: String, _ paths: [String]) -> some View {
        if !paths.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                ForEach(paths, id: \.self) { path in
                    let added = alreadyInProfile.contains(path)
                    let checked = added || selected.contains(path)
                    Button {
                        if selected.contains(path) { selected.remove(path) } else { selected.insert(path) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 17))
                                .foregroundStyle(checked ? .white : .white.opacity(0.35))
                            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                .resizable()
                                .frame(width: 26, height: 26)
                            Text(FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: ""))
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            if added {
                                Text("In profile").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(.white.opacity(selected.contains(path) ? 0.1 : 0)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(added)
                    .opacity(added ? 0.55 : 1)
                }
            }
        }
    }
}

// MARK: - Empty state

extension Notification.Name {
    static let newProfileRequested = Notification.Name("FocusDock.newProfileRequested")
}

struct SetupGuide: View {
    let addProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            IconSquare(symbol: "dock.rectangle", tint: ProfileTint.blue.color, size: 56)
            Text("Set up FocusDock")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 12) {
                step(1, "Create a profile and pick its Dock apps, folders and wallpaper.")
                step(2, "Turn on “Use when no Focus is on” for the profile you want back when a Focus ends.")
                step(3, "In System Settings › Focus, open a Focus, choose Add Filter › FocusDock and pick a profile.")
                step(4, "Repeat for each Focus. FocusDock switches automatically.")
            }
            HStack(spacing: 10) {
                Button(action: addProfile) { Label("New Profile", systemImage: "plus") }
                    .buttonStyle(GlassCapsuleStyle(prominent: true))
                Button("Open Focus Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension")!)
                }
                .buttonStyle(GlassCapsuleStyle())
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: 440, alignment: .leading)
        .padding(40)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.white.opacity(0.14)))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
