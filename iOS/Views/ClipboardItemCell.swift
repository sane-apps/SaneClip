import SwiftUI

/// Cell for displaying a clipboard item - matches macOS design aesthetic
struct ClipboardItemCell: View {
    let item: SharedClipboardItem
    var isPinned: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Brand Colors

    private var accentColor: Color {
        isPinned ? Color.pinnedOrange : Color.clipBlue
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.03)
    }

    // MARK: - Content Detection

    private var iconName: String {
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
            ? .system(.callout, design: .monospaced)
            : .system(.callout, weight: .medium)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Accent bar on left (matches macOS)
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor.opacity(0.65))
                .frame(width: 3)

            HStack(alignment: .top, spacing: 10) {
                // Pin indicator
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.pinnedOrange)
                        .padding(.top, 3)
                }

                // Content type icon
                Image(systemName: iconName)
                    .font(.caption)
                    .foregroundStyle(accentColor.opacity(0.8))
                    .frame(width: 16)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 4) {
                    // Preview text
                    Text(item.preview)
                        .font(itemFont)
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    // Metadata row
                    HStack(spacing: 6) {
                        // Timestamp
                        Text(item.relativeTime)
                            .font(.caption2)
                            .foregroundStyle(Color.textStone)

                        // Source app
                        if let source = item.sourceAppName {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(Color.textStone)
                            Text(source)
                                .font(.caption2)
                                .foregroundStyle(Color.textStone)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.black.opacity(0.06),
                    lineWidth: 0.5
                )
        )
        .contentShape(Rectangle())
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
            )
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
