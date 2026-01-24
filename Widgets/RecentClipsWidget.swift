import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct RecentClipsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentClipsEntry {
        RecentClipsEntry(date: .now, items: Self.sampleItems)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentClipsEntry) -> Void) {
        let items = loadRecentItems(limit: itemCount(for: context.family))
        completion(RecentClipsEntry(date: .now, items: items))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentClipsEntry>) -> Void) {
        let items = loadRecentItems(limit: itemCount(for: context.family))
        let entry = RecentClipsEntry(date: .now, items: items)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func itemCount(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 5
        case .systemLarge: return 8
        default: return 3
        }
    }

    private func loadRecentItems(limit: Int) -> [WidgetClipboardItem] {
        guard let container = WidgetDataContainer.load() else {
            return Self.sampleItems
        }
        return Array(container.recentItems.prefix(limit))
    }

    static let sampleItems: [WidgetClipboardItem] = [
        WidgetClipboardItem(
            id: UUID(),
            preview: "Sample clipboard text",
            timestamp: Date().addingTimeInterval(-300),
            isPinned: false,
            sourceAppName: "Safari",
            contentType: .text
        ),
        WidgetClipboardItem(
            id: UUID(),
            preview: "https://example.com",
            timestamp: Date().addingTimeInterval(-600),
            isPinned: false,
            sourceAppName: "Chrome",
            contentType: .url
        ),
        WidgetClipboardItem(
            id: UUID(),
            preview: "func hello() { print(\"Hi\") }",
            timestamp: Date().addingTimeInterval(-900),
            isPinned: false,
            sourceAppName: "Xcode",
            contentType: .code
        )
    ]
}

// MARK: - Timeline Entry

struct RecentClipsEntry: TimelineEntry {
    let date: Date
    let items: [WidgetClipboardItem]
}

// MARK: - Widget View

struct RecentClipsWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: RecentClipsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Recent Clips")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.bottom, 2)

            if entry.items.isEmpty {
                Spacer()
                Text("No clips yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(entry.items) { item in
                    ClipItemRow(item: item, compact: family == .systemSmall)
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Clip Item Row

struct ClipItemRow: View {
    let item: WidgetClipboardItem
    let compact: Bool

    var body: some View {
        HStack(spacing: 6) {
            // Content type icon
            Image(systemName: iconName)
                .font(.caption2)
                .foregroundStyle(iconColor)
                .frame(width: 12)

            // Preview text
            Text(item.truncatedPreview(maxLength: compact ? 25 : 40))
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer(minLength: 4)

            // Timestamp
            if !compact {
                Text(item.relativeTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        switch item.contentType {
        case .text: return "doc.text"
        case .url: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        }
    }

    private var iconColor: Color {
        switch item.contentType {
        case .text: return .primary
        case .url: return .blue
        case .code: return .orange
        case .image: return .purple
        }
    }
}

// MARK: - Widget Configuration

struct RecentClipsWidget: Widget {
    let kind: String = "RecentClipsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentClipsProvider()) { entry in
            RecentClipsWidgetView(entry: entry)
        }
        .configurationDisplayName("Recent Clips")
        .description("Quick access to your recent clipboard items.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    RecentClipsWidget()
} timeline: {
    RecentClipsEntry(date: .now, items: RecentClipsProvider.sampleItems)
}

#Preview(as: .systemMedium) {
    RecentClipsWidget()
} timeline: {
    RecentClipsEntry(date: .now, items: RecentClipsProvider.sampleItems)
}
