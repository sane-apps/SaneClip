import AppKit
import KeyboardShortcuts
import LocalAuthentication
import os.log
import SaneUI
import SwiftUI

// MARK: - Clipboard Rules Section

struct ClipboardRulesSection: View {
    var licenseService: LicenseService?
    @State private var rules = ClipboardRulesManager.shared

    private var isPro: Bool { licenseService?.isPro == true }

    var body: some View {
        CompactSection("Clipboard Rules") {
            if !isPro {
                ProLockedSectionBanner(feature: .clipboardRules, licenseService: licenseService)
            }

            if isPro {
                CompactToggle(
                    label: "Strip URL tracking parameters",
                    isOn: Binding(
                        get: { rules.stripTrackingParams },
                        set: { rules.stripTrackingParams = $0 }
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
                        get: { rules.autoTrimWhitespace },
                        set: { rules.autoTrimWhitespace = $0 }
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
                        get: { rules.normalizeLineEndings },
                        set: { rules.normalizeLineEndings = $0 }
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
                        get: { rules.removeDuplicateSpaces },
                        set: { rules.removeDuplicateSpaces = $0 }
                    )
                )
                .help("Collapse multiple consecutive spaces into one")
            } else {
                ProLockedRow(label: "Remove duplicate spaces", feature: .clipboardRules, licenseService: licenseService)
            }

            CompactDivider()

            if isPro {
                CompactToggle(
                    label: "Lowercase URL hosts",
                    isOn: Binding(
                        get: { rules.lowercaseURLs },
                        set: { rules.lowercaseURLs = $0 }
                    )
                )
                .help("Convert URL hostnames to lowercase")
            } else {
                ProLockedRow(label: "Lowercase URL hosts", feature: .clipboardRules, licenseService: licenseService)
            }
        }
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
                .foregroundStyle(.teal)
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
                    .foregroundStyle(.teal)
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
                .foregroundStyle(.teal)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .buttonStyle(ClipActionButtonStyle())
        .controlSize(.small)
    }
}
