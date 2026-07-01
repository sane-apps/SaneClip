import SwiftUI

/// Bundles the history list's keyboard navigation into one ViewModifier.
///
/// Kept out of `ClipboardHistoryView.body` (and out of the `historyList`
/// property) so this long `.onKeyPress` chain type-checks as its own unit —
/// inline, it pushed the SwiftUI body over the compiler's type-check budget.
struct HistoryListKeyboardShortcuts: ViewModifier {
    let canHandle: () -> Bool
    let move: (Int) -> Void
    let jumpToTop: () -> Void
    let jumpToBottom: () -> Void
    let selectContentFilter: (String) -> Void
    let togglePin: () -> Void
    let paste: () -> Void
    let focusSearch: () -> Void
    let escape: () -> KeyPress.Result
    let delete: () -> Void

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
            .onKeyPress(characters: CharacterSet(charactersIn: "12345")) { keyPress in
                guard canHandle() else { return .ignored }
                selectContentFilter(keyPress.characters)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "pP")) { _ in run { togglePin() } }
            .onKeyPress(.return) { run { paste() } }
            .onKeyPress(characters: CharacterSet(charactersIn: "/")) { _ in
                focusSearch()
                return .handled
            }
            .onKeyPress(.escape) { escape() }
            .onDeleteCommand {
                guard canHandle() else { return }
                delete()
            }
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
