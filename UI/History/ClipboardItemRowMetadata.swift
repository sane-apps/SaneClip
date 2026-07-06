import SaneUI
import SwiftUI

/// Adaptive metadata/action strip for a history row.
///
/// Glenn's minimum-width hover video showed the old row letting source text,
/// stats, shortcut badges, preview, and collection chips compete in one fixed
/// line. This view keeps the important controls reachable while progressively
/// dropping nonessential labels at tight widths instead of distorting the row.
struct ClipboardItemRowMetadata: View {
    let item: ClipboardItem
    let accentColor: Color
    let showsDragAffordance: Bool
    let shortcutHint: String?
    let onPreviewImage: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(showSourceName: true, showCollection: true)
            row(showSourceName: true, showCollection: false)
            row(showSourceName: false, showCollection: false)
        }
    }

    private var isImageItem: Bool {
        if case .image = item.content { return true }
        return false
    }

    private var sourceName: String? {
        guard let name = item.sourceAppName, !name.isEmpty else { return nil }
        return name
    }

    private func row(showSourceName: Bool, showCollection: Bool) -> some View {
        HStack(spacing: 6) {
            sourceCluster(showName: showSourceName)
            timeCluster

            Spacer(minLength: 4)

            if showsDragAffordance {
                Image(systemName: "line.3.horizontal")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
                    .help("Drag to another app")
            }

            if let shortcutHint {
                Text(shortcutHint)
                    .font(.system(.caption2, design: .monospaced))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 4)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(4)
            }

            if isImageItem {
                Button(action: onPreviewImage) {
                    Image(systemName: "eye")
                        .font(.caption)
                        .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
                .help("Preview image")
            }

            if showCollection, item.collection != "Default" {
                collectionChip
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private func sourceCluster(showName: Bool) -> some View {
        if let icon = item.sourceAppIcon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 14, height: 14)
        }

        if showName, let sourceName {
            Text(sourceName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 58, maxWidth: 132, alignment: .leading)
                .foregroundStyle(.white.opacity(0.9))
            Text("·")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        } else if isImageItem, item.sourceAppIcon == nil {
            Image(systemName: "photo")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var timeCluster: some View {
        HStack(spacing: 6) {
            Text(item.timeAgo)
                .font(.caption)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(.white.opacity(0.9))

            if item.pasteCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                    Text("\(item.pasteCount)")
                        .font(.caption2)
                }
                .foregroundStyle(Color.semanticSuccess.opacity(0.85))
                .fixedSize(horizontal: true, vertical: false)
                .help("Pasted \(item.pasteCount) time\(item.pasteCount == 1 ? "" : "s")")
            }
        }
    }

    private var collectionChip: some View {
        Text(item.collection)
            .font(.system(size: 10, weight: .medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .frame(maxWidth: 82)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
    }
}
