import SwiftUI

/// Sane Apps Brand Color Palette
/// Reference: ~/SaneApps/meta/Brand/SaneApps-Brand-Guidelines.md
extension Color {
    // MARK: - SaneClip Accent

    /// Primary accent color for SaneClip - Clip Blue #4f8ffa
    static let clipBlue = Color(hex: 0x4F8FFA)

    /// Pinned items accent - Warning Orange #f59e0b
    static let pinnedOrange = Color(hex: 0xF59E0B)

    // MARK: - Brand Primary

    /// Navy - Logo background, dark surfaces #1a2744
    static let brandNavy = Color(hex: 0x1A2744)

    /// Deep Navy - Gradient endpoint #0d1525
    static let brandDeepNavy = Color(hex: 0x0D1525)

    /// Glowing Teal - Highlights, CTAs #5fa8d3
    static let brandTeal = Color(hex: 0x5FA8D3)

    /// Silver - Secondary elements #a8b4c4
    static let brandSilver = Color(hex: 0xA8B4C4)

    // MARK: - Surface Colors

    /// Void - Backgrounds #0a0a0a
    static let surfaceVoid = Color(hex: 0x0A0A0A)

    /// Carbon - Cards, elevated surfaces #141414
    static let surfaceCarbon = Color(hex: 0x141414)

    /// Smoke - Borders, dividers #222222
    static let surfaceSmoke = Color(hex: 0x222222)

    // MARK: - Text Colors

    /// Stone - Muted text (like .secondary) #888888
    static let textStone = Color(hex: 0x888888)

    /// Cloud - Primary text #e5e5e5
    static let textCloud = Color(hex: 0xE5E5E5)

    // MARK: - Semantic Colors

    /// Success green #22c55e
    static let semanticSuccess = Color(hex: 0x22C55E)

    /// Warning amber #f59e0b
    static let semanticWarning = Color(hex: 0xF59E0B)

    /// Error red #ef4444
    static let semanticError = Color(hex: 0xEF4444)
}

// MARK: - Hex Initializer

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Clipboard Source-App Colors (shared by Mac + iOS)

/// Single source of truth for the per-source-app accent color used by history
/// rows on both platforms (macOS `ClipboardItemRow` and iOS `ClipboardItemCell`
/// both call this, so the two never drift). Well-known apps get a curated
/// color; every other source gets a deterministic, launch-stable color derived
/// from its name — so the list is fully color-coded instead of defaulting
/// unmapped apps (Brave, Chrome, Codex, QuickTime, …) to the same blue.
enum SaneClipSourceColor {
    /// - Parameters:
    ///   - name: `sourceAppName` (case-insensitive); `nil`/empty → brand blue.
    ///   - dark: whether the UI is in dark mode (affects saturation/brightness).
    static func color(forSourceNamed name: String?, dark: Bool) -> Color {
        guard let raw = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return .clipBlue }
        let source = raw.lowercased()
        return curated(source, dark: dark) ?? hashed(source, dark: dark)
    }

    /// Hand-tuned colors for Apple system apps + a few high-frequency
    /// third-party apps. `nil` means "not curated — use the hashed fallback."
    private static func curated(_ source: String, dark: Bool) -> Color? {
        if dark {
            switch source {
            case "messages": Color(hex: 0x5EC2A0)
            case "mail": Color(hex: 0xE8807C)
            case "safari", "safari technology preview": Color(hex: 0x6BADE4)
            case "notes": Color(hex: 0xE4C05C)
            case "maps": Color(hex: 0x4B9FE8)
            case "contacts": Color(hex: 0xC8ACE4)
            case "calendar": Color(hex: 0xD4849A)
            case "photos": Color(hex: 0xE89A3C)
            case "reminders": Color(hex: 0x8A9FE4)
            case "terminal", "iterm", "iterm2": Color(hex: 0x66E08E)
            case "xcode": Color(hex: 0x6B7FE8)
            case "finder": Color(hex: 0x4DD4D4)
            case "slack": Color(hex: 0xD464CC)
            case "brave browser", "brave": Color(hex: 0xF2795F)
            case "google chrome", "chrome": Color(hex: 0xE4B84C)
            case "arc": Color(hex: 0xE47FA6)
            case "visual studio code", "code", "vscode": Color(hex: 0x4FA3E8)
            default: nil
            }
        } else {
            switch source {
            case "messages": Color(hex: 0x2E8B6A)
            case "mail": Color(hex: 0xC4524E)
            case "safari", "safari technology preview": Color(hex: 0x3A7DB8)
            case "notes": Color(hex: 0x9E8528)
            case "maps": Color(hex: 0x2D7AC2)
            case "contacts": Color(hex: 0x7A5FA8)
            case "calendar": Color(hex: 0xA8566E)
            case "photos": Color(hex: 0xB87A22)
            case "reminders": Color(hex: 0x4E62A8)
            case "terminal", "iterm", "iterm2": Color(hex: 0x2D8A4E)
            case "xcode": Color(hex: 0x4450A8)
            case "finder": Color(hex: 0x2A8FA8)
            case "slack": Color(hex: 0xA03898)
            case "brave browser", "brave": Color(hex: 0xC4482F)
            case "google chrome", "chrome": Color(hex: 0x9E7A22)
            case "arc": Color(hex: 0xB04E70)
            case "visual studio code", "code", "vscode": Color(hex: 0x2E7AB8)
            default: nil
            }
        }
    }

    /// Deterministic, launch-stable color from the source name. Uses a djb2
    /// hash (NOT Swift's per-run-randomized `hashValue`) so an app keeps the
    /// same color across launches, mapped to a hue with fixed saturation /
    /// brightness tuned for contrast in each appearance.
    private static func hashed(_ source: String, dark: Bool) -> Color {
        var hash: UInt64 = 5381
        for byte in source.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        let hue = Double(hash % 360) / 360.0
        return Color(
            hue: hue,
            saturation: dark ? 0.52 : 0.70,
            brightness: dark ? 0.82 : 0.58
        )
    }
}
