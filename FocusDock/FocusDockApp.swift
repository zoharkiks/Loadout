import SwiftUI

@main
struct FocusDockApp: App {
    @StateObject private var store = ProfileStore.shared
    @StateObject private var applier = ProfileApplier.shared

    var body: some Scene {
        MenuBarExtra {
            MenuPanel()
                .environmentObject(store)
                .environmentObject(applier)
        } label: {
            Image(systemName: store.profile(id: applier.activeProfileID)?.displaySymbol ?? "dock.rectangle")
        }
        .menuBarExtraStyle(.window)

        Window("FocusDock", id: "main") {
            SettingsView()
                .environmentObject(store)
                .environmentObject(applier)
                .frame(minWidth: 820, minHeight: 600)
                .activatesApp()
        }
        .windowStyle(.hiddenTitleBar)
        // macOS may launch the app in the background to run the Focus filter; don't pop a window then.
        .defaultLaunchBehavior(.suppressed)

        Window("Welcome to FocusDock", id: "onboarding") {
            OnboardingView()
                .activatesApp()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultLaunchBehavior(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") ? .suppressed : .presented)
    }
}

/// A menu-bar-only app has no menu bar of its own, so moving the mouse to the top of the screen hands
/// the menu bar (and focus) to another app and our window drops behind it. While any of our windows
/// is open, act like a normal app instead: own menu bar, Dock icon, ⌘-Tab. Go back to menu-bar-only
/// once the last window closes.
@MainActor
enum WindowActivation {
    private static var openWindows = 0

    static func windowOpened() {
        openWindows += 1
        // An app that starts menu-bar-only gets a blank Dock tile when it turns regular,
        // unless it hands over its icon explicitly.
        NSApp.applicationIconImage = NSImage(named: NSImage.applicationIconName)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    static func windowClosed() {
        openWindows = max(openWindows - 1, 0)
        if openWindows == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

extension View {
    func activatesApp() -> some View {
        onAppear { WindowActivation.windowOpened() }
            .onDisappear { WindowActivation.windowClosed() }
    }
}
