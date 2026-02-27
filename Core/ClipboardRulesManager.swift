import Foundation

/// Clipboard content processing rules that apply automatically to copied text
@MainActor
@Observable
class ClipboardRulesManager {
    static let shared = ClipboardRulesManager()

    // MARK: - Rules (stored in UserDefaults)

    /// Strip tracking parameters from URLs (utm_*, fbclid, etc.)
    /// Default: true (existing behavior from ClipboardItem)
    var stripTrackingParams: Bool {
        get { UserDefaults.standard.bool(forKey: "rule.stripTrackingParams") }
        set { UserDefaults.standard.set(newValue, forKey: "rule.stripTrackingParams") }
    }

    /// Automatically trim leading/trailing whitespace
    var autoTrimWhitespace: Bool {
        get { UserDefaults.standard.bool(forKey: "rule.autoTrimWhitespace") }
        set { UserDefaults.standard.set(newValue, forKey: "rule.autoTrimWhitespace") }
    }

    /// Convert URL hosts to lowercase
    var lowercaseURLs: Bool {
        get { UserDefaults.standard.bool(forKey: "rule.lowercaseURLs") }
        set { UserDefaults.standard.set(newValue, forKey: "rule.lowercaseURLs") }
    }

    /// Normalize line endings to Unix-style (LF)
    var normalizeLineEndings: Bool {
        get { UserDefaults.standard.bool(forKey: "rule.normalizeLineEndings") }
        set { UserDefaults.standard.set(newValue, forKey: "rule.normalizeLineEndings") }
    }

    /// Remove duplicate spaces
    var removeDuplicateSpaces: Bool {
        get { UserDefaults.standard.bool(forKey: "rule.removeDuplicateSpaces") }
        set { UserDefaults.standard.set(newValue, forKey: "rule.removeDuplicateSpaces") }
    }

    // MARK: - Initialization

    private init() {
        // Keep first-launch defaults aligned with Basic (all Pro rules off).
        if UserDefaults.standard.object(forKey: "rule.stripTrackingParams") == nil {
            UserDefaults.standard.set(false, forKey: "rule.stripTrackingParams")
        }
    }

    // MARK: - Processing

    /// Apply all enabled rules to the input text
    func process(_ text: String) -> String {
        var result = text

        // Only apply URL tracking param stripping to actual URLs
        if stripTrackingParams && isURL(result) {
            result = ClipboardItem.stripTrackingParams(from: result)
        }

        if autoTrimWhitespace {
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if normalizeLineEndings {
            result = result.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
        }

        if removeDuplicateSpaces {
            // Replace multiple spaces with single space
            while result.contains("  ") {
                result = result.replacingOccurrences(of: "  ", with: " ")
            }
        }

        if lowercaseURLs {
            result = lowercaseURLHosts(in: result)
        }

        return result
    }

    // MARK: - Private Helpers

    private func isURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
    }

    private func lowercaseURLHosts(in text: String) -> String {
        // Only process if it looks like a URL
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return text
        }

        var result = text
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, range: range)

        // Process matches in reverse order to preserve indices
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: text),
                  let url = match.url,
                  let host = url.host else { continue }

            let lowercaseHost = host.lowercased()
            if host != lowercaseHost, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                components.host = lowercaseHost
                if let newURLString = components.string {
                    result.replaceSubrange(matchRange, with: newURLString)
                }
            }
        }

        return result
    }
}
