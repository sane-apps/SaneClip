import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct RecentClipsIOSProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentClipsIOSEntry {
        RecentClipsIOSEntry(date: .now, items: Self.sampleItems)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentClipsIOSEntry) -> Void) {
        let items = loadRecentItems(limit: itemCount(for: context.family))
        completion(RecentClipsIOSEntry(date: .now, items: items))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentClipsIOSEntry>) -> Void) {
        let items = loadRecentItems(limit: itemCount(for: context.family))
        let entry = RecentClipsIOSEntry(date: .now, items: items)

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func itemCount(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 4
        case .systemLarge: return 8
        case .accessoryRectangular: return 2
        case .accessoryCircular: return 1
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
            preview: "func hello() {}",
            timestamp: Date().addingTimeInterval(-900),
            isPinned: false,
            sourceAppName: "Xcode",
            contentType: .code
        )
    ]
}

// MARK: - Timeline Entry

struct RecentClipsIOSEntry: TimelineEntry {
    let date: Date
    let items: [WidgetClipboardItem]
}

// MARK: - Widget View

struct RecentClipsIOSWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: RecentClipsIOSEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            accessoryRectangularView
        case .accessoryCircular:
            accessoryCircularView
        default:
            standardView
        }
    }

    private var standardView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Recent")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.bottom, 2)

            if entry.items.isEmpty {
                Spacer()
                Text("No clips")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.items) { item in
                    IOSClipItemRow(item: item, compact: family == .systemSmall)
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entry.items.prefix(2)) { item in
                Text(item.truncatedPreview(maxLength: 30))
                    .font(.caption)
                    .lineLimit(1)
            }
        }
    }

    private var accessoryCircularView: some View {
        Image(systemName: "doc.on.clipboard.fill")
            .font(.title2)
    }
}

// MARK: - iOS Clip Item Row

struct IOSClipItemRow: View {
    let item: WidgetClipboardItem
    let compact: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption2)
                .foregroundStyle(iconColor)
                .frame(width: 12)

            Text(item.truncatedPreview(maxLength: compact ? 20 : 35))
                .font(.caption)
                .lineLimit(1)

            Spacer(minLength: 4)

            if !compact {
                Text(item.relativeTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 1)
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
        case .image: return .teal
        }
    }
}

// MARK: - Widget Configuration

struct RecentClipsIOSWidget: Widget {
    let kind: String = "RecentClipsIOSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentClipsIOSProvider()) { entry in
            RecentClipsIOSWidgetView(entry: entry)
        }
        .configurationDisplayName("Recent Clips")
        .description("Quick access to your recent clipboard items.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular
        ])
    }
}

#Preview(as: .systemSmall) {
    RecentClipsIOSWidget()
} timeline: {
    RecentClipsIOSEntry(date: .now, items: RecentClipsIOSProvider.sampleItems)
}
