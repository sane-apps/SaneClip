import Foundation
@testable import SaneClip
import Testing

/// Color-enforcement tests for the Settings UI.
///
/// The 2.3.14 color pass moved Settings off raw system hues that collided with
/// the one-meaning-per-hue history palette: raw `.teal` (Pro badges/banner)
/// collided with `mergeTeal` (= merge), raw `.orange` (a placeholder chip)
/// collided with `pinnedOrange` (= pinned), and the two permission/existence
/// status indicators used raw `.green` instead of the `semanticSuccess` token.
///
/// `HistoryColorAndStackTests.historyColorSemioticsAreEnforced` only guards the
/// five History/UI files, so it can't catch a Settings regression. This test
/// scans every `UI/Settings/*.swift` file and fails on a raw functional SwiftUI
/// hue applied as a foreground/background/fill/tint/stroke color, so the
/// collision (and the split Pro signalling) can't come back.
struct SettingsColorTests {
    private func projectRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Every raw functional SwiftUI hue we never want applied as a functional
    /// color in Settings. `.white`/`.black`/`.gray`/`.primary`/`.secondary` are
    /// neutral and stay allowed; these carry meaning and must come from a token.
    private static let forbiddenHues = [
        "teal", "orange", "green", "yellow", "pink",
        "purple", "red", "mint", "cyan", "indigo", "brown"
    ]

    /// SwiftUI modifiers that paint a color onto a view. A forbidden hue inside
    /// any of these is a functional-color regression.
    private static let colorModifiers = [
        "foregroundStyle", "foregroundColor", "background",
        "fill", "tint", "stroke", "backgroundStyle"
    ]

    private func settingsSwiftFiles() throws -> [URL] {
        let dir = projectRootURL()
            .appendingPathComponent("UI")
            .appendingPathComponent("Settings")
        let contents = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        )
        return contents
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    @Test("Settings UI applies no raw functional SwiftUI hue (must use a BrandColors token)")
    func settingsUsesNoRawFunctionalHues() throws {
        let files = try settingsSwiftFiles()
        // Guard against a silently-empty glob (moved/renamed dir) reporting a
        // false green.
        #expect(!files.isEmpty, "No UI/Settings/*.swift files found — glob is stale")

        // Build the forbidden token forms:
        //   - a leading-dot form used inside a modifier: `.green`, `? .green`
        //   - the fully-qualified form: `Color.green`
        // The dot form only counts when it's a color modifier argument, so a
        // property named `.greenChannel` or an unrelated `.red` on some model
        // type won't false-positive. We do that by requiring the hue to sit
        // inside one of the color modifiers on the same line.
        let modifierPattern = Self.colorModifiers.joined(separator: "|")

        for url in files {
            let relative = "UI/Settings/\(url.lastPathComponent)"
            let source = try String(contentsOf: url, encoding: .utf8)

            for hue in Self.forbiddenHues {
                // 1) Fully-qualified `Color.<hue>` anywhere is always wrong.
                #expect(
                    !source.contains("Color.\(hue)"),
                    "\(relative) uses raw Color.\(hue) — use a BrandColors token (e.g. semanticSuccess / proUnlock / mergeTeal)"
                )

                // 2) A bare `.<hue>` used as an argument to a color modifier.
                // We scan line-by-line: a line that both invokes a color
                // modifier and contains the leading-dot hue is a violation.
                for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
                    let text = String(line)
                    guard text.contains(".\(hue)") else { continue }
                    let mentionsModifier = Self.colorModifiers.contains { text.contains("\($0)(") }
                    if mentionsModifier {
                        #expect(
                            false,
                            "\(relative) applies raw .\(hue) via a color modifier (\(modifierPattern)) — use a BrandColors token"
                        )
                    }
                }
            }
        }
    }

    @Test("Settings permission/existence status greens route through the semanticSuccess token")
    func settingsStatusIndicatorsUseSemanticSuccess() throws {
        // The two status indicators (screen-recording granted, excluded-app
        // exists) are the legitimate place a green belongs — but it must be the
        // named status token, not raw `.green`, so it stays consistent with the
        // rest of the app and can be re-themed in one place.
        let general = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/Settings/GeneralSettingsView.swift"),
            encoding: .utf8
        )
        let excluded = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/Settings/ExcludedAppsSettingsView.swift"),
            encoding: .utf8
        )
        #expect(general.contains("Color.semanticSuccess"))
        #expect(excluded.contains("Color.semanticSuccess"))
    }

    @Test("Pro badges/banner in Settings stay on the single yellow proUnlock token")
    func settingsProSignallingIsUnified() throws {
        // The Pro-lock badge, the "requires Pro" banner, and the neutralized
        // placeholder chip were unified in the 2.3.14 pass; assert the Pro
        // signal is the yellow token everywhere in Settings and that no raw
        // teal (= merge) sneaks back in as the Pro color.
        for name in ["SnippetsSettingsView.swift", "ClipboardRulesSection.swift", "GeneralSettingsView.swift"] {
            let source = try String(
                contentsOf: projectRootURL().appendingPathComponent("UI/Settings/\(name)"),
                encoding: .utf8
            )
            #expect(
                !source.contains("Color.teal") && !source.contains("(.teal)"),
                "\(name) reintroduced raw teal for Pro — Pro must read as Color.proUnlock everywhere"
            )
        }
    }
}
