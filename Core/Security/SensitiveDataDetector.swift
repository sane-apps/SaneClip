import Foundation

/// Types of sensitive data that can be detected in clipboard content
enum SensitiveDataType: String, CaseIterable, Codable {
    case creditCard = "Credit Card"
    case ssn = "Social Security Number"
    case apiKey = "API Key"
    case password = "Password"
    case privateKey = "Private Key"
    case email = "Email Address"

    var icon: String {
        switch self {
        case .creditCard: return "creditcard"
        case .ssn: return "person.text.rectangle"
        case .apiKey: return "key"
        case .password: return "lock"
        case .privateKey: return "lock.doc"
        case .email: return "envelope"
        }
    }

    var description: String {
        switch self {
        case .creditCard: return "Credit card numbers (13-19 digits with Luhn validation)"
        case .ssn: return "Social Security Numbers (XXX-XX-XXXX format)"
        case .apiKey: return "API keys from common services (OpenAI, AWS, GitHub, Slack)"
        case .password: return "Text containing password-like patterns"
        case .privateKey: return "SSH or PGP private keys"
        case .email: return "Email addresses"
        }
    }
}

/// Service that detects sensitive data patterns in text content
final class SensitiveDataDetector: Sendable {

    /// Shared singleton instance
    static let shared = SensitiveDataDetector()

    /// Nonisolated shared instance for use from any context
    nonisolated static var detector: SensitiveDataDetector { shared }

    private init() {}

    /// Detects all types of sensitive data present in the given text
    /// - Parameter text: The text content to analyze
    /// - Returns: Array of detected sensitive data types
    func detect(in text: String) -> [SensitiveDataType] {
        var detected: [SensitiveDataType] = []

        if containsCreditCard(text) { detected.append(.creditCard) }
        if containsSSN(text) { detected.append(.ssn) }
        if containsAPIKey(text) { detected.append(.apiKey) }
        if containsPassword(text) { detected.append(.password) }
        if containsPrivateKey(text) { detected.append(.privateKey) }
        if containsEmail(text) { detected.append(.email) }

        return detected
    }

    /// Checks if text contains any sensitive data
    /// - Parameter text: The text content to analyze
    /// - Returns: True if any sensitive data is detected
    func containsSensitiveData(in text: String) -> Bool {
        !detect(in: text).isEmpty
    }

    // MARK: - Credit Card Detection

    /// Detects credit card numbers using pattern matching and Luhn validation
    private func containsCreditCard(_ text: String) -> Bool {
        // Pattern matches 13-19 digits, optionally separated by spaces or dashes
        let pattern = #"\b(?:\d[ -]*?){13,19}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return false
        }

        // Extract just the digits
        let digits = String(text[range].filter { $0.isNumber })

        // Validate with Luhn algorithm
        return luhnCheck(digits)
    }

    /// Validates a number string using the Luhn algorithm
    /// https://en.wikipedia.org/wiki/Luhn_algorithm
    private func luhnCheck(_ digits: String) -> Bool {
        guard digits.count >= 13, digits.count <= 19 else { return false }

        var sum = 0
        for (index, char) in digits.reversed().enumerated() {
            guard let digit = Int(String(char)) else { return false }

            if index % 2 == 1 {
                // Double every second digit from the right
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }

        return sum % 10 == 0
    }

    // MARK: - SSN Detection

    /// Detects Social Security Numbers in XXX-XX-XXXX format
    private func containsSSN(_ text: String) -> Bool {
        // Standard SSN format with dashes
        let dashPattern = #"\b\d{3}-\d{2}-\d{4}\b"#
        // Also check for SSN without dashes (9 consecutive digits)
        let plainPattern = #"\b\d{9}\b"#

        if text.range(of: dashPattern, options: .regularExpression) != nil {
            return true
        }

        // For plain 9-digit patterns, look for context clues
        if let regex = try? NSRegularExpression(pattern: plainPattern),
           regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            // Only flag if there's context suggesting SSN
            let ssnContext = ["ssn", "social security", "social sec", "ss#", "ss #"]
            let lowercased = text.lowercased()
            return ssnContext.contains { lowercased.contains($0) }
        }

        return false
    }

    // MARK: - API Key Detection

    /// Detects common API key patterns from popular services
    private func containsAPIKey(_ text: String) -> Bool {
        let patterns = [
            // OpenAI API keys
            #"sk-[a-zA-Z0-9]{32,}"#,
            #"sk-proj-[a-zA-Z0-9_-]{80,}"#,

            // AWS Access Key ID
            #"AKIA[0-9A-Z]{16}"#,

            // AWS Secret Access Key (40 chars after common prefixes)
            #"(?:aws_secret_access_key|secret_key|secretkey)\s*[=:]\s*[A-Za-z0-9/+=]{40}"#,

            // GitHub tokens
            #"ghp_[a-zA-Z0-9]{36}"#,      // Personal access tokens
            #"gho_[a-zA-Z0-9]{36}"#,      // OAuth tokens
            #"ghu_[a-zA-Z0-9]{36}"#,      // User-to-server tokens
            #"ghs_[a-zA-Z0-9]{36}"#,      // Server-to-server tokens
            #"ghr_[a-zA-Z0-9]{36}"#,      // Refresh tokens

            // Slack tokens
            #"xox[baprs]-[a-zA-Z0-9-]+"#,

            // Stripe keys
            #"sk_live_[a-zA-Z0-9]{24,}"#,
            #"sk_test_[a-zA-Z0-9]{24,}"#,
            #"pk_live_[a-zA-Z0-9]{24,}"#,
            #"pk_test_[a-zA-Z0-9]{24,}"#,

            // Google API keys
            #"AIza[0-9A-Za-z\-_]{35}"#,

            // Twilio
            #"SK[a-f0-9]{32}"#,

            // SendGrid
            #"SG\.[a-zA-Z0-9_-]{22}\.[a-zA-Z0-9_-]{43}"#,

            // Generic patterns that look like API keys
            #"(?:api[_-]?key|apikey|api_secret|apisecret)\s*[=:]\s*['\"]?[a-zA-Z0-9_-]{20,}['\"]?"#
        ]

        for pattern in patterns where text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }

        return false
    }

    // MARK: - Password Detection

    /// Detects password-like patterns with context clues
    private func containsPassword(_ text: String) -> Bool {
        // Look for password assignments or displays
        let patterns = [
            #"(?:password|passwd|pwd|pass)\s*[=:]\s*[^\s]{4,}"#,
            #"(?:password|passwd|pwd|pass)\s*:\s*[^\s]{4,}"#,
            #"(?:password|passwd|pwd)[\s]*is[\s]+[^\s]{4,}"#
        ]

        for pattern in patterns where text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }

        return false
    }

    // MARK: - Private Key Detection

    /// Detects SSH and PGP private key blocks
    private func containsPrivateKey(_ text: String) -> Bool {
        let markers = [
            "-----BEGIN RSA PRIVATE KEY-----",
            "-----BEGIN DSA PRIVATE KEY-----",
            "-----BEGIN EC PRIVATE KEY-----",
            "-----BEGIN OPENSSH PRIVATE KEY-----",
            "-----BEGIN PGP PRIVATE KEY BLOCK-----",
            "-----BEGIN PRIVATE KEY-----",
            "-----BEGIN ENCRYPTED PRIVATE KEY-----"
        ]

        return markers.contains { text.contains($0) }
    }

    // MARK: - Email Detection

    /// Detects email addresses
    private func containsEmail(_ text: String) -> Bool {
        // RFC 5322 simplified pattern
        let pattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}
