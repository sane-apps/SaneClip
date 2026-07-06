import SaneUI
import SwiftUI

/// The expandable Paste Stack management panel shown beneath the history list.
///
/// Extracted from `ClipboardHistoryView` to keep that view under the component
/// size limit. Presentation (the `isPro`/`showPasteStackPanel` guard and the
/// leading divider) stays with the parent; this view renders the panel body.
struct HistoryPasteStackPanel: View {
    var clipboardManager: ClipboardManager
    @Binding var editingStackTitleID: UUID?
    @Binding var editingStackNoteID: UUID?
    @Binding var stackTitleDraft: String
    @Binding var stackNoteDraft: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Paste Stack")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                // Build-by-copying: while on, every copy is appended to the
                // stack. Uses the stack's own violet so the color still means
                // "paste stack"; the filled dot carries the on/off state.
                Button {
                    clipboardManager.setStackRecording(!clipboardManager.isRecordingStack)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: clipboardManager.isRecordingStack ? "record.circle.fill" : "record.circle")
                        Text(clipboardManager.isRecordingStack ? "Recording copies" : "Record copies")
                    }
                    .font(.caption)
                    .foregroundStyle(clipboardManager.isRecordingStack ? Color.stackViolet : .white.opacity(0.9))
                }
                .buttonStyle(.plain)
                .help("Automatically add every copy to the stack, in order")

                Spacer()
                Toggle("Pause", isOn: Binding(
                    get: { SettingsModel.shared.pausePasteStackConsumption },
                    set: { SettingsModel.shared.pausePasteStackConsumption = $0 }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .help("Pause consuming the stack")
                Button("Undo") {
                    clipboardManager.undoLastPasteFromStack()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .disabled(!clipboardManager.canUndoLastStackPaste)
                Button("Clear") {
                    clipboardManager.clearPasteStack()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            }

            HStack(spacing: 10) {
                Toggle("Keep open while consuming", isOn: Binding(
                    get: { SettingsModel.shared.keepPasteStackOpenBetweenPastes },
                    set: { SettingsModel.shared.keepPasteStackOpenBetweenPastes = $0 }
                ))
                .toggleStyle(.checkbox)
                Toggle("Auto-close when empty", isOn: Binding(
                    get: { SettingsModel.shared.autoClosePasteStackWhenEmpty },
                    set: { SettingsModel.shared.autoClosePasteStackWhenEmpty = $0 }
                ))
                .toggleStyle(.checkbox)
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.9))

            if clipboardManager.pasteStack.isEmpty {
                Text(clipboardManager.isRecordingStack
                    ? "Recording — the next things you copy land here, in order."
                    : "Paste stack is empty. Turn on \u{201C}Record copies\u{201D} to build one as you copy, or use \u{201C}Add to Paste Stack\u{201D} on any clip.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            } else {
                List {
                    ForEach(Array(clipboardManager.pasteStack.enumerated()), id: \.element.id) { index, item in
                        stackRow(index: index, item: item)
                    }
                    .onMove { source, destination in
                        clipboardManager.movePasteStackItems(from: source, to: destination)
                    }
                }
                .frame(height: min(220, CGFloat(max(2, clipboardManager.pasteStack.count)) * 44))
                .listStyle(.plain)
            }
        }
        .padding(8)
        .background(.background.tertiary)
    }

    private func stackRow(index: Int, item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("#\(index + 1)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 24, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title?.isEmpty == false ? item.title! : item.preview)
                        .lineLimit(1)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .lineLimit(1)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                stackRowActions(for: item)
            }

            if editingStackTitleID == item.id {
                TextField("Title", text: $stackTitleDraft)
                    .textFieldStyle(.roundedBorder)
            }
            if editingStackNoteID == item.id {
                TextField("Note", text: $stackNoteDraft)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func stackRowActions(for item: ClipboardItem) -> some View {
        HStack(spacing: 8) {
            stackIconButton("return", "Paste this stack item", color: .stackViolet) {
                clipboardManager.pasteFromStackItem(id: item.id)
            }
            stackIconButton("arrow.up.to.line", "Move to top") {
                clipboardManager.movePasteStackItemToTop(id: item.id)
            }
            stackIconButton("arrow.up", "Move up") {
                clipboardManager.movePasteStackItemUp(id: item.id)
            }
            stackIconButton("arrow.down", "Move down") {
                clipboardManager.movePasteStackItemDown(id: item.id)
            }
            stackIconButton(
                editingStackTitleID == item.id ? "checkmark" : "pencil",
                editingStackTitleID == item.id ? "Save title" : "Rename"
            ) {
                if editingStackTitleID == item.id {
                    clipboardManager.updateItemTitle(id: item.id, title: stackTitleDraft)
                    editingStackTitleID = nil
                } else {
                    editingStackTitleID = item.id
                    stackTitleDraft = item.title ?? ""
                }
            }
            stackIconButton(
                editingStackNoteID == item.id ? "checkmark.circle" : "note.text",
                editingStackNoteID == item.id ? "Save note" : "Edit note"
            ) {
                if editingStackNoteID == item.id {
                    clipboardManager.updateItemNote(id: item.id, note: stackNoteDraft)
                    editingStackNoteID = nil
                } else {
                    editingStackNoteID = item.id
                    stackNoteDraft = item.note ?? ""
                }
            }
            stackIconButton("xmark.circle", "Remove from stack") {
                clipboardManager.removeFromPasteStack(id: item.id)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func stackIconButton(
        _ systemImage: String,
        _ help: String,
        color: Color = .white.opacity(0.9),
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption)
                .frame(width: 14, height: 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
        .help(help)
        .accessibilityLabel(help)
    }
}
