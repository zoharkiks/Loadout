import ServiceManagement
import SwiftUI

extension Notification.Name {
    static let editProfileRequested = Notification.Name("Loadout.editProfileRequested")
}

/// The menu bar dropdown: tinted glass panel with a Now / Profiles switcher.
struct MenuPanel: View {
    @EnvironmentObject private var store: ProfileStore
    @EnvironmentObject private var applier: ProfileApplier
    @ObservedObject private var theme = ThemeModel.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    @State private var tab: Tab
    @Namespace private var tabNamespace

    init(tab: Tab = .now) {
        _tab = State(initialValue: tab)
    }

    enum Tab: String, CaseIterable {
        case now = "Now", profiles = "Profiles"
    }

    private var active: Profile? { store.profile(id: applier.activeProfileID) }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 14)
                .padding(.horizontal, 14)

            Group {
                switch tab {
                case .now: nowTab
                case .profiles: profilesTab
                }
            }
            .transition(.opacity)
        }
        .frame(width: 340)
        .background(PanelBackground(tint: theme.tint))
        .environment(\.colorScheme, .dark)
        .onAppear { theme.refresh(for: active) }
        .onChange(of: applier.activeProfileID) { theme.refresh(for: active) }
        // Recolour straight away when the active profile's colour is edited.
        .onChange(of: active?.tint) { theme.refresh(for: active) }
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            HStack(spacing: 2) {
                ForEach(Tab.allCases, id: \.self) { item in
                    Text(item.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(tab == item ? 1 : 0.7))
                        .padding(.horizontal, 18)
                        .frame(height: 26)
                        .background {
                            if tab == item {
                                Capsule()
                                    .fill(.white.opacity(0.2))
                                    .matchedGeometryEffect(id: "tab", in: tabNamespace)
                            }
                        }
                        .contentShape(Capsule())
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.28)) { tab = item }
                        }
                }
            }
            .padding(3)
            .background(Capsule().fill(.black.opacity(0.12)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))

            HStack {
                Spacer()
                settingsMenu
            }
        }
    }

    private var settingsMenu: some View {
        Menu {
            Button("Edit Profiles…") { openMain() }
            Button("Show Welcome…") {
                closePanel()
                openWindow(id: "onboarding")
                NSApp.activate()
            }
            Divider()
            Toggle("Open at Login", isOn: Binding(
                get: { SMAppService.mainApp.status == .enabled },
                set: { on in try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }))
            Divider()
            Button("Quit Loadout") { NSApp.terminate(nil) }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "gearshape.fill").font(.system(size: 15))
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.85))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: Now

    @ViewBuilder private var nowTab: some View {
        VStack(spacing: 0) {
            Image(systemName: active?.displaySymbol ?? "dock.rectangle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .contentTransition(.symbolEffect(.replace))
                .padding(.top, 24)

            Text(caption)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 10)

            Text(active?.name ?? "Loadout")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 24)
                .padding(.top, 2)

            buttons.padding(.top, 18)

            if let active {
                VStack(spacing: 6) {
                    dockRow(active)
                    wallpaperRow(active)
                }
                .padding(.top, 22)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .padding(.bottom, active == nil ? 14 : 0)
    }

    private var caption: String {
        guard active != nil else {
            return store.library.profiles.isEmpty ? "No profiles yet" : "No profile active"
        }
        switch applier.activationSource {
        case .focus: return "Switched by Focus"
        case .shortcut: return "Applied from Shortcuts"
        case .manual, nil: return "Active profile"
        }
    }

    @ViewBuilder private var buttons: some View {
        HStack(spacing: 8) {
            if let active {
                Button("Reapply") { applier.apply(active) }
                    .buttonStyle(GlassCapsuleStyle(prominent: true))
                Button("Edit") { openMain(editing: active.id) }
                    .buttonStyle(GlassCapsuleStyle())
                Button("Switch") { withAnimation(.snappy(duration: 0.28)) { tab = .profiles } }
                    .buttonStyle(GlassCapsuleStyle())
            } else if store.library.profiles.isEmpty {
                Button("Create Profile") { newProfile() }
                    .buttonStyle(GlassCapsuleStyle(prominent: true))
            } else {
                Button("Choose a Profile") { withAnimation(.snappy(duration: 0.28)) { tab = .profiles } }
                    .buttonStyle(GlassCapsuleStyle(prominent: true))
            }
        }
    }

    private func dockRow(_ profile: Profile) -> some View {
        GlassRow {
            HStack(spacing: 10) {
                IconSquare(symbol: "dock.rectangle", tint: ProfileTint.yellow.color)
                Text("Dock").font(.system(size: 14, weight: .medium))
                Spacer()
                if profile.changesDock {
                    HStack(spacing: -5) {
                        ForEach(profile.dockApps.prefix(4), id: \.self) { path in
                            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                    }
                    Text(profile.appCountText)
                        .font(.system(size: 13, weight: .semibold))
                } else {
                    Text("Unchanged").font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    private func wallpaperRow(_ profile: Profile) -> some View {
        GlassRow {
            HStack(spacing: 10) {
                IconSquare(symbol: "photo.fill", tint: ProfileTint.pink.color)
                Text("Wallpaper").font(.system(size: 14, weight: .medium))
                Spacer()
                if profile.changesWallpaper, let path = profile.wallpaperPath {
                    Text((path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 110, alignment: .trailing)
                    WallpaperThumbnail(path: path)
                } else {
                    Text("Unchanged").font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    // MARK: Profiles

    private var profilesTab: some View {
        VStack(spacing: 6) {
            if store.library.profiles.count > 5 {
                ScrollView { profileRows }.frame(height: 300)
            } else {
                profileRows
            }
            Button { newProfile() } label: { Label("New Profile", systemImage: "plus") }
                .buttonStyle(GlassCapsuleStyle())
                .padding(.top, 10)
        }
        .padding(.horizontal, 10)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var profileRows: some View {
        VStack(spacing: 6) {
            ForEach(store.library.profiles) { profile in
                ProfileRow(profile: profile,
                           isActive: profile.id == applier.activeProfileID,
                           isDefault: profile.id == store.library.defaultProfileID) {
                    applier.apply(profile)
                    withAnimation(.snappy(duration: 0.28)) { tab = .now }
                }
            }
        }
    }

    // MARK: Actions

    private func openMain(editing id: UUID? = nil) {
        closePanel()
        openWindow(id: "main")
        NSApp.activate()
        guard let id else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .editProfileRequested, object: id)
        }
    }

    /// Closes this menu bar panel so it doesn't sit on top of the window being opened.
    private func closePanel() {
        dismiss()
        // Fallback in case the system keeps a window-style menu bar extra open after dismiss().
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApp.windows
                .filter { String(describing: type(of: $0)).contains("MenuBarExtra") && $0.isVisible }
                .forEach { $0.orderOut(nil) }
        }
    }

    private func newProfile() {
        openMain()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .newProfileRequested, object: nil)
        }
    }
}

private struct ProfileRow: View {
    let profile: Profile
    let isActive: Bool
    let isDefault: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            GlassRow(highlighted: hovering || isActive) {
                HStack(spacing: 10) {
                    IconSquare(symbol: profile.displaySymbol, tint: profile.displayTint.color)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile.name.isEmpty ? "Untitled" : profile.name)
                            .font(.system(size: 14, weight: .medium))
                        Text(summary)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    if isDefault {
                        Text("No Focus")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.white.opacity(0.12)))
                    }
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var summary: String {
        var parts: [String] = []
        if profile.changesDock { parts.append(profile.appCountText) }
        if profile.changesWallpaper && profile.wallpaperPath != nil { parts.append("wallpaper") }
        return parts.isEmpty ? "No changes" : parts.joined(separator: " · ")
    }
}

/// Wallpaper-tinted gradient with a soft highlight in the top-left corner.
private struct PanelBackground: View {
    let tint: Color

    var body: some View {
        LinearGradient(colors: [tint.opacity(0.8), tint.mix(with: .black, by: 0.3).opacity(0.9)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                RadialGradient(colors: [.white.opacity(0.1), .clear],
                               center: UnitPoint(x: 0.15, y: 0), startRadius: 0, endRadius: 280)
            }
    }
}
