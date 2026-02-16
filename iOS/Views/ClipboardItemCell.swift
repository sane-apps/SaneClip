import SwiftUI

/// Cell for displaying a clipboard item - matches macOS design aesthetic
struct ClipboardItemCell: View {
    let item: SharedClipboardItem
    var isPinned: Bool = false
    var isCopied: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Source-Aware Colors

    /// Harmonious muted palette — each hue family is distinct, no two colors clash.
    /// Dark mode: bright/saturated for readability on dark backgrounds.
    /// Light mode: darkened variants for WCAG AA (4.5:1) on light backgrounds.
    private var sourceColor: Color {
        guard let source = item.sourceAppName?.lowercased() else { return Color.teal }
        if colorScheme == .dark {
            switch source {
            case "messages": return Color(hex: 0x5EC2A0) // Sage green
            case "mail": return Color(hex: 0xE8807C) // Soft coral
            case "safari": return Color(hex: 0x6BADE4) // Sky blue
            case "notes": return Color(hex: 0xE4C05C) // Warm gold
            case "maps": return Color(hex: 0x4B9FE8) // Blue
            case "contacts": return Color(hex: 0xC8ACE4) // Soft lavender (boosted)
            case "calendar": return Color(hex: 0xD4849A) // Dusty rose
            case "photos": return Color(hex: 0xE89A3C) // Warm amber (distinct from gold)
            case "reminders": return Color(hex: 0x8A9FE4) // Periwinkle (boosted)
            case "terminal": return Color(hex: 0x66E08E) // Lime green
            case "xcode": return Color(hex: 0x6B7FE8) // Indigo
            case "finder": return Color(hex: 0x4DD4D4) // Cyan
            case "slack": return Color(hex: 0xD464CC) // Fuchsia
            default: return Color.teal
            }
        } else {
            switch source {
            case "messages": return Color(hex: 0x2E8B6A) // Deep sage
            case "mail": return Color(hex: 0xC4524E) // Deep coral
            case "safari": return Color(hex: 0x3A7DB8) // Deep sky
            case "notes": return Color(hex: 0x9E8528) // Deep gold
            case "maps": return Color(hex: 0x2D7AC2) // Deep blue
            case "contacts": return Color(hex: 0x7A5FA8) // Deep lavender
            case "calendar": return Color(hex: 0xA8566E) // Deep rose
            case "photos": return Color(hex: 0xB87A22) // Deep amber
            case "reminders": return Color(hex: 0x4E62A8) // Deep periwinkle
            case "terminal": return Color(hex: 0x2D8A4E) // Deep lime
            case "xcode": return Color(hex: 0x4450A8) // Deep indigo
            case "finder": return Color(hex: 0x2A8FA8) // Deep cyan
            case "slack": return Color(hex: 0xA03898) // Deep fuchsia
            default: return Color.teal
            }
        }
    }

    /// Bar color: orange for pinned, source color otherwise
    private var barColor: Color {
        isPinned ? Color.pinnedOrange : sourceColor
    }

    /// Accent for icons and source labels: always source-aware, even on pinned items
    private var accentColor: Color {
        sourceColor
    }

    private var cardBackground: Color {
        if isCopied {
            return accentColor.opacity(0.12)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.03)
    }

    // MARK: - Content Detection

    private var iconName: String {
        if isCopied { return "checkmark.circle.fill" }
        switch item.content {
        case .text:
            if item.isURL { return "link" }
            if item.isCode { return "curlybraces" }
            return "text.alignleft"
        case .imageData:
            return "photo"
        }
    }

    private var itemFont: Font {
        item.isCode
            ? .system(.subheadline, design: .monospaced, weight: .semibold)
            : .system(.subheadline, weight: .semibold)
    }

    /// Preview text: bright white in dark, near-black in light
    private var previewColor: Color {
        colorScheme == .dark ? Color.textCloud : Color(hex: 0x1A1A1A)
    }

    /// Metadata: readable gray, not washed out
    private var metadataColor: Color {
        colorScheme == .dark ? Color.textStone : Color(hex: 0x555555)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Accent bar on left — orange for pinned, source color otherwise
            RoundedRectangle(cornerRadius: 2)
                .fill(barColor)
                .frame(width: 3)

            HStack(alignment: .top, spacing: 10) {
                // Pin indicator
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.pinnedOrange)
                        .padding(.top, 2)
                }

                // Content type icon
                Image(systemName: iconName)
                    .font(.callout)
                    .foregroundStyle(accentColor)
                    .frame(width: 18)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    // Preview text or image thumbnail
                    switch item.content {
                    case .text:
                        Text(item.preview)
                            .font(itemFont)
                            .lineLimit(2)
                            .foregroundColor(previewColor)
                    case let .imageData(data, _, _):
                        if let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            Text("[Image]")
                                .font(itemFont)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }

                    // Metadata row
                    HStack(spacing: 6) {
                        Text(item.relativeTime)
                            .font(.caption)
                            .foregroundStyle(metadataColor)

                        if let source = item.sourceAppName {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(metadataColor)
                            Text(source)
                                .font(.caption)
                                .foregroundColor(accentColor)
                        }

                        if !item.deviceName.isEmpty {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(metadataColor)
                            Text(item.deviceName)
                                .font(.caption)
                                .foregroundStyle(metadataColor)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Chevron hint for detail view
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(metadataColor)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isCopied
                        ? accentColor.opacity(0.3)
                        : (colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.black.opacity(0.06)),
                    lineWidth: isCopied ? 1 : 0.5
                )
        )
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isCopied)
    }
}

#Preview {
    List {
        ClipboardItemCell(
            item: SharedClipboardItem(
                content: .text("Sample clipboard text that might be a bit longer"),
                sourceAppName: "Safari"
            )
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        .listRowSeparator(.hidden)

        ClipboardItemCell(
            item: SharedClipboardItem(
                content: .text("https://example.com/page?utm_source=test"),
                sourceAppName: "Chrome"
            ),
            isCopied: true
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        .listRowSeparator(.hidden)

        ClipboardItemCell(
            item: SharedClipboardItem(
                content: .text("func hello() { print(\"Hi\") }"),
                sourceAppName: "Xcode"
            ),
            isPinned: true
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
}
