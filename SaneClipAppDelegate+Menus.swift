import AppKit
import SaneUI

extension SaneClipAppDelegate {
    func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "SaneClip")
        #if APP_STORE
            addAppStoreCoreUtilityItems(to: appMenu, settingsKeyEquivalent: ",")
        #else
            appMenu.addItem(SaneStandardMenu.aboutAndBugReportItem(target: self, action: #selector(openAboutSettings)))
            appMenu.addItem(SaneStandardMenu.settingsItem(target: self, action: #selector(openSettings)))
            appMenu.addItem(SaneStandardMenu.licenseItem(target: self, action: #selector(openLicenseSettings)))

            #if !SETAPP
                appMenu.addItem(SaneStandardMenu.checkForUpdatesItem(target: self, action: #selector(checkForUpdates)))
            #endif

            #if SETAPP
                appMenu.addItem(SaneStandardMenu.whatsNewItem(target: self, action: #selector(showReleaseNotes)))
            #endif
        #endif

        appMenu.addItem(NSMenuItem.separator())

        #if APP_STORE
            addAppStoreQuitItem(to: appMenu)
        #else
            appMenu.addItem(SaneStandardMenu.quitItem(appName: "SaneClip", target: NSApplication.shared, action: #selector(NSApplication.terminate(_:))))
        #endif
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: String(localized: "Edit"))
        let captureScreenshotItem = NSMenuItem(
            title: CaptureWorkflow.screenshot.menuTitle,
            action: #selector(captureScreenshotFromMenu),
            keyEquivalent: ""
        )
        captureScreenshotItem.target = self
        editMenu.addItem(captureScreenshotItem)

        let captureTextItem = NSMenuItem(
            title: captureTextMenuItemTitle,
            action: #selector(captureTextFromMenu),
            keyEquivalent: ""
        )
        captureTextItem.target = self
        editMenu.addItem(captureTextItem)

        editMenu.addItem(NSMenuItem.separator())

        let searchHistoryItem = NSMenuItem(title: String(localized: "Search History"), action: #selector(focusHistorySearch), keyEquivalent: "f")
        searchHistoryItem.keyEquivalentModifierMask = [.command]
        searchHistoryItem.target = self
        editMenu.addItem(searchHistoryItem)

        let addExcludedAppItem = NSMenuItem(title: String(localized: "Add Excluded App..."), action: #selector(requestExcludedAppPicker), keyEquivalent: "n")
        addExcludedAppItem.keyEquivalentModifierMask = [.command]
        addExcludedAppItem.target = self
        editMenu.addItem(addExcludedAppItem)

        editMenu.addItem(NSMenuItem.separator())

        // Build-by-copying entry point that works even when the stack panel is
        // closed and empty. Checkmark reflects the current mode via
        // validateMenuItem(_:).
        let recordStackItem = NSMenuItem(
            title: String(localized: "Record Copies to Paste Stack"),
            action: #selector(toggleStackRecordingFromMenu),
            keyEquivalent: "r"
        )
        recordStackItem.keyEquivalentModifierMask = [.command, .shift]
        recordStackItem.target = self
        editMenu.addItem(recordStackItem)
        editMenuItem.submenu = editMenu

        let settingsMenuItem = NSMenuItem()
        mainMenu.addItem(settingsMenuItem)

        let settingsMenu = NSMenu(title: String(localized: "Settings"))
        for item in settingsMenuItems() {
            settingsMenu.addItem(item)
        }
        settingsMenuItem.submenu = settingsMenu

        NSApp.mainMenu = mainMenu
    }

    func showContextMenu() {
        guard let button = statusItem.button else { return }
        let menu = buildContextMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }

    private func settingsMenuItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = [
            settingsMenuItem(title: String(localized: "General"), action: #selector(openGeneralSettings), key: "1"),
            settingsMenuItem(title: String(localized: "Shortcuts"), action: #selector(openShortcutsSettings), key: "2")
        ]

        #if ENABLE_SYNC
            items.append(settingsMenuItem(title: String(localized: "Sync"), action: #selector(openSyncSettings), key: "3"))
            items.append(settingsMenuItem(title: String(localized: "Snippets"), action: #selector(openSnippetsSettings), key: "4"))
            items.append(settingsMenuItem(title: String(localized: "Storage"), action: #selector(openStorageSettings), key: "5"))
            items.append(settingsMenuItem(title: String(localized: "License"), action: #selector(openLicenseSettings), key: "6"))
            items.append(settingsMenuItem(title: String(localized: "About"), action: #selector(openAboutSettings), key: "7"))
        #else
            items.append(settingsMenuItem(title: String(localized: "Snippets"), action: #selector(openSnippetsSettings), key: "3"))
            items.append(settingsMenuItem(title: String(localized: "Storage"), action: #selector(openStorageSettings), key: "4"))
            items.append(settingsMenuItem(title: String(localized: "License"), action: #selector(openLicenseSettings), key: "5"))
            items.append(settingsMenuItem(title: String(localized: "About"), action: #selector(openAboutSettings), key: "6"))
        #endif

        return items
    }

    private func settingsMenuItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = [.command]
        item.target = self
        return item
    }

    func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        let captureScreenshotItem = NSMenuItem(
            title: CaptureWorkflow.screenshot.menuTitle,
            action: #selector(captureScreenshotFromMenu),
            keyEquivalent: ""
        )
        captureScreenshotItem.target = self
        menu.addItem(captureScreenshotItem)

        let captureTextItem = NSMenuItem(
            title: captureTextMenuItemTitle,
            action: #selector(captureTextFromMenu),
            keyEquivalent: ""
        )
        captureTextItem.target = self
        menu.addItem(captureTextItem)

        menu.addItem(NSMenuItem.separator())

        let showItem = NSMenuItem(title: String(localized: "Show History"), action: #selector(showPopover), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(NSMenuItem.separator())

        addRecentItemsToMenu(menu)
        menu.addItem(buildSnippetsSubmenu())
        menu.addItem(NSMenuItem.separator())

        let clearItem = NSMenuItem(title: String(localized: "Clear History"), action: #selector(clearHistoryFromMenu), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(NSMenuItem.separator())

        #if APP_STORE
            addAppStoreCoreUtilityItems(to: menu, settingsKeyEquivalent: "")
            addAppStoreQuitItem(to: menu)
        #else
            SaneStandardMenu.addCoreUtilityItems(
                to: menu,
                appName: "SaneClip",
                target: self,
                settingsAction: #selector(openSettings),
                licenseAction: #selector(openLicenseSettings),
                checkForUpdatesAction: directUpdateAction,
                aboutAndBugReportAction: #selector(openAboutSettings),
                whatsNewAction: setappWhatsNewAction,
                quitTarget: NSApplication.shared,
                quitAction: #selector(NSApplication.terminate(_:)),
                settingsKeyEquivalent: ""
            )
        #endif

        return menu
    }

    #if APP_STORE
        private func addAppStoreCoreUtilityItems(to menu: NSMenu, settingsKeyEquivalent: String) {
            let aboutItem = NSMenuItem(title: String(localized: "About / Report a Bug..."), action: #selector(openAboutSettings), keyEquivalent: "")
            aboutItem.target = self
            menu.addItem(aboutItem)

            let settingsItem = NSMenuItem(title: String(localized: "Settings..."), action: #selector(openSettings), keyEquivalent: settingsKeyEquivalent)
            settingsItem.target = self
            settingsItem.keyEquivalentModifierMask = settingsKeyEquivalent.isEmpty ? [] : [.command]
            menu.addItem(settingsItem)

            let licenseItem = NSMenuItem(title: String(localized: "License..."), action: #selector(openLicenseSettings), keyEquivalent: "")
            licenseItem.target = self
            menu.addItem(licenseItem)
        }

        private func addAppStoreQuitItem(to menu: NSMenu) {
            let quitItem = NSMenuItem(
                title: String(localized: "Quit SaneClip"),
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
            quitItem.target = NSApplication.shared
            menu.addItem(quitItem)
        }
    #endif

    private func addRecentItemsToMenu(_ menu: NSMenu) {
        let recentItems = Array(clipboardManager.history.prefix(5))
        guard !recentItems.isEmpty else { return }
        for (index, item) in recentItems.enumerated() {
            let menuItem = NSMenuItem(
                title: String(item.preview.prefix(40)) + (item.preview.count > 40 ? "..." : ""),
                action: #selector(pasteFromMenu(_:)),
                keyEquivalent: ""
            )
            menuItem.tag = index
            menuItem.target = self
            menu.addItem(menuItem)
        }
        menu.addItem(NSMenuItem.separator())
    }

    private func buildSnippetsSubmenu() -> NSMenuItem {
        guard licenseService.isPro else {
            let snippetsItem = NSMenuItem(title: String(localized: "Snippets Pro") + " \u{1F512}", action: #selector(showSnippetsUpsell), keyEquivalent: "")
            snippetsItem.target = self
            return snippetsItem
        }

        let snippetsItem = NSMenuItem(title: String(localized: "Snippets"), action: nil, keyEquivalent: "")
        let snippetsMenu = NSMenu()
        let sections = SnippetManager.librarySections(for: SnippetManager.shared.snippets)
        if !sections.isEmpty {
            let helpItem = NSMenuItem(title: String(localized: "Paste into the frontmost email or document"), action: nil, keyEquivalent: "")
            helpItem.isEnabled = false
            snippetsMenu.addItem(helpItem)
            snippetsMenu.addItem(NSMenuItem.separator())

            for section in sections {
                let categoryItem = NSMenuItem(title: section.title, action: nil, keyEquivalent: "")
                let categoryMenu = NSMenu()
                for snippet in section.snippets {
                    let snippetMenuItem = NSMenuItem(
                        title: snippet.name,
                        action: #selector(pasteSnippetFromMenu(_:)),
                        keyEquivalent: ""
                    )
                    snippetMenuItem.representedObject = snippet.id.uuidString
                    snippetMenuItem.target = self
                    categoryMenu.addItem(snippetMenuItem)
                }
                categoryItem.submenu = categoryMenu
                snippetsMenu.addItem(categoryItem)
            }
        } else {
            let emptyItem = NSMenuItem(title: String(localized: "No snippets"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            snippetsMenu.addItem(emptyItem)
        }
        snippetsMenu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: String(localized: "Open Snippets Settings..."), action: #selector(openSnippetsSettingsFromMenu), keyEquivalent: "")
        settingsItem.target = self
        snippetsMenu.addItem(settingsItem)
        snippetsItem.submenu = snippetsMenu
        return snippetsItem
    }

    #if !APP_STORE && !SETAPP
        private var directUpdateAction: Selector? {
            #selector(checkForUpdates)
        }

        @objc private func checkForUpdates() {
            updateService.checkForUpdates()
        }
    #else
        private var directUpdateAction: Selector? {
            nil
        }
    #endif

    #if SETAPP
        private var setappWhatsNewAction: Selector? {
            #selector(showReleaseNotes)
        }
    #else
        private var setappWhatsNewAction: Selector? {
            nil
        }
    #endif

    @objc func toggleStackRecordingFromMenu() {
        clipboardManager.setStackRecording(!clipboardManager.isRecordingStack)
    }

    /// Reflects the current recording mode as a checkmark on the menu item.
    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleStackRecordingFromMenu) {
            menuItem.state = clipboardManager.isRecordingStack ? .on : .off
        }
        return true
    }
}
