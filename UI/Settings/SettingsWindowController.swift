import AppKit
import SaneUI
import SwiftUI

// MARK: - Settings Window Controller

@MainActor
enum SettingsWindowController {
    enum PendingAction: Equatable {
        case excludedAppPicker
    }

    private static var window: NSWindow?
    private static var windowDelegate: SettingsWindowDelegate?
    private static var pendingAction: PendingAction?
    static var licenseService: LicenseService?
    static var presentedWindow: NSWindow? {
        guard let window, window.isVisible else { return nil }
        return window
    }

    static func open(tab: SettingsView.SettingsTab? = nil) {
        settingsLogger.info("Opening settings window with license service present=\(licenseService != nil) isPro=\(licenseService?.isPro == true)")
        if let existingWindow = window, existingWindow.isVisible {
            if let tab {
                existingWindow.contentViewController = makeHostingController(initialTab: tab)
            }
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(contentViewController: makeHostingController(initialTab: tab))
        newWindow.title = "SaneClip Settings"
        newWindow.appearance = NSAppearance(named: .darkAqua)
        newWindow.styleMask = [.titled, .closable, .resizable]
        newWindow.contentMinSize = NSSize(width: 760, height: 500)
        newWindow.setContentSize(NSSize(width: 760, height: 500))
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        // Standard window - glass effect handled in SwiftUI view
        newWindow.hasShadow = true

        let delegate = SettingsWindowDelegate()
        windowDelegate = delegate
        newWindow.delegate = delegate

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func close() {
        window?.performClose(nil)
    }

    static func schedulePendingAction(_ action: PendingAction) {
        pendingAction = action
    }

    static func consumePendingAction(_ action: PendingAction) -> Bool {
        guard pendingAction == action else { return false }
        pendingAction = nil
        return true
    }

    private static func makeHostingController(initialTab: SettingsView.SettingsTab?) -> NSHostingController<AnyView> {
        let settingsView = AnyView(
            SettingsView(licenseService: licenseService, initialTab: initialTab)
                .preferredColorScheme(.dark)
        )
        return NSHostingController(rootView: settingsView)
    }
}

/// Restores the user's Dock preference after settings closes, in case Sparkle or
/// another modal path temporarily forced `.regular` and left a ghost Dock tile.
private final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_: Notification) {
        SaneActivationPolicy.restorePolicy(showDockIcon: SettingsModel.shared.showInDock)
    }
}
