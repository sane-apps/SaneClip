import AppKit
import KeyboardShortcuts
import LocalAuthentication
import os.log
import SaneUI
import SwiftUI

// MARK: - Clipboard Rules Section

struct ClipboardRulesSection: View {
    var licenseService: LicenseService?
    private let rules = ClipboardRulesManager.shared
    @State private var stripTrackingParams = ClipboardRulesManager.shared.stripTrackingParams
    @State private var autoTrimWhitespace = ClipboardRulesManager.shared.autoTrimWhitespace
    @State private var normalizeLineEndings = ClipboardRulesManager.shared.normalizeLineEndings
    @State private var removeDuplicateSpaces = ClipboardRulesManager.shared.removeDuplicateSpaces
    @State private var stripTrailingNewline = ClipboardRulesManager.shared.stripTrailingNewline
    @State private var lowercaseURLs = ClipboardRulesManager.shared.lowercaseURLs

    private var isPro: Bool {
        licenseService?.isPro == true
    }

    var body: some View {
        CompactSection("Clipboard Rules") {
            if !isPro {
                ProLockedSectionBanner(feature: .clipboardRules, licenseService: licenseService)
            }

            if isPro {
                CompactToggle(
                    label: "Strip URL tracking parameters",
                    isOn: Binding(
                        get: { stripTrackingParams },
                        set: { newValue in
                            stripTrackingParams = newValue
                            rules.stripTrackingParams = newValue
                        }
                    )
                )
                .help("Remove utm_*, fbclid, and other tracking params from URLs")
            } else {
                ProLockedRow(label: "Strip URL tracking parameters", feature: .clipboardRules, licenseService: licenseService)
            }

            CompactDivider()

            if isPro {
                CompactToggle(
                    label: "Auto-trim whitespace",
                    isOn: Binding(
                        get: { autoTrimWhitespace },
                        set: { newValue in
                            autoTrimWhitespace = newValue
                            rules.autoTrimWhitespace = newValue
                        }
                    )
                )
                .help("Remove leading/trailing spaces from copied text")
            } else {
                ProLockedRow(label: "Auto-trim whitespace", feature: .clipboardRules, licenseService: licenseService)
            }

            CompactDivider()

            if isPro {
                CompactToggle(
                    label: "Normalize line endings",
                    isOn: Binding(
                        get: { normalizeLineEndings },
                        set: { newValue in
                            normalizeLineEndings = newValue
                            rules.normalizeLineEndings = newValue
                        }
                    )
                )
                .help("Convert Windows (CRLF) to Unix (LF) line endings")
            } else {
                ProLockedRow(label: "Normalize line endings", feature: .clipboardRules, licenseService: licenseService)
            }

            CompactDivider()

            if isPro {
                CompactToggle(
                    label: "Remove duplicate spaces",
                    isOn: Binding(
                        get: { removeDuplicateSpaces },
                        set: { newValue in
                            removeDuplicateSpaces = newValue
                            rules.removeDuplicateSpaces = newValue
                        }
                    )
                )
                .help("Collapse multiple consecutive spaces into one")
            } else {
                ProLockedRow(label: "Remove duplicate spaces", feature: .clipboardRules, licenseService: licenseService)
            }

            CompactDivider()

            if isPro {
                CompactToggle(
                    label: "Strip trailing newline",
                    isOn: Binding(
                        get: { stripTrailingNewline },
                        set: { newValue in
                            stripTrailingNewline = newValue
                            rules.stripTrailingNewline = newValue
                        }
                    )
                )
                .help("Drop the final newline so pasting into a terminal doesn't run the command")
            } else {
                ProLockedRow(label: "Strip trailing newline", feature: .clipboardRules, licenseService: licenseService)
            }

            CompactDivider()

            if isPro {
                CompactToggle(
                    label: "Lowercase URL hosts",
                    isOn: Binding(
                        get: { lowercaseURLs },
                        set: { newValue in
                            lowercaseURLs = newValue
                            rules.lowercaseURLs = newValue
                        }
                    )
                )
                .help("Convert URL hostnames to lowercase")
            } else {
                ProLockedRow(label: "Lowercase URL hosts", feature: .clipboardRules, licenseService: licenseService)
            }
        }
        .onAppear(perform: syncRuleState)
    }

    private func syncRuleState() {
        stripTrackingParams = rules.stripTrackingParams
        autoTrimWhitespace = rules.autoTrimWhitespace
        normalizeLineEndings = rules.normalizeLineEndings
        removeDuplicateSpaces = rules.removeDuplicateSpaces
        stripTrailingNewline = rules.stripTrailingNewline
        lowercaseURLs = rules.lowercaseURLs
    }
}

// MARK: - Pro Lock Helpers

/// Inline row showing a lock badge with a "Pro" label — tapping shows the upsell.
struct ProLockedRow: View {
    let label: String
    let feature: ProFeature
    var licenseService: LicenseService?

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Button {
                if let ls = licenseService {
                    ProUpsellWindow.show(feature: feature, licenseService: ls)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Pro")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.proUnlock)
            }
            .buttonStyle(ClipActionButtonStyle())
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// Banner shown at the top of a Pro-gated section to explain the requirement.
struct ProLockedSectionBanner: View {
    let feature: ProFeature
    var licenseService: LicenseService?

    var body: some View {
        Button {
            if let ls = licenseService {
                ProUpsellWindow.show(feature: feature, licenseService: ls)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.proUnlock)
                Text("These settings require SaneClip Pro")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Pro")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.proUnlock)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .buttonStyle(ClipActionButtonStyle())
        .controlSize(.small)
    }
}
