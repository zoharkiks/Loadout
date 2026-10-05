import ImageIO
import SwiftUI

// MARK: - Profile appearance

enum ProfileTint: String, Codable, CaseIterable, Identifiable {
    case blue, purple, pink, red, orange, yellow, green, teal, graphite

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: .rgb(0.10, 0.52, 1.00)
        case .purple: .rgb(0.60, 0.36, 0.96)
        case .pink: .rgb(0.90, 0.38, 0.84)
        case .red: .rgb(0.98, 0.30, 0.30)
        case .orange: .rgb(1.00, 0.56, 0.12)
        case .yellow: .rgb(0.84, 0.70, 0.08)
        case .green: .rgb(0.22, 0.74, 0.36)
        case .teal: .rgb(0.10, 0.70, 0.78)
        case .graphite: .rgb(0.52, 0.55, 0.60)
        }
    }
}

enum ProfileSymbols {
    static let all = [
        "briefcase.fill", "house.fill", "gamecontroller.fill", "moon.fill",
        "book.fill", "paintbrush.fill", "film.fill", "music.note",
        "dumbbell.fill", "cup.and.saucer.fill", "graduationcap.fill", "bolt.fill",
        "leaf.fill", "sparkles", "camera.fill", "hammer.fill",
    ]
}

// MARK: - Wallpaper-driven tint

extension Profile {
    /// The profile's colour, deepened so white text stays readable. Every themed screen uses this.
    var themeColor: Color { displayTint.color.mix(with: .black, by: 0.5) }
}

/// The app-wide tint: the active profile's colour, or the wallpaper's when no profile is active.
@MainActor
final class ThemeModel: ObservableObject {
    static let shared = ThemeModel()

    /// Warm amber until a wallpaper has been sampled.
    @Published private(set) var tint = Color(hue: 0.08, saturation: 0.75, brightness: 0.5)

    private var cache: [String: Color] = [:]

    func refresh(for profile: Profile?) {
        if let profile { return set(profile.themeColor) }

        guard let url = NSScreen.main.flatMap({ NSWorkspace.shared.desktopImageURL(for: $0) }) else { return }
        if let cached = cache[url.path] { return set(cached) }

        Task.detached(priority: .utility) {
            guard let average = Self.averageColor(of: url) else { return }
            await MainActor.run {
                let color = Self.panelTint(from: average)
                self.cache[url.path] = color
                self.set(color)
            }
        }
    }

    private func set(_ color: Color) {
        withAnimation(.smooth(duration: 0.6)) { tint = color }
    }

    /// Average of a small thumbnail, weighted toward saturated pixels so the result isn't muddy.
    nonisolated private static func averageColor(of url: URL) -> NSColor? {
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceThumbnailMaxPixelSize: 48] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options),
              let context = CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: 16, height: 16))
        guard let data = context.data else { return nil }

        let pixels = data.bindMemory(to: UInt8.self, capacity: 16 * 16 * 4)
        var red = 0.0, green = 0.0, blue = 0.0, total = 0.0
        for i in stride(from: 0, to: 16 * 16 * 4, by: 4) {
            let r = Double(pixels[i]) / 255, g = Double(pixels[i + 1]) / 255, b = Double(pixels[i + 2]) / 255
            let weight = 0.15 + max(r, g, b) - min(r, g, b)
            red += r * weight; green += g * weight; blue += b * weight; total += weight
        }
        return NSColor(srgbRed: red / total, green: green / total, blue: blue / total, alpha: 1)
    }

    /// Keeps the wallpaper's hue but fixes brightness so white text always reads well.
    nonisolated private static func panelTint(from color: NSColor) -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        color.usingColorSpace(.sRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(hue: hue, saturation: min(max(saturation * 1.25, 0.3), 0.85), brightness: 0.48)
    }
}

// MARK: - Components

/// Rounded, colour-filled square with a white glyph, like an app icon.
struct IconSquare: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(LinearGradient(colors: [tint.mix(with: .white, by: 0.18), tint],
                                         startPoint: .top, endPoint: .bottom))
            }
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
    }
}

/// Capsule button for the glass panel: filled when prominent, outlined otherwise.
struct GlassCapsuleStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        let fill = prominent ? (configuration.isPressed ? 0.32 : 0.22) : (configuration.isPressed ? 0.12 : 0)
        return configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, prominent ? 18 : 14)
            .frame(height: 32)
            .background(Capsule().fill(.white.opacity(fill)))
            .overlay(Capsule().strokeBorder(.white.opacity(prominent ? 0.1 : 0.22), lineWidth: 1))
            .contentShape(Capsule())
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Soft translucent row container used throughout the panel.
struct GlassRow<Content: View>: View {
    var highlighted = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(highlighted ? 0.15 : 0.08))
            }
    }
}

/// Small wallpaper preview, decoded as a thumbnail so large images stay cheap.
struct WallpaperThumbnail: View {
    let path: String?
    var size = CGSize(width: 32, height: 20)
    var pixelSize = 96
    var cornerRadius: CGFloat = 4
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 2).resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(.white.opacity(0.12))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
        .task(id: path) {
            guard let path else { image = nil; return }
            let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                           kCGImageSourceCreateThumbnailWithTransform: true,
                           kCGImageSourceThumbnailMaxPixelSize: pixelSize] as CFDictionary
            image = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)
                .flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, options) }
        }
    }
}
