import AppKit
import SwiftUI

/// The floating clipboard-history panel.
///
/// It must do two things that a plain `NSPanel` can't do together:
/// 1. NOT activate SaneClip when shown, so a paste lands in the app you were
///    typing in (`.nonactivatingPanel` style + `orderFrontRegardless()`).
/// 2. Still become the KEY window, so the search field is typeable AND — the
///    part that bit us — so a click on a row is delivered to the row instead of
///    being swallowed as a window-activating "first mouse" click.
///
/// A `.nonactivatingPanel` defaults `canBecomeKey` to `false`, which makes
/// `makeKey()` a no-op: the panel never becomes key, so the first click on any
/// row is eaten to "activate" the (inactive-app) window and the paste never
/// fires. Forcing `canBecomeKey = true` is exactly how Maccy solves this. We
/// keep `canBecomeMain = false` so we never take over the app's main window.
final class NonActivatingHistoryPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

extension View {
    /// Escalation hatch (currently unused): if a key non-activating panel still
    /// swallows the first click through SwiftUI's backing `NSClipView`, wrap the
    /// clickable row in this to force `acceptsFirstMouse`. See Christian Tietze,
    /// "Enable SwiftUI Button Click-Through for Inactive Windows on macOS".
    func acceptClickThrough() -> some View {
        ClickThroughBackdrop(self)
    }
}

private struct ClickThroughBackdrop<Content: View>: NSViewRepresentable {
    final class Backdrop: NSHostingView<Content> {
        override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
            true
        }
    }

    let content: Content
    init(_ content: Content) {
        self.content = content
    }

    func makeNSView(context _: Context) -> Backdrop {
        let backdrop = Backdrop(rootView: content)
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        return backdrop
    }

    func updateNSView(_ nsView: Backdrop, context _: Context) {
        nsView.rootView = content
    }
}
