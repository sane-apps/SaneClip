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
                    .foregroundStyle(.primary.opacity(0.9))
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
                .foregroundStyle(.secondary)
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
            .foregroundStyle(.secondary)

            if clipboardManager.pasteStack.isEmpty {
                Text("Paste stack is empty.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title?.isEmpty == false ? item.title! : item.preview)
                        .lineLimit(1)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .lineLimit(1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Paste") {
                    clipboardManager.pasteFromStackItem(id: item.id)
                }
                .buttonStyle(.plain)
                .font(.caption)
                Button("Top") {
                    clipboardManager.movePasteStackItemToTop(id: item.id)
                }
                .buttonStyle(.plain)
                .font(.caption)
                Button {
                    clipboardManager.movePasteStackItemUp(id: item.id)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Move up")
                Button {
                    clipboardManager.movePasteStackItemDown(id: item.id)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Move down")
                Button(editingStackTitleID == item.id ? "Save Title" : "Rename") {
                    if editingStackTitleID == item.id {
                        clipboardManager.updateItemTitle(id: item.id, title: stackTitleDraft)
                        editingStackTitleID = nil
                    } else {
                        editingStackTitleID = item.id
                        stackTitleDraft = item.title ?? ""
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                Button(editingStackNoteID == item.id ? "Save Note" : "Note") {
                    if editingStackNoteID == item.id {
                        clipboardManager.updateItemNote(id: item.id, note: stackNoteDraft)
                        editingStackNoteID = nil
                    } else {
                        editingStackNoteID = item.id
                        stackNoteDraft = item.note ?? ""
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                Button {
                    clipboardManager.removeFromPasteStack(id: item.id)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Remove from stack")
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
}
