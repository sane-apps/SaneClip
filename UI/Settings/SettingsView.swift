import AppKit
import KeyboardShortcuts
import LocalAuthentication
import os.log
import SaneUI
import SwiftUI

let settingsLogger = Logger(subsystem: "com.saneclip.app", category: "Settings")
let clipReadableSecondary = Color.white.opacity(0.88)
let clipReadableMuted = Color.white.opacity(0.78)
let clipReadableMonospace = Color.white.opacity(0.92)

typealias ClipActionButtonStyle = SaneUI.SaneActionButtonStyle

// MARK: - Notifications

extension Notification.Name {
    static let menuBarIconChanged = Notification.Name("menuBarIconChanged")
    static let historySearchShortcutRequested = Notification.Name("historySearchShortcutRequested")
    static let settingsTabShortcutRequested = Notification.Name("settingsTabShortcutRequested")
    static let settingsAddExcludedAppRequested = Notification.Name("settingsAddExcludedAppRequested")
}

// MARK: - Settings View

struct SettingsView: View {
    var licenseService: LicenseService?
    @State private var selectedTab: SettingsTab?

    enum SettingsTab: String, SaneSettingsTab {
        case general = "General"
        case shortcuts = "Shortcuts"
        #if ENABLE_SYNC
        case sync = "Sync"
        #endif
        case snippets = "Snippets"
        case storage = "Storage"
        case license = "License"
        case about = "About"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: SaneSettingsStrings.generalTabTitle
            case .shortcuts: SaneSettingsStrings.shortcutsTabTitle
            #if ENABLE_SYNC
            case .sync: SaneSettingsStrings.syncTabTitle
            #endif
            case .snippets: SaneSettingsStrings.snippetsTabTitle
            case .storage: SaneSettingsStrings.storageTabTitle
            case .license: SaneSettingsStrings.licenseTabTitle
            case .about: SaneSettingsStrings.aboutTabTitle
            }
        }

        var icon: String {
            switch self {
            case .general: "gear"
            case .shortcuts: "keyboard"
            #if ENABLE_SYNC
            case .sync: "arrow.triangle.2.circlepath.icloud"
            #endif
            case .snippets: "text.quote"
            case .storage: "chart.pie"
            case .license: "key"
            case .about: "info.circle"
            }
        }

        var iconColor: Color {
            switch self {
            case .general: SaneSettingsIconSemantic.general.color
            case .shortcuts: SaneSettingsIconSemantic.shortcuts.color
            #if ENABLE_SYNC
            case .sync: SaneSettingsIconSemantic.sync.color
            #endif
            case .snippets: SaneSettingsIconSemantic.content.color
            case .storage: SaneSettingsIconSemantic.storage.color
            case .license: SaneSettingsIconSemantic.license.color
            case .about: SaneSettingsIconSemantic.about.color
            }
        }
    }

    init(licenseService: LicenseService?, initialTab: SettingsTab? = .general) {
        self.licenseService = licenseService
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        SaneSettingsContainer(defaultTab: .general, selection: $selectedTab, windowSizing: .embedded) { tab in
            switch tab {
            case .general:
                GeneralSettingsView(licenseService: licenseService)
            case .shortcuts:
                ShortcutsSettingsView(licenseService: licenseService)
            #if ENABLE_SYNC
            case .sync:
                SyncSettingsView()
            #endif
            case .snippets:
                SnippetsSettingsView(licenseService: licenseService)
                    .padding(20)
            case .storage:
                StorageStatsView()
                    .padding(20)
            case .license:
                Group {
                    if let licenseService {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                LicenseSettingsView(licenseService: licenseService, style: .panel)
                                    .frame(maxWidth: 420, alignment: .leading)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(20)
                        }
                    } else {
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .about:
                SaneAboutView(
                    appName: "SaneClip",
                    githubRepo: "SaneClip",
                    diagnosticsService: .shared,
                    licenses: saneClipAboutLicenses(licenseService: licenseService)
                )
            }
        }
        .frame(minWidth: 760, idealWidth: 760, minHeight: 500, idealHeight: 500)
        .background(settingsKeyboardShortcuts)
        .onExitCommand {
            SettingsWindowController.close()
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsTabShortcutRequested)) { notification in
            guard let tab = notification.object as? SettingsTab else { return }
            selectedTab = tab
        }
    }

    nonisolated static func tab(forShortcutIndex index: Int) -> SettingsTab? {
        guard SettingsTab.allCases.indices.contains(index) else { return nil }
        return SettingsTab.allCases[index]
    }

    @ViewBuilder
    private var settingsKeyboardShortcuts: some View {
        ZStack {
            ForEach(Array(SettingsTab.allCases.enumerated()), id: \.element.id) { index, tab in
                Button("") {
                    selectedTab = tab
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0.001)
                .accessibilityHidden(true)
            }
        }
    }
}

