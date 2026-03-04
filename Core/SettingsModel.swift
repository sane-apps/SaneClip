import Combine
import SwiftUI

/// Sound to play when pasting from clipboard history
enum PasteSound: String, CaseIterable {
    case off = "Off"
    case tink = "Tink"
    case pop = "Pop"
    case glass = "Glass"

    /// Play the configured sound (no-op for .off)
    func play() {
        switch self {
        case .off: break
        case .tink: NSSound(named: .init("Tink"))?.play()
        case .pop: NSSound(named: .init("Pop"))?.play()
        case .glass: NSSound(named: .init("Glass"))?.play()
        }
    }
}

/// Default paste mode when pasting from history
enum PasteMode: String, CaseIterable {
    case standard = "Standard"
    case plain = "Plain Text"
    case smart = "Smart"

    var description: String {
        switch self {
        case .standard: "Paste with original formatting"
        case .plain: "Always strip formatting"
        case .smart: "Auto-detect: code→plain, URL→cleaned, else→standard"
        }
    }
}

@MainActor
@Observable
class SettingsModel {
    static let shared = SettingsModel()

    nonisolated static let allowedMaxCaptureTextBytes: Set<Int> = [
        0,
        64 * 1024,
        256 * 1024,
        512 * 1024,
        1024 * 1024
    ]

    nonisolated static let allowedMaxCaptureImageBytes: Set<Int> = [
        0,
        2 * 1024 * 1024,
        5 * 1024 * 1024,
        10 * 1024 * 1024,
        25 * 1024 * 1024
    ]

    nonisolated static func normalizedCaptureTextBytes(_ value: Int) -> Int {
        allowedMaxCaptureTextBytes.contains(value) ? value : 256 * 1024
    }

    nonisolated static func normalizedCaptureImageBytes(_ value: Int) -> Int {
        allowedMaxCaptureImageBytes.contains(value) ? value : 5 * 1024 * 1024
    }

    var maxHistorySize: Int {
        didSet {
            UserDefaults.standard.set(maxHistorySize, forKey: "maxHistorySize")
        }
    }

    /// When enabled, opening history anchors near current mouse cursor instead of menu bar icon.
    var openHistoryAtCursor: Bool {
        didSet {
            UserDefaults.standard.set(openHistoryAtCursor, forKey: "openHistoryAtCursor")
        }
    }

