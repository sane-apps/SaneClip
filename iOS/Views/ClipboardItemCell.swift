import SwiftUI

/// Cell for displaying a clipboard item - matches macOS design aesthetic
struct ClipboardItemCell: View {
    let item: SharedClipboardItem
    var isPinned: Bool = false
    var isCopied: Bool = false
    var isSelected: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isIPad: Bool {
        sizeClass == .regular
    }

    private let isScreenshotMode = LaunchOptions.isScreenshotMode()

    // MARK: - Source-Aware Colors

    /// Harmonious muted palette — each hue family is distinct, no two colors clash.
    /// Dark mode: bright/saturated for readability on dark backgrounds.
    /// Light mode: darkened variants for WCAG AA (4.5:1) on light backgrounds.
    /// Shared with macOS `ClipboardItemRow` via `SaneClipSourceColor`
    /// (Core/BrandColors.swift): curated colors for well-known apps, a stable
    /// hashed color for every other source so nothing defaults to plain blue.
    private var sourceColor: Color {
        SaneClipSourceColor.color(forSourceNamed: item.sourceAppName, dark: colorScheme == .dark)
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
        if isSelected {
            return accentColor.opacity(0.08)
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
        if isIPad {
            return item.isCode
                ? .system(size: 24, weight: .semibold, design: .monospaced)
                : .system(size: 24, weight: .semibold)
        }
        return item.isCode
            ? .system(.subheadline, design: .monospaced, weight: .semibold)
            : .system(.subheadline, weight: .semibold)
    }

    /// Preview text: bright white in dark, near-black in light
    private var previewColor: Color {
        colorScheme == .dark ? Color.textCloud : Color(hex: 0x1A1A1A)
    }

    /// Metadata: white (never gray — SaneApps rule)
    private var metadataColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.9) : Color(hex: 0x333333)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Accent bar on left — orange for pinned, source color otherwise
            RoundedRectangle(cornerRadius: 2)
                .fill(barColor)
                .frame(width: isIPad ? 6 : 3)

            HStack(alignment: .top, spacing: isIPad ? 20 : 10) {
                // Pin indicator
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(isIPad ? .title3 : .caption2)
                        .foregroundStyle(Color.pinnedOrange)
                        .padding(.top, isIPad ? 4 : 2)
                }

                // Content type icon
                Image(systemName: iconName)
                    .font(isIPad ? .title : .callout)
                    .foregroundStyle(accentColor)
                    .frame(width: isIPad ? 32 : 18)
                    .padding(.top, isIPad ? 4 : 2)

                VStack(alignment: .leading, spacing: isIPad ? 12 : 4) {
                    // Preview text or image thumbnail
                    switch item.content {
                    case .text:
                        Text(item.preview)
                            .font(itemFont)
                            .lineLimit(isIPad ? 3 : 2)
                            .foregroundColor(previewColor)
                    case let .imageData(data, _, _):
                        if let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: isIPad ? 200 : 60)
                                .clipShape(RoundedRectangle(cornerRadius: isIPad ? 8 : 4))
                        } else {
                            Text("[Image]")
                                .font(itemFont)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }

                    // Metadata row
                    HStack(spacing: isIPad ? 10 : 6) {
                        Text(item.relativeTime)
                            .font(isIPad ? .system(size: 18) : .caption)
                            .foregroundStyle(metadataColor)

                        if let source = item.sourceAppName {
                            Text("·")
                                .font(isIPad ? .system(size: 18) : .caption)
                                .foregroundStyle(metadataColor)
                            Text(source)
                                .font(isIPad ? .system(size: 18) : .caption)
                                .foregroundColor(accentColor)
                        }

                        if !item.deviceName.isEmpty, !isScreenshotMode {
                            Text("·")
                                .font(isIPad ? .system(size: 18) : .caption)
                                .foregroundStyle(metadataColor)
                            Text(item.deviceName)
                                .font(isIPad ? .system(size: 18) : .caption)
                                .foregroundStyle(metadataColor)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Chevron hint for detail view
                Image(systemName: "chevron.right")
                    .font(isIPad ? .title3 : .caption)
                    .foregroundStyle(metadataColor)
                    .padding(.top, isIPad ? 8 : 2)
            }
            .padding(.horizontal, isIPad ? 24 : 10)
            .padding(.vertical, isIPad ? 24 : 10)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 16 : 8))
        .overlay(
            RoundedRectangle(cornerRadius: isIPad ? 16 : 8)
                .strokeBorder(
                    isCopied
                        ? accentColor.opacity(0.3)
                        : isSelected
                        ? accentColor.opacity(0.55)
                        : (colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.black.opacity(0.06)),
                    lineWidth: isCopied || isSelected ? 1.5 : 0.5
                )
        )
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isCopied)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
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
