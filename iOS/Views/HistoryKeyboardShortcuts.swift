import SwiftUI

/// Hardware-keyboard navigation for the iOS History list (iPad Magic Keyboard
/// and any paired keyboard). Mirrors the Mac `HistoryListKeyboardShortcuts`
/// shape so cross-device muscle memory holds: arrows/J/K move, Home/End jump,
/// PageUp/PageDown leap ten, P pins, Return copies, / focuses search, Esc
/// peels back. macOS-only pieces (`.onDeleteCommand`, filter-digit shortcuts)
/// are intentionally absent — iOS has no filter bar and delete stays on
/// swipe/context menu.
struct HistoryKeyboardShortcuts: ViewModifier {
    let canHandle: () -> Bool
    let move: (Int) -> Void
    let jumpToTop: () -> Void
    let jumpToBottom: () -> Void
    let togglePin: () -> Void
    let copySelected: () -> Void
    let focusSearch: () -> Void
    let escape: () -> KeyPress.Result

    func body(content: Content) -> some View {
        content
            .onKeyPress(.downArrow) { step(1) }
            .onKeyPress(.upArrow) { step(-1) }
            .onKeyPress(characters: CharacterSet(charactersIn: "jJ")) { _ in step(1) }
            .onKeyPress(characters: CharacterSet(charactersIn: "kK")) { _ in step(-1) }
            .onKeyPress(.home) { run { jumpToTop() } }
            .onKeyPress(.end) { run { jumpToBottom() } }
            .onKeyPress(.pageUp) { step(-10) }
            .onKeyPress(.pageDown) { step(10) }
            .onKeyPress(characters: CharacterSet(charactersIn: "pP")) { _ in run { togglePin() } }
            .onKeyPress(.return) { run { copySelected() } }
            .onKeyPress(characters: CharacterSet(charactersIn: "/")) { _ in
                guard canHandle() else { return .ignored }
                focusSearch()
                return .handled
            }
            .onKeyPress(.escape) { escape() }
    }

    private func step(_ offset: Int) -> KeyPress.Result {
        run { move(offset) }
    }

    private func run(_ action: () -> Void) -> KeyPress.Result {
        guard canHandle() else { return .ignored }
        action()
        return .handled
    }
}