    var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: "showInDock")
            applyDockVisibility()
        }
    }

    var protectPasswords: Bool {
        didSet {
            UserDefaults.standard.set(protectPasswords, forKey: "protectPasswords")
        }
    }

    var requireTouchID: Bool {
        didSet {
            UserDefaults.standard.set(requireTouchID, forKey: "requireTouchID")
        }
    }

    var excludedApps: [String] {
        didSet {
            UserDefaults.standard.set(excludedApps, forKey: "excludedApps")
        }
    }

    var pasteSound: PasteSound {
        didSet {
            UserDefaults.standard.set(pasteSound.rawValue, forKey: "pasteSound")
        }
    }

    /// Backward-compatible computed property
    var playSounds: Bool { pasteSound != .off }

    /// Paste stack order: false = FIFO (oldest first), true = LIFO (newest first)
    var pasteStackReversed: Bool {
        didSet {
            UserDefaults.standard.set(pasteStackReversed, forKey: "pasteStackReversed")
        }
    }

    /// Keep the history panel visible between paste-stack actions by reopening it after each paste.
    var keepPasteStackOpenBetweenPastes: Bool {
        didSet {
            UserDefaults.standard.set(keepPasteStackOpenBetweenPastes, forKey: "keepPasteStackOpenBetweenPastes")
        }
    }

    /// When enabled, close the history panel after the last stack item is consumed.
    var autoClosePasteStackWhenEmpty: Bool {
        didSet {
            UserDefaults.standard.set(autoClosePasteStackWhenEmpty, forKey: "autoClosePasteStackWhenEmpty")
        }
    }

    /// Temporarily disable consuming items from the paste stack.
    var pausePasteStackConsumption: Bool {
        didSet {
            UserDefaults.standard.set(pausePasteStackConsumption, forKey: "pausePasteStackConsumption")
        }
    }

    /// Collapse duplicate entries in the paste stack by content hash.
    var collapseDuplicatePasteStackItems: Bool {
        didSet {
            UserDefaults.standard.set(collapseDuplicatePasteStackItems, forKey: "collapseDuplicatePasteStackItems")
        }
    }

    /// Optional per-app paste mode overrides keyed by source bundle ID.
    var perAppPasteModes: [String: String] {
        didSet {
            UserDefaults.standard.set(perAppPasteModes, forKey: "perAppPasteModes")
        }
    }

    var menuBarIcon: String {
        didSet {
            UserDefaults.standard.set(menuBarIcon, forKey: "menuBarIcon")
            NotificationCenter.default.post(name: .menuBarIconChanged, object: menuBarIcon)
        }
    }

    /// Auto-expire items after this many hours (0 = never expire)
    var autoExpireHours: Int {
        didSet {
            UserDefaults.standard.set(autoExpireHours, forKey: "autoExpireHours")
        }
    }

    /// Encrypt clipboard history at rest using AES-GCM
    var encryptHistory: Bool {
        didSet {
            UserDefaults.standard.set(encryptHistory, forKey: "encryptHistory")
            // Re-save history to apply encryption/decryption change
            ClipboardManager.shared?.saveHistory()
        }
    }

    /// Default paste mode for history items
    var defaultPasteMode: PasteMode {
        didSet {
            UserDefaults.standard.set(defaultPasteMode.rawValue, forKey: "defaultPasteMode")
        }
    }

    /// Maximum text size to capture from clipboard (bytes, UTF-8). 0 disables limit.
    var maxCaptureTextBytes: Int {
        didSet {
            UserDefaults.standard.set(maxCaptureTextBytes, forKey: "maxCaptureTextBytes")
        }
    }

    /// Maximum image size to capture from clipboard/file (bytes). 0 disables limit.
    var maxCaptureImageBytes: Int {
        didSet {
            UserDefaults.standard.set(maxCaptureImageBytes, forKey: "maxCaptureImageBytes")
        }
    }

    func isAppExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedApps.contains(bundleID)
    }

    func addExcludedApp(_ bundleID: String) {
        if !excludedApps.contains(bundleID) {
            excludedApps.append(bundleID)
        }
    }

    func removeExcludedApp(_ bundleID: String) {
        excludedApps.removeAll { $0 == bundleID }
    }

    init() {
        maxHistorySize = UserDefaults.standard.object(forKey: "maxHistorySize") as? Int ?? 50
        openHistoryAtCursor = UserDefaults.standard.object(forKey: "openHistoryAtCursor") as? Bool ?? false
        showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? false
        protectPasswords = UserDefaults.standard.object(forKey: "protectPasswords") as? Bool ?? true
        requireTouchID = UserDefaults.standard.object(forKey: "requireTouchID") as? Bool ?? false
        excludedApps = UserDefaults.standard.object(forKey: "excludedApps") as? [String] ?? []
        // Migrate from old playSounds bool → new pasteSound enum
        if let raw = UserDefaults.standard.string(forKey: "pasteSound"),
           let sound = PasteSound(rawValue: raw) {
            pasteSound = sound
        } else if let oldBool = UserDefaults.standard.object(forKey: "playSounds") as? Bool {
            pasteSound = oldBool ? .pop : .off
        } else {
            pasteSound = .off
        }
        menuBarIcon = UserDefaults.standard.object(forKey: "menuBarIcon") as? String ?? "list.clipboard.fill"
        autoExpireHours = UserDefaults.standard.object(forKey: "autoExpireHours") as? Int ?? 0
        // Basic default must be non-contradictory with Pro gating.
        encryptHistory = UserDefaults.standard.object(forKey: "encryptHistory") as? Bool ?? false
        pasteStackReversed = UserDefaults.standard.object(forKey: "pasteStackReversed") as? Bool ?? false
        keepPasteStackOpenBetweenPastes = UserDefaults.standard.object(forKey: "keepPasteStackOpenBetweenPastes") as? Bool ?? true
        autoClosePasteStackWhenEmpty = UserDefaults.standard.object(forKey: "autoClosePasteStackWhenEmpty") as? Bool ?? true
        pausePasteStackConsumption = UserDefaults.standard.object(forKey: "pausePasteStackConsumption") as? Bool ?? false
        collapseDuplicatePasteStackItems = UserDefaults.standard.object(forKey: "collapseDuplicatePasteStackItems") as? Bool ?? true
        perAppPasteModes = UserDefaults.standard.object(forKey: "perAppPasteModes") as? [String: String] ?? [:]
        defaultPasteMode = PasteMode(rawValue: UserDefaults.standard.string(forKey: "defaultPasteMode") ?? "") ?? .standard
        let savedTextBytes = UserDefaults.standard.object(forKey: "maxCaptureTextBytes") as? Int ?? 262_144
        let normalizedTextBytes = Self.normalizedCaptureTextBytes(savedTextBytes)
        maxCaptureTextBytes = normalizedTextBytes

        let savedImageBytes = UserDefaults.standard.object(forKey: "maxCaptureImageBytes") as? Int ?? 5_000_000
        let normalizedImageBytes = Self.normalizedCaptureImageBytes(savedImageBytes)
        maxCaptureImageBytes = normalizedImageBytes

        if normalizedTextBytes != savedTextBytes {
            UserDefaults.standard.set(normalizedTextBytes, forKey: "maxCaptureTextBytes")
        }
        if normalizedImageBytes != savedImageBytes {
            UserDefaults.standard.set(normalizedImageBytes, forKey: "maxCaptureImageBytes")
        }
        applyDockVisibility()
    }

    private func applyDockVisibility() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    // MARK: - Settings Export/Import

    enum SettingsError: Error, LocalizedError {
        case encodingFailed
        case decodingFailed
        case invalidFormat

        var errorDescription: String? {
            switch self {
            case .encodingFailed: "Could not encode settings"
            case .decodingFailed: "Could not decode settings"
            case .invalidFormat: "Invalid settings file format"
            }
        }
    }

    /// Export all settings to JSON data
    func exportSettings() throws -> Data {
        let settings: [String: Any] = [
            "version": 1, // For future format versioning
            "maxHistorySize": maxHistorySize,
            "openHistoryAtCursor": openHistoryAtCursor,
            "showInDock": showInDock,
            "protectPasswords": protectPasswords,
            "requireTouchID": requireTouchID,
            "excludedApps": excludedApps,
            "pasteSound": pasteSound.rawValue,
            "menuBarIcon": menuBarIcon,
            "autoExpireHours": autoExpireHours,
            "encryptHistory": encryptHistory,
            "pasteStackReversed": pasteStackReversed,
            "keepPasteStackOpenBetweenPastes": keepPasteStackOpenBetweenPastes,
            "autoClosePasteStackWhenEmpty": autoClosePasteStackWhenEmpty,
            "pausePasteStackConsumption": pausePasteStackConsumption,
            "collapseDuplicatePasteStackItems": collapseDuplicatePasteStackItems,
            "defaultPasteMode": defaultPasteMode.rawValue,
            "perAppPasteModes": perAppPasteModes,
            "maxCaptureTextBytes": maxCaptureTextBytes,
            "maxCaptureImageBytes": maxCaptureImageBytes,
            // Include clipboard rules
            "rules": [
                "stripTrackingParams": ClipboardRulesManager.shared.stripTrackingParams,
                "autoTrimWhitespace": ClipboardRulesManager.shared.autoTrimWhitespace,
                "normalizeLineEndings": ClipboardRulesManager.shared.normalizeLineEndings,
                "removeDuplicateSpaces": ClipboardRulesManager.shared.removeDuplicateSpaces,
                "lowercaseURLs": ClipboardRulesManager.shared.lowercaseURLs
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted) else {
            throw SettingsError.encodingFailed
        }
        return data
    }

    /// Import settings from JSON data
    func importSettings(from data: Data) throws {
        guard let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SettingsError.decodingFailed
        }

        // Apply each setting if present
        if let value = settings["maxHistorySize"] as? Int {
            maxHistorySize = value
        }
        if let value = settings["openHistoryAtCursor"] as? Bool {
            openHistoryAtCursor = value
        }
        if let value = settings["showInDock"] as? Bool {
            showInDock = value
        }
        if let value = settings["protectPasswords"] as? Bool {
            protectPasswords = value
        }
        if let value = settings["requireTouchID"] as? Bool {
            requireTouchID = value
        }
        if let value = settings["excludedApps"] as? [String] {
            excludedApps = value
        }
        if let value = settings["pasteSound"] as? String,
           let sound = PasteSound(rawValue: value) {
            pasteSound = sound
        } else if let value = settings["playSounds"] as? Bool {
            pasteSound = value ? .pop : .off
        }
        if let value = settings["menuBarIcon"] as? String {
            menuBarIcon = value
        }
        if let value = settings["autoExpireHours"] as? Int {
            autoExpireHours = value
        }
        if let value = settings["encryptHistory"] as? Bool {
            encryptHistory = value
        }
        if let value = settings["pasteStackReversed"] as? Bool {
            pasteStackReversed = value
        }
        if let value = settings["keepPasteStackOpenBetweenPastes"] as? Bool {
            keepPasteStackOpenBetweenPastes = value
        }
        if let value = settings["autoClosePasteStackWhenEmpty"] as? Bool {
            autoClosePasteStackWhenEmpty = value
        }
        if let value = settings["pausePasteStackConsumption"] as? Bool {
            pausePasteStackConsumption = value
        }
        if let value = settings["collapseDuplicatePasteStackItems"] as? Bool {
            collapseDuplicatePasteStackItems = value
        }
        if let value = settings["defaultPasteMode"] as? String,
           let mode = PasteMode(rawValue: value) {
            defaultPasteMode = mode
        }
        if let value = settings["perAppPasteModes"] as? [String: String] {
            perAppPasteModes = value
        }
        if let value = settings["maxCaptureTextBytes"] as? Int {
            maxCaptureTextBytes = Self.normalizedCaptureTextBytes(value)
        }
        if let value = settings["maxCaptureImageBytes"] as? Int {
            maxCaptureImageBytes = Self.normalizedCaptureImageBytes(value)
        }

        // Apply clipboard rules if present
        if let rules = settings["rules"] as? [String: Any] {
            let rulesManager = ClipboardRulesManager.shared
            if let value = rules["stripTrackingParams"] as? Bool {
                rulesManager.stripTrackingParams = value
            }
            if let value = rules["autoTrimWhitespace"] as? Bool {
                rulesManager.autoTrimWhitespace = value
            }
            if let value = rules["normalizeLineEndings"] as? Bool {
                rulesManager.normalizeLineEndings = value
            }
            if let value = rules["removeDuplicateSpaces"] as? Bool {
                rulesManager.removeDuplicateSpaces = value
            }
            if let value = rules["lowercaseURLs"] as? Bool {
                rulesManager.lowercaseURLs = value
            }
        }
    }

    func pasteMode(for bundleID: String?) -> PasteMode? {
        guard let bundleID,
              let raw = perAppPasteModes[bundleID],
              let mode = PasteMode(rawValue: raw)
        else { return nil }
        return mode
    }

    func setPasteMode(_ mode: PasteMode?, for bundleID: String) {
        var map = perAppPasteModes
        if let mode {
            map[bundleID] = mode.rawValue
        } else {
            map.removeValue(forKey: bundleID)
        }
        perAppPasteModes = map
    }
}
