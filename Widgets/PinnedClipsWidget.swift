import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct PinnedClipsProvider: TimelineProvider {
    func placeholder(in context: Context) -> PinnedClipsEntry {
        PinnedClipsEntry(date: .now, items: Self.sampleItems)
    }

    func getSnapshot(in context: Context, completion: @escaping (PinnedClipsEntry) -> Void) {
        let items = loadPinnedItems(limit: itemCount(for: context.family))
        completion(PinnedClipsEntry(date: .now, items: items))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PinnedClipsEntry>) -> Void) {
        let items = loadPinnedItems(limit: itemCount(for: context.family))
        let entry = PinnedClipsEntry(date: .now, items: items)

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

    private func loadPinnedItems(limit: Int) -> [WidgetClipboardItem] {
        guard let container = WidgetDataContainer.load() else {
            return Self.sampleItems
        }
        return Array(container.pinnedItems.prefix(limit))
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
            preview: "https://mywebsite.com",
            timestamp: Date().addingTimeInterval(-172800),
            isPinned: true,
            sourceAppName: "Safari",
            contentType: .url
        ),
        WidgetClipboardItem(
            id: UUID(),
            preview: "const API_KEY = \"...\"",
            timestamp: Date().addingTimeInterval(-259200),
            isPinned: true,
            sourceAppName: "VS Code",
            contentType: .code
        )
    ]
}

// MARK: - Timeline Entry

struct PinnedClipsEntry: TimelineEntry {
    let date: Date
    let items: [WidgetClipboardItem]
}

// MARK: - Widget View

struct PinnedClipsWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: PinnedClipsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Pinned Clips")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.bottom, 2)

            if entry.items.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "pin.slash")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No pinned clips")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(entry.items) { item in
                    PinnedItemRow(item: item, compact: family == .systemSmall)
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Pinned Item Row

struct PinnedItemRow: View {
    let item: WidgetClipboardItem
    let compact: Bool

    var body: some View {
        HStack(spacing: 6) {
            // Pin indicator
            Image(systemName: "pin.fill")
                .font(.system(size: 8))
                .foregroundStyle(.orange)
                .frame(width: 12)

            // Preview text
            Text(item.truncatedPreview(maxLength: compact ? 25 : 40))
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer(minLength: 4)

            // Source app (if space)
            if !compact, let source = item.sourceAppName {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Widget Configuration

struct PinnedClipsWidget: Widget {
    let kind: String = "PinnedClipsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PinnedClipsProvider()) { entry in
            PinnedClipsWidgetView(entry: entry)
        }
        .configurationDisplayName("Pinned Clips")
        .description("Quick access to your pinned clipboard items.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    PinnedClipsWidget()
} timeline: {
    PinnedClipsEntry(date: .now, items: PinnedClipsProvider.sampleItems)
}

#Preview(as: .systemMedium) {
    PinnedClipsWidget()
} timeline: {
    PinnedClipsEntry(date: .now, items: PinnedClipsProvider.sampleItems)
}
