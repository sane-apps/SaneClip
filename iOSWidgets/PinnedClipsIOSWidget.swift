import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct PinnedClipsIOSProvider: TimelineProvider {
    func placeholder(in context: Context) -> PinnedClipsIOSEntry {
        PinnedClipsIOSEntry(date: .now, items: Self.sampleItems)
    }

    func getSnapshot(in context: Context, completion: @escaping (PinnedClipsIOSEntry) -> Void) {
        let items = visibleItems(limit: itemCount(for: context.family), isPreview: context.isPreview)
        completion(PinnedClipsIOSEntry(date: .now, items: items))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PinnedClipsIOSEntry>) -> Void) {
        let items = visibleItems(limit: itemCount(for: context.family), isPreview: false)
        let entry = PinnedClipsIOSEntry(date: .now, items: items)

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

    private func visibleItems(limit: Int, isPreview: Bool) -> [WidgetClipboardItem] {
        WidgetTimelineSelection.items(
            stored: WidgetDataContainer.load()?.pinnedItems,
            limit: limit,
            isPreview: isPreview,
            samples: Self.sampleItems
        )
    }

    static let sampleItems: [WidgetClipboardItem] = [
        WidgetClipboardItem(
            id: UUID(),
            preview: "Email signature",
            timestamp: Date().addingTimeInterval(-86400),
            isPinned: true,
            sourceAppName: "Notes",
            contentType: .text
        ),
        WidgetClipboardItem(
            id: UUID(),
            preview: "https://mysite.com",
            timestamp: Date().addingTimeInterval(-172800),
            isPinned: true,
            sourceAppName: "Safari",
            contentType: .url
        ),
        WidgetClipboardItem(
            id: UUID(),
            preview: "Weekly standup notes",
            timestamp: Date().addingTimeInterval(-259200),
            isPinned: true,
            sourceAppName: "Terminal",
            contentType: .code
        )
    ]
}

// MARK: - Timeline Entry

struct PinnedClipsIOSEntry: TimelineEntry {
    let date: Date
    let items: [WidgetClipboardItem]
}

// MARK: - Widget View

struct PinnedClipsIOSWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: PinnedClipsIOSEntry

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
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("Pinned")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.bottom, 2)

            if entry.items.isEmpty {
                Spacer()
                VStack(spacing: 2) {
                    Image(systemName: "pin.slash")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No pins")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.items) { item in
                    IOSPinnedItemRow(item: item, compact: family == .systemSmall)
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entry.items.prefix(2)) { item in
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                    Text(item.truncatedPreview(maxLength: 25))
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
    }

    private var accessoryCircularView: some View {
        Image(systemName: "pin.fill")
            .font(.title2)
            .foregroundStyle(.orange)
    }
}

// MARK: - iOS Pinned Item Row

struct IOSPinnedItemRow: View {
    let item: WidgetClipboardItem
    let compact: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "pin.fill")
                .font(.system(size: 8))
                .foregroundStyle(.orange)
                .frame(width: 12)

            Text(item.truncatedPreview(maxLength: compact ? 20 : 35))
                .font(.caption)
                .lineLimit(1)

            Spacer(minLength: 4)

            if !compact, let source = item.sourceAppName {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Widget Configuration

struct PinnedClipsIOSWidget: Widget {
    let kind: String = "PinnedClipsIOSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PinnedClipsIOSProvider()) { entry in
            PinnedClipsIOSWidgetView(entry: entry)
        }
        .configurationDisplayName("Pinned Clips")
        .description("Quick access to your pinned clipboard items.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular
        ])
    }
}

#Preview(as: .systemSmall) {
    PinnedClipsIOSWidget()
} timeline: {
    PinnedClipsIOSEntry(date: .now, items: PinnedClipsIOSProvider.sampleItems)
}
