import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isPinned: Bool
    let clipboardManager: ClipboardManager
    var shortcutHint: String?
    var isSelected: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var showEditSheet = false
    @State private var editText = ""

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts: [String] = []

        // Content type and preview
        if case .image = item.content {
            parts.append("Image")
        } else if item.isURL {
            parts.append("Link: \(item.preview)")
        } else if item.isCode {
            parts.append("Code: \(item.preview)")
        } else {
            parts.append(item.preview)
        }

        // Pinned status
        if isPinned {
            parts.append("Pinned")
        }

        // Source app
        if let appName = item.sourceAppName {
            parts.append("from \(appName)")
        }

        // Paste count
        if item.pasteCount > 0 {
            parts.append("pasted \(item.pasteCount) time\(item.pasteCount == 1 ? "" : "s")")
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - Source-Aware Colors (matches iOS ClipboardItemCell palette)

    /// Harmonious muted palette — each hue family is distinct, no two colors clash.
    /// Dark mode: bright/saturated. Light mode: darkened for WCAG AA on light backgrounds.
    private var sourceColor: Color {
        guard let source = item.sourceAppName?.lowercased() else { return Color.clipBlue }
        if colorScheme == .dark {
            switch source {
            case "messages": return Color(hex: 0x5EC2A0)
            case "mail": return Color(hex: 0xE8807C)
            case "safari": return Color(hex: 0x6BADE4)
            case "notes": return Color(hex: 0xE4C05C)
            case "maps": return Color(hex: 0x4B9FE8)
            case "contacts": return Color(hex: 0xC8ACE4)
            case "calendar": return Color(hex: 0xD4849A)
            case "photos": return Color(hex: 0xE89A3C)
            case "reminders": return Color(hex: 0x8A9FE4)
            case "terminal": return Color(hex: 0x66E08E) // Lime green
            case "xcode": return Color(hex: 0x6B7FE8) // Indigo
            case "finder": return Color(hex: 0x4DD4D4) // Cyan
            case "slack": return Color(hex: 0xD464CC) // Fuchsia
            default: return Color.clipBlue
            }
        } else {
            switch source {
            case "messages": return Color(hex: 0x2E8B6A)
            case "mail": return Color(hex: 0xC4524E)
            case "safari": return Color(hex: 0x3A7DB8)
            case "notes": return Color(hex: 0x9E8528)
            case "maps": return Color(hex: 0x2D7AC2)
            case "contacts": return Color(hex: 0x7A5FA8)
            case "calendar": return Color(hex: 0xA8566E)
            case "photos": return Color(hex: 0xB87A22)
            case "reminders": return Color(hex: 0x4E62A8)
            case "terminal": return Color(hex: 0x2D8A4E) // Deep lime
            case "xcode": return Color(hex: 0x4450A8) // Deep indigo
            case "finder": return Color(hex: 0x2A8FA8) // Deep cyan
            case "slack": return Color(hex: 0xA03898) // Deep fuchsia
            default: return Color.clipBlue
            }
        }
    }

    /// Bar color: orange for pinned, source color otherwise
    private var barColor: Color {
        isPinned ? .pinnedOrange : sourceColor
    }

    /// Accent for icons and source labels: always source-aware, even on pinned items
    private var accentColor: Color {
        sourceColor
    }

    private var cardBackground: Color {
        // Hover and selection both use the same subtle highlight
        // Selection is distinguished by border, not fill
        if isHovering || isSelected {
            return colorScheme == .dark
                ? Color.white.opacity(0.12)
                : Color.black.opacity(0.06)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.03)
    }

    // Improved font selection: Monospaced for code
    private var itemFont: Font {
        item.isCode ? .system(.callout, design: .monospaced) : .system(.callout, weight: .medium)
    }

    // Content-type icon for faster visual scanning
    @ViewBuilder
    private var contentTypeIcon: some View {
        if case .image = item.content {
            Image(systemName: "photo")
        } else if item.isURL {
            Image(systemName: "link")
        } else if item.isCode {
            Image(systemName: "curlybraces")
        } else {
            Image(systemName: "text.alignleft")
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Accent bar on left — orange for pinned, source color otherwise
            RoundedRectangle(cornerRadius: 2)
                .fill(barColor)
                .frame(width: 3)

            HStack(alignment: .top, spacing: 8) {
                // Pin indicator
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }

                // Content & metadata stacked
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        // Content-type icon for faster scanning
                        contentTypeIcon
                            .font(.caption)
                            .foregroundStyle(accentColor)
                            .frame(width: 14)

                        Text(item.preview)
                            .lineLimit(3)
                            .font(itemFont)
                            .foregroundStyle(.primary)
                    }

                    // Metadata line - fixed columns for alignment
                    HStack(spacing: 12) { // Increased spacing
                        // Source app icon
                        if let icon = item.sourceAppIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                                .help(item.sourceAppName ?? "Unknown app")
                        }

                        // Stats with icons
                        HStack(spacing: 4) {
                            if case .image = item.content {
                                Image(systemName: "photo")
                                    .font(.caption2)
                            }
                            Text(item.stats)
                                .font(.caption)
                        }
                        .foregroundStyle(.primary.opacity(0.7))

                        // Time ago
                        Text(item.timeAgo)
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.5))

                        // Paste count badge
                        if item.pasteCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 9))
                                Text("\(item.pasteCount)")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.green.opacity(0.8))
                            .help("Pasted \(item.pasteCount) time\(item.pasteCount == 1 ? "" : "s")")
                        }

                        Spacer()

                        if let hint = shortcutHint {
                            Text(hint)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.55))
                                .padding(.horizontal, 4)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(4)
                        }
                    }
                    .lineLimit(1)
                }

                Spacer(minLength: 4)
            }
            .padding(.vertical, 12)
            .padding(.leading, 10)
            .padding(.trailing, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .opacity(isHovering || isSelected ? 1.0 : 0.7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accentColor.opacity(isSelected ? 0.4 : 0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            clipboardManager.paste(item: item)
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .contextMenu {
            Button("Paste") { clipboardManager.paste(item: item) }
            Button("Paste as Plain Text") { clipboardManager.pasteAsPlainText(item: item) }

            // Text transform options (only for text content)
            if case .text = item.content {
                Menu("Paste As...") {
                    ForEach(TextTransform.allCases, id: \.self) { transform in
                        Button(transform.displayName) {
                            clipboardManager.pasteWithTransform(item: item, transform: transform)
                        }
                    }
                }
            }

            Divider()

            // Copy without paste
            Button("Copy") {
                clipboardManager.copyWithoutPaste(item: item)
            }

            // Share menu
            Button("Share...") {
                shareItem()
            }

            // Save as PDF (text only)
            if case .text = item.content {
                Button("Save as PDF...") {
                    clipboardManager.exportItemAsPDF(item: item)
                }
            }

            // Open Link (for URLs only)
            if item.isURL, case let .text(urlString) = item.content,
               let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                Button("Open Link") {
                    NSWorkspace.shared.open(url)
                }
            }

            // Edit (text only)
            if case let .text(text) = item.content {
                Button("Edit...") {
                    editText = text
                    showEditSheet = true
                }
            }

            Divider()
            Button("Add to Paste Stack") {
                clipboardManager.addToPasteStack(item)
            }
            Divider()
            Button(isPinned ? "Unpin" : "Pin") {
                clipboardManager.togglePin(item: item)
            }
            Divider()
            Button("Delete", role: .destructive) { clipboardManager.delete(item: item) }
        }
        .sheet(isPresented: $showEditSheet) {
            EditClipboardItemSheet(
                text: $editText,
                onSave: {
                    clipboardManager.updateItemContent(id: item.id, newContent: editText)
                    showEditSheet = false
                },
                onCancel: {
                    showEditSheet = false
                }
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to paste")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Share Helper

    private func shareItem() {
        var shareContent: Any? = switch item.content {
        case let .text(string):
            string
        case let .image(image):
            image
        }

        guard let content = shareContent else { return }

        let picker = NSSharingServicePicker(items: [content])
        if let window = NSApp.keyWindow, let contentView = window.contentView {
            picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        }
    }
}

// MARK: - Edit Clipboard Item Sheet

struct EditClipboardItemSheet: View {
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Clipboard Item")
                .font(.headline)

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 400, minHeight: 200)
                .border(Color.secondary.opacity(0.3), width: 1)

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 450, minHeight: 300)
    }
}

// MARK: - Paste Button Style with Dramatic Press Feedback

struct PasteButtonStyle: ButtonStyle {
    let accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(
                Circle()
                    .fill(configuration.isPressed ? accentColor : accentColor.opacity(0.1))
            )
            .foregroundStyle(configuration.isPressed ? .white : accentColor)
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .shadow(color: configuration.isPressed ? accentColor.opacity(0.4) : .clear, radius: 4)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
