import Combine
import SwiftUI

@MainActor
@Observable
class SettingsModel {
    static let shared = SettingsModel()

    var maxHistorySize: Int {
        didSet {
            UserDefaults.standard.set(maxHistorySize, forKey: "maxHistorySize")
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

    var playSounds: Bool {
        didSet {
            UserDefaults.standard.set(playSounds, forKey: "playSounds")
        }
    }

    /// Paste stack order: false = FIFO (oldest first), true = LIFO (newest first)
    var pasteStackReversed: Bool {
        didSet {
            UserDefaults.standard.set(pasteStackReversed, forKey: "pasteStackReversed")
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
        showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true
        protectPasswords = UserDefaults.standard.object(forKey: "protectPasswords") as? Bool ?? true
        requireTouchID = UserDefaults.standard.object(forKey: "requireTouchID") as? Bool ?? false
        excludedApps = UserDefaults.standard.object(forKey: "excludedApps") as? [String] ?? []
        playSounds = UserDefaults.standard.object(forKey: "playSounds") as? Bool ?? false
        menuBarIcon = UserDefaults.standard.object(forKey: "menuBarIcon") as? String ?? "list.clipboard.fill"
        autoExpireHours = UserDefaults.standard.object(forKey: "autoExpireHours") as? Int ?? 0
        encryptHistory = UserDefaults.standard.object(forKey: "encryptHistory") as? Bool ?? true
        pasteStackReversed = UserDefaults.standard.object(forKey: "pasteStackReversed") as? Bool ?? false
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
            "showInDock": showInDock,
            "protectPasswords": protectPasswords,
            "requireTouchID": requireTouchID,
            "excludedApps": excludedApps,
            "playSounds": playSounds,
            "menuBarIcon": menuBarIcon,
            "autoExpireHours": autoExpireHours,
            "encryptHistory": encryptHistory,
            "pasteStackReversed": pasteStackReversed,
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
        if let value = settings["playSounds"] as? Bool {
            playSounds = value
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
}
