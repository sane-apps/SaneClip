import AppIntents
import Foundation
import UIKit

/// Copies a specific clipboard item to the system clipboard
struct CopyClipIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Clip"
    static let description: IntentDescription = "Copy a specific item from your SaneClip history to the clipboard."
    static let openAppWhenRun = false

    @Parameter(title: "Item Number", description: "Which item to copy (1 = most recent)", default: 1)
    var itemNumber: Int

    func perform() async throws -> some ProvidesDialog {
        guard let container = WidgetDataContainer.load() else {
            return .result(dialog: "No clipboard history available.")
        }

        let index = itemNumber - 1
        guard index >= 0, index < container.recentItems.count else {
            return .result(dialog: "Item \(itemNumber) not found. You have \(container.recentItems.count) items.")
        }

        let item = container.recentItems[index]
        await MainActor.run {
            UIPasteboard.general.string = item.preview
        }

        let preview = item.truncatedPreview(maxLength: 40)
        return .result(dialog: "Copied: \(preview)")
    }
}
