import SwiftUI

/// First-launch welcome window: a few paged cards with a soft gradient header.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.colorScheme) private var colorScheme

    @State private var page: Int
    @State private var forward = true

    init(initialPage: Int = 0) {
        _page = State(initialValue: initialPage)
    }

    private var isLastPage: Bool { page == Self.pages.count - 1 }

    var body: some View {
        ZStack(alignment: .top) {
            background

            VStack(spacing: 0) {
                ZStack {
                    PageContent(index: page, primaryAction: primaryAction, secondaryAction: secondaryAction)
                        .id(page)
                        .transition(.asymmetric(
                            insertion: .offset(x: forward ? 48 : -48).combined(with: .opacity),
                            removal: .offset(x: forward ? -48 : 48).combined(with: .opacity)))
                }
                .frame(maxHeight: .infinity, alignment: .top)

                PageDots(count: Self.pages.count, current: page) { go(to: $0) }
                    .padding(.bottom, 30)
            }

            if !isLastPage {
                Button("Skip") { finish(createProfile: false) }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 14)
                    .padding(.trailing, 20)
            }
        }
        .frame(width: 560, height: 620)
        .ignoresSafeArea()
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.rightArrow) { go(to: page + 1); return .handled }
        .onKeyPress(.leftArrow) { go(to: page - 1); return .handled }
        .onAppear { NSApp.activate() }
        // Closing the window counts as done, so it doesn't come back on every launch.
        .onDisappear { hasCompletedOnboarding = true }
    }

    private var background: some View {
        ZStack(alignment: .top) {
            Onboarding.cardColor(colorScheme)
            GradientHeader(palette: Self.pages[page].palette)
                .frame(height: 360)
                .animation(.smooth(duration: 0.6), value: page)
        }
    }

    // MARK: Navigation

    private func go(to newPage: Int) {
        guard newPage != page, Self.pages.indices.contains(newPage) else { return }
        forward = newPage > page
        DispatchQueue.main.async {
            withAnimation(.smooth(duration: 0.45)) { page = newPage }
        }
    }

    private func primaryAction() {
        isLastPage ? finish(createProfile: true) : go(to: page + 1)
    }

    private func secondaryAction() {
        switch page {
        case 3:
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension")!)
        case Self.pages.count - 1:
            finish(createProfile: false)
        default:
            break
        }
    }

    private func finish(createProfile: Bool) {
        hasCompletedOnboarding = true
        dismissWindow(id: "onboarding")
        guard createProfile else { return }
        openWindow(id: "main")
        NSApp.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .newProfileRequested, object: nil)
        }
    }

    // MARK: Pages

    struct Page {
        let title: String
        let message: String
        let button: String
        var secondaryButton: String?
        /// Six colours for the header mesh: three along the top edge, three across the middle.
        let palette: [Color]
    }

    static let pages: [Page] = [
        Page(title: "Welcome to Loadout",
             message: "Loadout gives every Focus mode its own Dock and wallpaper, so your Mac changes with what you're doing.",
             button: "Continue",
             palette: [.rgb(0.66, 0.89, 1.00), .rgb(0.74, 0.82, 1.00), .rgb(0.60, 0.71, 1.00),
                       .rgb(0.84, 0.94, 1.00), .rgb(0.89, 0.83, 1.00), .rgb(0.80, 0.84, 1.00)]),
        Page(title: "A Dock for every Focus",
             message: "Build profiles with just the apps and folders you need for work, play or winding down.",
             button: "Continue",
             palette: [.rgb(1.00, 0.86, 0.92), .rgb(0.91, 0.80, 1.00), .rgb(0.78, 0.71, 1.00),
                       .rgb(1.00, 0.94, 0.97), .rgb(0.94, 0.87, 1.00), .rgb(0.87, 0.82, 1.00)]),
        Page(title: "Wallpaper that follows along",
             message: "Pick a wallpaper for each profile. It's set on every display the moment a Focus turns on.",
             button: "Continue",
             palette: [.rgb(1.00, 0.87, 0.78), .rgb(1.00, 0.82, 0.86), .rgb(0.93, 0.80, 1.00),
                       .rgb(1.00, 0.95, 0.90), .rgb(1.00, 0.91, 0.93), .rgb(0.95, 0.90, 1.00)]),
        Page(title: "Connect your Focus modes",
             message: "In System Settings › Focus, open a Focus, choose Add Filter › Loadout and pick a profile.",
             button: "Continue",
             secondaryButton: "Open Focus Settings",
             palette: [.rgb(0.70, 0.93, 0.95), .rgb(0.80, 0.95, 0.86), .rgb(0.72, 0.93, 0.72),
                       .rgb(0.87, 0.97, 0.98), .rgb(0.90, 0.97, 0.91), .rgb(0.86, 0.96, 0.86)]),
        Page(title: "You're all set",
             message: "Create your first profile to get started. You can change everything later from the menu bar.",
             button: "Create First Profile",
             secondaryButton: "Maybe Later",
             palette: [.rgb(0.68, 0.87, 1.00), .rgb(0.72, 0.80, 1.00), .rgb(0.64, 0.74, 1.00),
                       .rgb(0.85, 0.94, 1.00), .rgb(0.86, 0.85, 1.00), .rgb(0.82, 0.86, 1.00)]),
    ]
}

// MARK: - Page content

private struct PageContent: View {
    let index: Int
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    private var page: OnboardingView.Page { OnboardingView.pages[index] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            illustration
                .frame(maxWidth: .infinity)
                .frame(height: 330)

            VStack(alignment: .leading, spacing: 10) {
                Text(page.title)
                    .font(.system(size: 27, weight: .semibold))
                    .kerning(-0.4)
                Text(page.message)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 400, alignment: .leading)
            }
            .padding(.top, 6)

