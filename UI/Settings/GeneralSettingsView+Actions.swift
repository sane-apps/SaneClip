import AppKit
import KeyboardShortcuts
import LocalAuthentication
import os.log
import SaneUI
import SwiftUI

extension GeneralSettingsView {
    func refreshPermissionState() {
        screenCapturePermissionGranted = ScreenCapturePermissionService.isGranted()
    }

    @MainActor
    func authenticateForSecurityChange(reason: String) async -> Bool {
        isAuthenticating = true
        let context = LAContext()
        var error: NSError?

        // Use biometrics if available, otherwise fall back to device password
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        let success = await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                policy,
                localizedReason: reason
            ) { didSucceed, _ in
                continuation.resume(returning: didSucceed)
            }
        }

        isAuthenticating = false
        return success
    }

    func popupSymbolImage(_ systemImage: String) -> NSImage {
        let weightConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: .white)
        let resolvedConfig = weightConfig.applying(colorConfig)

        guard let symbol = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)?
                .withSymbolConfiguration(resolvedConfig)
        else {
            return NSImage()
        }

        symbol.isTemplate = false
        return symbol
    }

    func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "clipboard-history.json"
        panel.title = "Export Clipboard History"

        presentSavePanel(panel) { url in
            if let data = ClipboardManager.exportHistoryFromDisk() {
                do {
                    try data.write(to: url)
                } catch {
                    print("Failed to export history: \(error)")
                }
            }
        }
    }

    func importHistory() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Import Clipboard History"
        panel.message = "Select a previously exported clipboard history file"

        presentOpenPanel(panel) { url in
            // Show merge/replace confirmation
            let alert = NSAlert()
            alert.messageText = "Import Clipboard History"
            alert.informativeText = "How would you like to import the history?"
            alert.addButton(withTitle: "Merge")
            alert.addButton(withTitle: "Replace All")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .informational

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn: // Merge
                performImport(from: url, merge: true)
            case .alertSecondButtonReturn: // Replace
                performImport(from: url, merge: false)
            default:
                break
            }
        }
    }

    func performImport(from url: URL, merge: Bool) {
        guard let manager = ClipboardManager.shared else { return }
        do {
            let count = try manager.importHistory(from: url, merge: merge)
            let alert = NSAlert()
            alert.messageText = "Import Successful"
            alert.informativeText = merge
                ? "Imported \(count) new items."
                : "Replaced history with \(count) items."
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Import Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "saneclip-settings.json"
        panel.title = "Export Settings"

        presentSavePanel(panel) { url in
            do {
                let data = try settings.exportSettings()
                try data.write(to: url)
                let alert = NSAlert()
                alert.messageText = "Settings Exported"
                alert.informativeText = "Your settings have been saved."
                alert.alertStyle = .informational
                alert.runModal()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Import Settings"
        panel.message = "Select a previously exported settings file"

        presentOpenPanel(panel) { url in
            do {
                let data = try Data(contentsOf: url)
                try settings.importSettings(from: data)
                let alert = NSAlert()
                alert.messageText = "Settings Imported"
                alert.informativeText = "Your settings have been restored."
                alert.alertStyle = .informational
                alert.runModal()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Import Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
}
