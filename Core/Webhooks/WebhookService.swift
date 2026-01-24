import CommonCrypto
import Foundation

/// Events that can trigger webhooks
enum WebhookEvent: String, Codable, CaseIterable {
    case onCopy = "copy"
    case onPaste = "paste"
    case onDelete = "delete"
    case onClear = "clear"

    var displayName: String {
        switch self {
        case .onCopy: return "On Copy"
        case .onPaste: return "On Paste"
        case .onDelete: return "On Delete"
        case .onClear: return "On Clear"
        }
    }
}

/// Configuration for webhook delivery
struct WebhookConfig: Codable, Equatable {
    var enabled: Bool
    var endpoint: URL
    var secret: String?
    var events: [WebhookEvent]
    var includeContent: Bool
    var retryCount: Int

    init(
        enabled: Bool = false,
        endpoint: URL,
        secret: String? = nil,
        events: [WebhookEvent] = WebhookEvent.allCases,
        includeContent: Bool = false,
        retryCount: Int = 3
    ) {
        self.enabled = enabled
        self.endpoint = endpoint
        self.secret = secret
        self.events = events
        self.includeContent = includeContent
        self.retryCount = retryCount
    }
}

/// Webhook delivery result
struct WebhookDeliveryResult {
    let success: Bool
    let statusCode: Int?
    let error: Error?
    let timestamp: Date
}

