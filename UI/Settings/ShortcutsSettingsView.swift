import AppKit
import KeyboardShortcuts
import LocalAuthentication
import os.log
import SaneUI
import SwiftUI

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    var licenseService: LicenseService?
    private var isPro: Bool {
        licenseService?.isPro == true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CompactSection("Main Shortcuts") {
                    CompactRow("Show Clipboard History") {
                        HStack(spacing: 8) {
                            KeyboardShortcuts.Recorder(for: .showClipboardHistory)
                            Button("Reset") {
                                KeyboardShortcuts.setShortcut(
                                    .init(.y, modifiers: [.command, .shift, .control]),
                                    for: .showClipboardHistory
                                )
                            }
                            .buttonStyle(ClipActionButtonStyle())
                            .controlSize(.small)
                            .help("Restore Command-Shift-Control-Y for Show Clipboard History")
                        }
                    }
                    CompactDivider()
                    CompactRow(SaneClipSettingsCopy.captureScreenshotLabel) {
                        KeyboardShortcuts.Recorder(for: .captureScreenshot)
                    }
                    CompactDivider()
                    if isPro {
                        CompactRow(SaneClipSettingsCopy.captureTextLabel) {
                            KeyboardShortcuts.Recorder(for: .captureText)
                        }
                    } else {
                        ProLockedRow(label: "\(SaneClipSettingsCopy.captureTextLabel) shortcut", feature: .ocrCapture, licenseService: licenseService)
                    }
                    CompactDivider()
                    CompactToggle(label: "Open history at mouse cursor", isOn: Binding(
                        get: { SettingsModel.shared.openHistoryAtCursor },
                        set: { SettingsModel.shared.openHistoryAtCursor = $0 }
                    ))
                    CompactDivider()
                    if isPro {
                        CompactRow("Paste as Plain Text") {
                            KeyboardShortcuts.Recorder(for: .pasteAsPlainText)
                        }
                    } else {
                        ProLockedRow(label: "Paste as Plain Text shortcut", feature: .plainTextPaste, licenseService: licenseService)
                    }
                    CompactDivider()
                    if isPro {
                        CompactRow("Paste from Stack") {
                            KeyboardShortcuts.Recorder(for: .pasteFromStack)
                        }
                    } else {
                        ProLockedRow(label: "Paste from Stack shortcut", feature: .pasteStack, licenseService: licenseService)
                    }
                    CompactDivider()
                    if isPro {
                        CompactRow("Smart Paste") {
                            KeyboardShortcuts.Recorder(for: .pasteSmartMode)
                        }
                    } else {
                        ProLockedRow(label: "Smart Paste shortcut", feature: .smartPaste, licenseService: licenseService)
                    }
                    CompactDivider()
                    CompactRow("Ignore Next Copy") {
                        KeyboardShortcuts.Recorder(for: .ignoreNextCopy)
                    }
                }

                CompactSection("Quick Paste (Items 1-9)") {
                    CompactRow("Paste Item 1") {
                        KeyboardShortcuts.Recorder(for: .pasteItem1)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 2") {
                        KeyboardShortcuts.Recorder(for: .pasteItem2)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 3") {
                        KeyboardShortcuts.Recorder(for: .pasteItem3)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 4") {
                        KeyboardShortcuts.Recorder(for: .pasteItem4)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 5") {
                        KeyboardShortcuts.Recorder(for: .pasteItem5)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 6") {
                        KeyboardShortcuts.Recorder(for: .pasteItem6)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 7") {
                        KeyboardShortcuts.Recorder(for: .pasteItem7)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 8") {
                        KeyboardShortcuts.Recorder(for: .pasteItem8)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 9") {
                        KeyboardShortcuts.Recorder(for: .pasteItem9)
                    }
                }
            }
            .padding(20)
        }
    }
}