            HStack(spacing: 20) {
                Button(page.button, action: primaryAction)
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut(.defaultAction)
                if let secondary = page.secondaryButton {
                    Button(secondary, action: secondaryAction)
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Onboarding.accent)
                }
            }
            .padding(.top, 26)
        }
        .padding(.horizontal, 52)
    }

    @ViewBuilder private var illustration: some View {
        switch index {
        case 0:
            IconTile(size: 124) {
                Image(systemName: "dock.rectangle")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [.rgb(0.30, 0.72, 1.00), Onboarding.accent],
                                                    startPoint: .top, endPoint: .bottom))
                    .shadow(color: Onboarding.accent.opacity(0.35), radius: 8, y: 4)
            }
            .padding(.top, 40)
        case 1:
            ProfileListIllustration()
                .padding(.top, 64)
                .frame(maxHeight: .infinity, alignment: .top)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
        case 2:
            WallpaperIllustration()
                .padding(.top, 36)
        case 3:
            HStack(spacing: 22) {
                IconTile(size: 116) { SlateSymbol(name: "moon.fill") }
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Onboarding.slate.opacity(0.7))
                IconTile(size: 116) { SlateSymbol(name: "dock.rectangle") }
            }
            .padding(.top, 36)
        default:
            IconTile(size: 124) { SlateSymbol(name: "checkmark", weight: .bold) }
                .padding(.top, 40)
        }
    }
}

// MARK: - Building blocks

enum Onboarding {
    static let accent = Color.rgb(0.03, 0.55, 1.00)
    static let slate = Color.rgb(0.55, 0.62, 0.75)

    static func cardColor(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .rgb(0.11, 0.11, 0.13) : .white
    }

    static func tileColor(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .rgb(0.19, 0.19, 0.22) : .white.opacity(0.92)
    }
}

extension Color {
    static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red, green: green, blue: blue)
    }
}

/// Slowly drifting pastel mesh that fades into the card colour at the bottom.
private struct GradientHeader: View {
    let palette: [Color]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let base = Onboarding.cardColor(colorScheme)
            let colors = palette.map { colorScheme == .dark ? base.mix(with: $0, by: 0.28) : $0 }
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [Float(0.5 + 0.12 * sin(t * 0.35)), 0], [1, 0],
                    [0, 0.5], [Float(0.5 + 0.15 * sin(t * 0.5)), Float(0.45 + 0.08 * cos(t * 0.4))], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: colors + [base, base, base])
        }
    }
}

/// Frosted white rounded square with a soft drop shadow, like the reference's icon tiles.
private struct IconTile<Content: View>: View {
    let size: CGFloat
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                    .fill(Onboarding.tileColor(colorScheme))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 24, y: 12)
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.08 : 0.7), lineWidth: 1)
            }
    }
}

private struct SlateSymbol: View {
    let name: String
    var weight: Font.Weight = .semibold

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 50, weight: weight))
            .foregroundStyle(LinearGradient(colors: [Onboarding.slate.opacity(0.85), Onboarding.slate],
                                            startPoint: .top, endPoint: .bottom))
    }
}

private struct ProfileListIllustration: View {
    @Environment(\.colorScheme) private var colorScheme

    private let rows: [(name: String, symbol: String, color: Color, count: Int)] = [
        ("Work", "briefcase.fill", .blue, 8),
        ("Personal", "house.fill", .orange, 6),
        ("Gaming", "gamecontroller.fill", .purple, 5),
        ("Sleep", "moon.fill", .indigo, 3),
    ]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                HStack(spacing: 12) {
                    Image(systemName: row.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(row.color)
                        .frame(width: 22)
                    Text(row.name)
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                    Text("\(row.count) apps")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.primary.opacity(0.05)))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background {
                    if index == 2 {
                        RoundedRectangle(cornerRadius: 11, style: .continuous).fill(.primary.opacity(0.06))
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .frame(width: 320)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Onboarding.tileColor(colorScheme))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.07), radius: 24, y: 10)
        }
    }
}

private struct WallpaperIllustration: View {
    var body: some View {
        ZStack {
            MiniDesktop(colors: [.rgb(0.35, 0.55, 0.98), .rgb(0.55, 0.85, 0.95)])
                .rotationEffect(.degrees(-7))
                .offset(x: -70, y: 10)
            MiniDesktop(colors: [.rgb(1.00, 0.62, 0.45), .rgb(0.93, 0.45, 0.70)])
                .rotationEffect(.degrees(6))
                .offset(x: 70, y: -6)
        }
        .frame(height: 220)
    }
}

/// Tiny desktop: a wallpaper with a Dock along the bottom.
private struct MiniDesktop: View {
    let colors: [Color]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 200, height: 130)
            .overlay(alignment: .bottom) {
                HStack(spacing: 5) {
                    ForEach(0..<5) { _ in
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(.white.opacity(0.9))
                            .frame(width: 14, height: 14)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(0.35)))
                .padding(.bottom, 9)
            }
            .padding(5)
            .background {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(Onboarding.tileColor(colorScheme))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.1), radius: 20, y: 10)
            }
    }
}

private struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 30)
            .frame(height: 48)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [.rgb(0.16, 0.63, 1.00), Onboarding.accent],
                                         startPoint: .top, endPoint: .bottom))
            }
            .shadow(color: Onboarding.accent.opacity(0.28), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int
    let select: (Int) -> Void

    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.primary.opacity(0.85) : Color.primary.opacity(0.18))
                    .frame(width: 7, height: 7)
                    .contentShape(Rectangle().inset(by: -4))
                    .onTapGesture { select(index) }
            }
        }
        .animation(.smooth, value: current)
    }
}