/// Service for sending webhook notifications on clipboard events
actor WebhookService {

    /// Shared singleton instance
    static let shared = WebhookService()

    /// Current webhook configuration
    private var config: WebhookConfig?

    /// Delivery history for debugging
    private var deliveryHistory: [WebhookDeliveryResult] = []
    private let maxHistorySize = 50

    private init() {
        // Load config synchronously at init
        self.config = Self.loadConfigFromDisk()
    }

    /// Loads config from disk (nonisolated for init)
    private nonisolated static func loadConfigFromDisk() -> WebhookConfig? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configURL = appSupport
            .appendingPathComponent("SaneClip")
            .appendingPathComponent("webhook_config.json")

        do {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(WebhookConfig.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Configuration

    /// Gets the current webhook configuration
    func getConfig() -> WebhookConfig? {
        config
    }

    /// Updates the webhook configuration
    func updateConfig(_ newConfig: WebhookConfig?) {
        config = newConfig
        saveConfig()
    }

    /// Tests the webhook configuration by sending a test payload
    func testWebhook() async -> WebhookDeliveryResult {
        guard let config, config.enabled else {
            return WebhookDeliveryResult(
                success: false,
                statusCode: nil,
                error: WebhookError.notConfigured,
                timestamp: Date()
            )
        }

        let payload: [String: Any] = [
            "event": "test",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "message": "This is a test webhook from SaneClip"
        ]

        return await sendWebhook(payload: payload, retries: 1)
    }

    // MARK: - Event Triggers

    /// Triggers a webhook for a clipboard copy event
    func triggerCopy(item: ClipboardItem) async {
        await trigger(event: .onCopy, item: item)
    }

    /// Triggers a webhook for a clipboard paste event
    func triggerPaste(item: ClipboardItem) async {
        await trigger(event: .onPaste, item: item)
    }

    /// Triggers a webhook for a clipboard item deletion
    func triggerDelete(itemId: UUID) async {
        guard let config, config.enabled, config.events.contains(.onDelete) else { return }

        let payload: [String: Any] = [
            "event": WebhookEvent.onDelete.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "itemId": itemId.uuidString
        ]

        _ = await sendWebhook(payload: payload, retries: config.retryCount)
    }

    /// Triggers a webhook for history clear
    func triggerClear(itemCount: Int) async {
        guard let config, config.enabled, config.events.contains(.onClear) else { return }

        let payload: [String: Any] = [
            "event": WebhookEvent.onClear.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "itemsCleared": itemCount
        ]

        _ = await sendWebhook(payload: payload, retries: config.retryCount)
    }

    // MARK: - Private Methods

    private func trigger(event: WebhookEvent, item: ClipboardItem) async {
        guard let config, config.enabled, config.events.contains(event) else { return }

        var payload: [String: Any] = [
            "event": event.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "itemId": item.id.uuidString,
            "contentType": item.contentTypeString,
            "sourceApp": item.sourceAppName ?? "Unknown",
            "sourceAppBundleId": item.sourceAppBundleID ?? ""
        ]

        // Only include content if configured and it's text
        if config.includeContent, case .text(let text) = item.content {
            // Truncate long content
            payload["content"] = String(text.prefix(1000))
            payload["contentTruncated"] = text.count > 1000
        }

        _ = await sendWebhook(payload: payload, retries: config.retryCount)
    }

    private func sendWebhook(payload: [String: Any], retries: Int) async -> WebhookDeliveryResult {
        guard let config else {
            return WebhookDeliveryResult(
                success: false,
                statusCode: nil,
                error: WebhookError.notConfigured,
                timestamp: Date()
            )
        }

        var lastError: Error?
        var lastStatusCode: Int?

        for attempt in 0..<retries {
            do {
                var request = URLRequest(url: config.endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("SaneClip/1.0", forHTTPHeaderField: "User-Agent")

                // Add HMAC signature if secret is configured
                let jsonData = try JSONSerialization.data(withJSONObject: payload)
                request.httpBody = jsonData

                if let secret = config.secret, !secret.isEmpty {
                    let signature = computeHMAC(data: jsonData, secret: secret)
                    request.setValue("sha256=\(signature)", forHTTPHeaderField: "X-SaneClip-Signature")
                }

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    lastStatusCode = httpResponse.statusCode

                    if (200...299).contains(httpResponse.statusCode) {
                        let result = WebhookDeliveryResult(
                            success: true,
                            statusCode: httpResponse.statusCode,
                            error: nil,
                            timestamp: Date()
                        )
                        recordDelivery(result)
                        return result
                    }
                }

                // Retry on server errors
                if attempt < retries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                }

            } catch {
                lastError = error

                // Retry on network errors
                if attempt < retries - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                }
            }
        }

        let result = WebhookDeliveryResult(
            success: false,
            statusCode: lastStatusCode,
            error: lastError ?? WebhookError.deliveryFailed,
            timestamp: Date()
        )
        recordDelivery(result)
        return result
    }

    private func computeHMAC(data: Data, secret: String) -> String {
        // HMAC-SHA256 implementation using CommonCrypto
        let secretData = Data(secret.utf8)
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        secretData.withUnsafeBytes { secretBytes in
            data.withUnsafeBytes { dataBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    secretBytes.baseAddress,
                    secretData.count,
                    dataBytes.baseAddress,
                    data.count,
                    &hmac
                )
            }
        }

        return hmac.map { String(format: "%02x", $0) }.joined()
    }

    private func recordDelivery(_ result: WebhookDeliveryResult) {
        deliveryHistory.append(result)
        if deliveryHistory.count > maxHistorySize {
            deliveryHistory.removeFirst()
        }
    }

    /// Gets recent delivery history
    func getDeliveryHistory() -> [WebhookDeliveryResult] {
        deliveryHistory
    }

    // MARK: - Persistence

    private var configFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("SaneClip")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("webhook_config.json")
    }

    private func saveConfig() {
        do {
            if let config {
                let data = try JSONEncoder().encode(config)
                try data.write(to: configFileURL)
            } else {
                try? FileManager.default.removeItem(at: configFileURL)
            }
        } catch {
            print("Failed to save webhook config: \(error)")
        }
    }

}

// MARK: - Errors

enum WebhookError: Error, LocalizedError {
    case notConfigured
    case deliveryFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Webhook is not configured"
        case .deliveryFailed:
            return "Failed to deliver webhook after retries"
        case .invalidResponse:
            return "Invalid response from webhook endpoint"
        }
    }
}

// MARK: - ClipboardItem Extension

extension ClipboardItem {
    var contentTypeString: String {
        switch content {
        case .text: return "text"
        case .image: return "image"
        }
    }
}
