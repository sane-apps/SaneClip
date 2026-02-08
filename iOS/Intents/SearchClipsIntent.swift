import AppIntents
import Foundation

/// Searches clipboard history for matching text
struct SearchClipsIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Clips"
    static let description: IntentDescription = "Search your SaneClip clipboard history for matching text."
    static let openAppWhenRun = false

    @Parameter(title: "Search Text")
    var query: String

    func perform() async throws -> some ReturnsValue<[String]> & ProvidesDialog {
        guard let container = WidgetDataContainer.load() else {
            return .result(value: [], dialog: "No clipboard history available.")
        }

        let allItems = container.recentItems + container.pinnedItems
        let matches = allItems.filter {
            $0.preview.localizedCaseInsensitiveContains(query)
        }

        if matches.isEmpty {
            return .result(value: [], dialog: "No clips matching \"\(query)\".")
        }

        let results = matches.map(\.preview)
        return .result(
            value: results,
            dialog: "Found \(results.count) clip\(results.count == 1 ? "" : "s") matching \"\(query)\"."
        )
    }
}
