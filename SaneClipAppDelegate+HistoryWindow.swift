import AppKit
import SwiftUI

extension SaneClipAppDelegate {
    func showHistoryPopover() {
        if SettingsModel.shared.openHistoryAtCursor {
            showPopoverAtCursor()
        } else {
            showPopoverAtButton()
        }
    }

    func historyRootView() -> some View {
        ClipboardHistoryView(clipboardManager: clipboardManager, licenseService: licenseService)
            .frame(
                minWidth: ClipboardHistoryView.popoverWidth,
                idealWidth: ClipboardHistoryView.popoverWidth,
                maxWidth: ClipboardHistoryView.popoverWidth,
                minHeight: ClipboardHistoryView.popoverMinHeight,
                idealHeight: ClipboardHistoryView.popoverMinHeight,
                alignment: .top
            )
            .preferredColorScheme(.dark)
    }

    func toggleHistoryWindow() {
        if popover.isShown {
            popover.performClose(nil)
        }

        if let historyWindow, historyWindow.isVisible {
            historyWindow.close()
            return
        }

        showHistoryWindow()
    }

    func showHistoryWindow() {
        if popover.isShown {
            popover.performClose(nil)
        }

        if let historyWindow, historyWindow.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            historyWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = historyWindow ?? NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: ClipboardHistoryView.popoverWidth,
                height: ClipboardHistoryView.popoverMinHeight
            ),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "SaneClip History"
        window.contentViewController = NSHostingController(rootView: historyRootView())
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        historyWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func showPopoverAtButton() {
        guard let button = statusItem.button else { return }
        resetHistoryPopoverSize()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        if let popoverWindow = popover.contentViewController?.view.window {
            popoverWindow.makeKey()
        }
    }

    func showPopoverAtCursor() {
        guard let button = statusItem.button else { return }
        resetHistoryPopoverSize()

        // Use the status item as an anchor view, then reposition to cursor.
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        guard let popoverWindow = popover.contentViewController?.view.window else { return }

        let mouse = NSEvent.mouseLocation
        let size = popoverWindow.frame.size
        let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        let visible = targetScreen?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero

        // Prefer below cursor; fall back above if needed.
        var origin = NSPoint(
            x: mouse.x - (size.width / 2.0),
            y: mouse.y - size.height - 12
        )
        if origin.y < visible.minY {
            origin.y = mouse.y + 16
        }

        let minX = visible.minX
        let maxX = max(visible.minX, visible.maxX - size.width)
        let minY = visible.minY
        let maxY = max(visible.minY, visible.maxY - size.height)
        origin.x = min(max(origin.x, minX), maxX)
        origin.y = min(max(origin.y, minY), maxY)

        popoverWindow.setFrameOrigin(origin)
        popoverWindow.makeKey()
    }

    func resetHistoryPopoverSize() {
        let size = NSSize(
            width: ClipboardHistoryView.popoverWidth,
            height: ClipboardHistoryView.popoverMinHeight
        )
        popover.contentSize = size
        popover.contentViewController?.preferredContentSize = size
    }
}