@MainActor
private func saneClipAboutLicenses(licenseService: LicenseService?) -> [SaneAboutView.LicenseEntry] {
    var entries = [
        SaneAboutView.LicenseEntry(
            name: "KeyboardShortcuts",
            url: "https://github.com/sindresorhus/KeyboardShortcuts",
            text: """
            MIT License (third-party dependency)

            Copyright (c) Sindre Sorhus <sindresorhus@gmail.com> (https://sindresorhus.com)

            Permission is hereby granted, free of charge, to any person obtaining a copy \
            of this software and associated documentation files (the "Software"), to deal \
            in the Software without restriction, including without limitation the rights \
            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
            copies of the Software, and to permit persons to whom the Software is \
            furnished to do so, subject to the following conditions:

            The above copyright notice and this permission notice shall be included in all \
            copies or substantial portions of the Software.

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
            SOFTWARE.
            """
        )
    ]

    if licenseService?.distributionChannel.supportsInAppUpdates == true {
        entries.append(
            SaneAboutView.LicenseEntry(
                name: "Sparkle",
                url: "https://sparkle-project.org",
                text: """
                Copyright (c) 2006-2013 Andy Matuschak.
                Copyright (c) 2009-2013 Elgato Systems GmbH.
                Copyright (c) 2011-2014 Kornel Lesiński.
                Copyright (c) 2015-2017 Mayur Pawashe.
                Copyright (c) 2014 C.W. Betts.
                Copyright (c) 2014 Petroules Corporation.
                Copyright (c) 2014 Big Nerd Ranch.
                All rights reserved.

                Permission is hereby granted, free of charge, to any person obtaining a copy of
                this software and associated documentation files (the "Software"), to deal in
                the Software without restriction, including without limitation the rights to
                use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
                of the Software, and to permit persons to whom the Software is furnished to do
                so, subject to the following conditions:

                The above copyright notice and this permission notice shall be included in all
                copies or substantial portions of the Software.

                THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
                IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
                FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
                COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
                IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
                CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
                """
            )
        )
    }

    return entries
}

@MainActor
private func preferredPanelHostWindow(explicitWindow: NSWindow? = nil) -> NSWindow? {
    if let explicitWindow, explicitWindow.isVisible {
        return explicitWindow
    }

    if let settingsWindow = SettingsWindowController.presentedWindow {
        return settingsWindow
    }

    if let keyWindow = NSApp.keyWindow, keyWindow.isVisible {
        return keyWindow
    }

    if let mainWindow = NSApp.mainWindow, mainWindow.isVisible {
        return mainWindow
    }

    return NSApp.windows.first(where: \.isVisible)
}

@MainActor
func presentOpenPanel(_ panel: NSOpenPanel, onSelection: @escaping (URL) -> Void) {
    if NSApp.activationPolicy() == .accessory {
        settingsLogger.info("Presenting open panel modally for accessory app flow")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settingsLogger.info("Accessory open panel completed with selection \(url.path, privacy: .public)")
        onSelection(url)
        return
    }

    if let window = preferredPanelHostWindow() {
        settingsLogger.info(
            "Presenting open panel as sheet on window title=\(window.title, privacy: .public) class=\(String(describing: type(of: window)), privacy: .public)"
        )
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            settingsLogger.info("Open panel completed with selection \(url.path, privacy: .public)")
            onSelection(url)
        }
        return
    }

    settingsLogger.info("Presenting open panel modally without host window")
    guard panel.runModal() == .OK, let url = panel.url else { return }
    settingsLogger.info("Modal open panel completed with selection \(url.path, privacy: .public)")
    onSelection(url)
}

@MainActor
func presentSavePanel(_ panel: NSSavePanel, onSelection: @escaping (URL) -> Void) {
    if NSApp.activationPolicy() == .accessory {
        settingsLogger.info("Presenting save panel modally for accessory app flow")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settingsLogger.info("Accessory save panel completed with selection \(url.path, privacy: .public)")
        onSelection(url)
        return
    }

    if let window = preferredPanelHostWindow() {
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            onSelection(url)
        }
        return
    }

    guard panel.runModal() == .OK, let url = panel.url else { return }
    onSelection(url)
}

@MainActor
func showSettingsWarning(message: String, info: String) {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = info
    alert.alertStyle = .warning
    alert.runModal()
}
