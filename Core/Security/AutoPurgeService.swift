import Foundation

/// Configuration for an auto-purge rule
struct PurgeRule: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var sensitiveTypes: [SensitiveDataType]
    var purgeAfterMinutes: Int
    var enabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        sensitiveTypes: [SensitiveDataType],
        purgeAfterMinutes: Int,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.sensitiveTypes = sensitiveTypes
        self.purgeAfterMinutes = purgeAfterMinutes
        self.enabled = enabled
    }

    /// Default rules for common sensitive data scenarios
    static var defaults: [PurgeRule] {
        [
            PurgeRule(
                name: "Credit Cards",
                sensitiveTypes: [.creditCard],
                purgeAfterMinutes: 5,
                enabled: true
            ),
            PurgeRule(
                name: "API Keys & Passwords",
                sensitiveTypes: [.apiKey, .password, .privateKey],
                purgeAfterMinutes: 15,
                enabled: true
            ),
            PurgeRule(
                name: "Social Security Numbers",
                sensitiveTypes: [.ssn],
                purgeAfterMinutes: 1,
                enabled: true
            )
        ]
    }
}

/// Service that automatically purges sensitive clipboard items based on configurable rules
@MainActor
@Observable
final class AutoPurgeService {

    /// Shared singleton instance
    static let shared = AutoPurgeService()

    /// Active purge rules
    var rules: [PurgeRule] = [] {
        didSet { saveRules() }
    }

    /// Whether auto-purge is globally enabled
    var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "autoPurgeEnabled")
            if isEnabled {
                start()
            } else {
                stop()
            }
        }
    }

    /// Statistics for monitoring
    private(set) var totalPurged: Int = 0
    private(set) var lastPurgeDate: Date?

    private var timer: Timer?
    private let detector = SensitiveDataDetector.shared
    private let checkInterval: TimeInterval = 60 // Check every minute

    private init() {
        loadRules()
        isEnabled = UserDefaults.standard.bool(forKey: "autoPurgeEnabled")
        if rules.isEmpty {
            rules = PurgeRule.defaults
        }
    }

    // MARK: - Lifecycle

    /// Starts the auto-purge timer
    func start() {
        guard isEnabled else { return }

        stop() // Ensure no duplicate timers

        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performCleanup()
            }
        }

        // Run immediately on start
        performCleanup()
    }

    /// Stops the auto-purge timer
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Cleanup Logic

    /// Performs cleanup based on active rules
    func performCleanup() {
        guard isEnabled, let clipboardManager = ClipboardManager.shared else { return }

        let now = Date()
        var purgedCount = 0
        var itemsToRemove: [UUID] = []

        for item in clipboardManager.history {
            // Skip pinned items - user explicitly wants to keep these
            if clipboardManager.pinnedItems.contains(where: { $0.id == item.id }) {
                continue
            }

            // Only analyze text items
            guard case .text(let text) = item.content else { continue }

            let detectedTypes = detector.detect(in: text)
            guard !detectedTypes.isEmpty else { continue }

            // Check each rule
            for rule in rules where rule.enabled {
                let hasMatchingType = !Set(detectedTypes).isDisjoint(with: Set(rule.sensitiveTypes))
                guard hasMatchingType else { continue }

                let cutoffDate = now.addingTimeInterval(-Double(rule.purgeAfterMinutes * 60))
                if item.timestamp < cutoffDate {
                    itemsToRemove.append(item.id)
                    purgedCount += 1
                    break // No need to check other rules for this item
                }
            }
        }

        // Remove flagged items
        if !itemsToRemove.isEmpty {
            clipboardManager.history.removeAll { itemsToRemove.contains($0.id) }
            clipboardManager.saveHistory()

            totalPurged += purgedCount
            lastPurgeDate = now
            savePurgeStats()
        }
    }

    /// Manually triggers a purge scan
    func triggerManualPurge() {
        performCleanup()
    }

    /// Analyzes a single item without purging (for UI preview)
    func analyzeItem(_ item: ClipboardItem) -> [SensitiveDataType] {
        guard case .text(let text) = item.content else { return [] }
        return detector.detect(in: text)
    }

    // MARK: - Rule Management

    /// Adds a new purge rule
    func addRule(_ rule: PurgeRule) {
        rules.append(rule)
    }

    /// Updates an existing rule
    func updateRule(_ rule: PurgeRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        }
    }

    /// Removes a rule by ID
    func removeRule(id: UUID) {
        rules.removeAll { $0.id == id }
    }

    /// Resets rules to defaults
    func resetToDefaults() {
        rules = PurgeRule.defaults
    }

    // MARK: - Persistence

    private var rulesFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("SaneClip")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("purge_rules.json")
    }

    private func saveRules() {
        do {
            let data = try JSONEncoder().encode(rules)
            try data.write(to: rulesFileURL)
        } catch {
            print("Failed to save purge rules: \(error)")
        }
    }

    private func loadRules() {
        do {
            let data = try Data(contentsOf: rulesFileURL)
            rules = try JSONDecoder().decode([PurgeRule].self, from: data)
        } catch {
            // File doesn't exist or is corrupted - will use defaults
            rules = []
        }
    }

    private func savePurgeStats() {
        UserDefaults.standard.set(totalPurged, forKey: "autoPurgeTotalCount")
        UserDefaults.standard.set(lastPurgeDate, forKey: "autoPurgeLastDate")
    }
}
