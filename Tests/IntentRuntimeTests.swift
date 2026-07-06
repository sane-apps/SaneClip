import Foundation
@testable import SaneClip
import Testing

struct IntentRuntimeTests {
    private func projectRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("App Shortcuts provider is release-only while intents stay testable")
    func appShortcutsProviderIsReleaseOnly() throws {
        let source = try String(
            contentsOf: projectRootURL().appendingPathComponent("Core/Intents/SaneClipIntents.swift"),
            encoding: .utf8
        )
        #expect(source.contains("#if !DEBUG"))
        #expect(source.contains("struct SaneClipShortcuts: AppShortcutsProvider"))
        #expect(source.contains("AppShortcut("))
        #expect(source.contains("GetClipboardHistoryIntent()"))
        #expect(source.contains("ClearHistoryIntent()"))
        #expect(source.contains("ListSnippetsIntent()"))
    }
}
