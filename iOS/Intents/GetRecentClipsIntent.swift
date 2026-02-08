import AppIntents
import Foundation

/// Returns the most recent clipboard items from SaneClip history
struct GetRecentClipsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Recent Clips"
    static let description: IntentDescription = "Returns your most recent clipboard items from SaneClip."
    static let openAppWhenRun = false

    @Parameter(title: "Number of Items", default: 5)
    var count: Int

    func perform() async throws -> some ReturnsValue<[String]> & ProvidesDialog {
        let items = loadRecentClips(count: min(count, 20))

        if items.isEmpty {
            return .result(
                value: [],
                dialog: "No clipboard items found. Copy something on your Mac first."
            )
        }

        return .result(
            value: items,
            dialog: "Found \(items.count) recent clip\(items.count == 1 ? "" : "s")."
        )
    }

    private func loadRecentClips(count: Int) -> [String] {
        guard let container = WidgetDataContainer.load() else { return [] }
        return Array(container.recentItems.prefix(count).map(\.preview))
    }
}
