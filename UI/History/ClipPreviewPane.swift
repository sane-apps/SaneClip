import SaneUI
import SwiftUI

/// Right-hand preview of the selected clip, shown on the floating history
/// window when it is wide enough. It answers the "which clip is this?"
/// question — the second thing anyone wants from a clipboard manager — with the
/// full content plus the metadata people actually choose by: which app it came
/// from, its type, when it was captured, and how often it has been pasted.
///
/// The menu-bar popover and any narrow floating window stay single-column; this
/// pane only appears once the window is wide enough to hold both comfortably.
struct ClipPreviewPane: View {
    let item: ClipboardItem?
    let clipboardManager: ClipboardManager
    var licenseService: LicenseService?

    @Environment(\.colorScheme) private var colorScheme
    private var isPro: Bool {
        licenseService?.isPro == true
    }

    var body: some View {
        Group {
            if let item {
                filled(item)
            } else {
                ContentUnavailableView(
                    "No clip selected",
                    systemImage: "sidebar.squares.right",
                    description: Text("Choose a clip to preview it here")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.03))
    }

    // MARK: - Type helpers

    private func typeLabel(_ item: ClipboardItem) -> String {
        if case .image = item.content { return "Image" }
        if item.isURL { return "Link" }
        if item.isCode { return "Code" }
        return "Text"
    }

    private func typeIcon(_ item: ClipboardItem) -> String {
        if case .image = item.content { return "photo" }
        if item.isURL { return "link" }
        if item.isCode { return "curlybraces" }
        return "text.alignleft"
    }

    private func accent(_ item: ClipboardItem) -> Color {
        SaneClipSourceColor.color(forSourceNamed: item.sourceAppName, dark: colorScheme == .dark)
    }

    // MARK: - Filled

    private func filled(_ item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header(item)
            contentBlock(item)
            metadata(item)
            Spacer(minLength: 0)
            actions(item)
        }
        .padding(18)
    }

    private func header(_ item: ClipboardItem) -> some View {
        HStack(spacing: 10) {
            if let icon = item.sourceAppIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(accent(item))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: typeIcon(item))
                            .font(.caption)
                            .foregroundStyle(.white)
                    )
            }

            Text((item.title?.isEmpty == false ? item.title : nil) ?? item.preview)
                .font(.system(.headline, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            // Type badge is neutral — source hue means "which app", never
            // "what type", so type carries no identity color.
            Text(typeLabel(item).uppercased())
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.secondary.opacity(0.35), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func contentBlock(_ item: ClipboardItem) -> some View {
        switch item.content {
        case let .text(string):
            ScrollView {
                Text(string)
                    .font(item.isCode ? .system(.callout, design: .monospaced) : .callout)
                    .textSelection(.enabled)
                    .foregroundStyle(item.isURL ? Color.clipBlue : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 220)
            .background(RoundedRectangle(cornerRadius: 9).fill(.black.opacity(0.25)))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.08), lineWidth: 1))
        case let .image(nsImage):
            ScrollView {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding(8)
            }
            .frame(maxHeight: 240)
            .background(RoundedRectangle(cornerRadius: 9).fill(.black.opacity(0.25)))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.08), lineWidth: 1))
        }
    }

    private func metadata(_ item: ClipboardItem) -> some View {
        VStack(spacing: 9) {
            metaRow("Source app", item.sourceAppName ?? "Unknown")
            metaRow("Type", "\(typeLabel(item)) · \(item.stats)")
            metaRow("Captured", capturedString(item))
            if item.pasteCount > 0 {
                metaRow("Pasted", "\(item.pasteCount) time\(item.pasteCount == 1 ? "" : "s")")
            }
            if item.collection != "Default" {
                metaRow("Collection", item.collection)
            }
            if !item.tags.isEmpty {
                metaRow("Tags", item.tags.map { "#\($0)" }.joined(separator: " "))
            }
            if let note = item.note, !note.isEmpty {
                metaRow("Note", note)
            }
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.9))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private func capturedString(_ item: ClipboardItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return "\(item.timeAgo) · \(formatter.string(from: item.timestamp))"
    }

    private func actions(_ item: ClipboardItem) -> some View {
        HStack(spacing: 8) {
            Button {
                _ = clipboardManager.pasteFromHistory(item: item)
            } label: {
                Label("Paste", systemImage: "return")
                    .font(.system(.callout, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.clipBlue, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            if isPro {
                pill("Plain text") { _ = clipboardManager.pasteAsPlainText(item: item) }
            }
            pill(clipboardManager.isPinned(item) ? "Unpin" : "Pin") {
                clipboardManager.togglePin(item: item)
            }
        }
    }

    private func pill(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(.primary.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
