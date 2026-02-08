import AppIntents

/// Provides suggested shortcuts for the Shortcuts app
struct SaneClipShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetRecentClipsIntent(),
            phrases: [
                "Get recent clips from \(.applicationName)",
                "Show my clipboard in \(.applicationName)",
                "What did I copy in \(.applicationName)"
            ],
            shortTitle: "Recent Clips",
            systemImageName: "doc.on.clipboard"
        )

        AppShortcut(
            intent: SearchClipsIntent(),
            phrases: [
                "Search clips in \(.applicationName)",
                "Find text in \(.applicationName)"
            ],
            shortTitle: "Search Clips",
            systemImageName: "magnifyingglass"
        )

        AppShortcut(
            intent: CopyClipIntent(),
            phrases: [
                "Copy last clip from \(.applicationName)",
                "Paste from \(.applicationName)"
            ],
            shortTitle: "Copy Clip",
            systemImageName: "doc.on.doc"
        )
    }
}
