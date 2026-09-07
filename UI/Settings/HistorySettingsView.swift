import AppKit
import SaneUI
import SwiftUI

struct HistorySettingsView: View {
    var licenseService: LicenseService?
    @State var settings = SettingsModel.shared
    private var isPro: Bool {
        licenseService?.isPro == true
    }

    private var historySizeChoices: [Int] {
        let currentChoice = SettingsModel.normalizedMaxHistorySize(settings.maxHistorySize)
        let allChoices = Set(SettingsModel.proHistorySizeChoices + [currentChoice])
        return allChoices.sorted { lhs, rhs in
            if SettingsModel.isUnlimitedHistorySize(lhs) {
                return false
            }
            if SettingsModel.isUnlimitedHistorySize(rhs) {
                return true
            }
            return lhs < rhs
        }
    }

    var body: some View {
        SaneSettingsPage {
            Text(String(localized: "History"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            CompactSection(String(localized: "History Limits")) {
                CompactRow(SaneClipSettingsCopy.maximumItemsLabel) {
                    if isPro {
                        Picker("", selection: Binding(
                            get: { settings.maxHistorySize },
                            set: { settings.maxHistorySize = SettingsModel.normalizedMaxHistorySize($0) }
                        )) {
                            ForEach(historySizeChoices, id: \.self) { choice in
                                Text(SettingsModel.historySizeLabel(choice)).tag(choice)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        .help("Pro keeps as much history as you configure, including unlimited.")
                    } else {
                        Button {
                            if let ls = licenseService {
                                ProUpsellWindow.show(feature: ProFeature.unlimitedHistory, licenseService: ls)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("50")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("•")
                                    .foregroundStyle(.white)
                                Text("100 / 500 / Unlimited")
                                    .foregroundStyle(.white)
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.proUnlock)
                                Text("Pro")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.proUnlock)
                            }
                        }
                        .buttonStyle(ClipActionButtonStyle())
                        .controlSize(.small)
                    }
                }
                CompactDivider()
                CompactRow(SaneClipSettingsCopy.autoDeleteAfterLabel) {
                    Picker("", selection: Binding(
                        get: { settings.autoExpireHours },
                        set: { settings.autoExpireHours = $0 }
                    )) {
                        Text(String(localized: "saneclip.settings.history.never", defaultValue: "Never")).tag(0)
                        Text(String(localized: "saneclip.settings.history.1_hour", defaultValue: "1 hour")).tag(1)
                        Text(String(localized: "saneclip.settings.history.24_hours", defaultValue: "24 hours")).tag(24)
                        Text(String(localized: "saneclip.settings.history.7_days", defaultValue: "7 days")).tag(168)
                        Text(String(localized: "saneclip.settings.history.30_days", defaultValue: "30 days")).tag(720)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    .help(SaneClipSettingsCopy.pinnedItemsHelp)
                }
            }

            CompactSection(SaneClipSettingsCopy.backupRestoreSectionTitle) {
                CompactRow(SaneClipSettingsCopy.historySectionTitle) {
                    if isPro {
                        HStack(spacing: 8) {
                            Button(SaneClipSettingsCopy.exportButtonTitle) {
                                exportHistory()
                            }
                            .buttonStyle(ClipActionButtonStyle())
                            .controlSize(.small)

                            Button(SaneClipSettingsCopy.importButtonTitle) {
                                importHistory()
                            }
                            .buttonStyle(ClipActionButtonStyle())
                            .controlSize(.small)
                        }
                    } else {
                        Button {
                            if let ls = licenseService {
                                ProUpsellWindow.show(feature: ProFeature.exportImport, licenseService: ls)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(SaneClipSettingsCopy.exportImportLabel)
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Pro")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Color.proUnlock)
                        }
                        .buttonStyle(ClipActionButtonStyle())
                        .controlSize(.small)
                    }
                }
                CompactDivider()
                CompactRow(SaneClipSettingsCopy.settingsLabel) {
                    HStack(spacing: 8) {
                        Button(SaneClipSettingsCopy.exportButtonTitle) {
                            exportSettings()
                        }
                        .buttonStyle(ClipActionButtonStyle())
                        .controlSize(.small)

                        Button(SaneClipSettingsCopy.importButtonTitle) {
                            importSettings()
                        }
                        .buttonStyle(ClipActionButtonStyle())
                        .controlSize(.small)
                    }
                }
            }

            CompactSection(String(localized: "Storage Usage")) {
                StorageStatsView().padding(12)
            }
        }
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
