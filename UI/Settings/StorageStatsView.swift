import SwiftUI

/// Storage statistics view showing clipboard history stats and breakdown
struct StorageStatsView: View {
    @State private var historyCount: Int = 0
    @State private var pinnedCount: Int = 0
    @State private var fileSize: String = "Calculating..."
    @State private var itemsByType: [(String, Int)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stats cards
            HStack(spacing: 12) {
                StatCard(title: "Total Items", value: "\(historyCount)", icon: "doc.on.doc")
                StatCard(title: "Pinned", value: "\(pinnedCount)", icon: "pin.fill")
                StatCard(title: "Storage", value: fileSize, icon: "internaldrive")
            }

            // Items by type breakdown
            if !itemsByType.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Items by Type")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(itemsByType, id: \.0) { type, count in
                        HStack {
                            Image(systemName: iconForType(type))
                                .frame(width: 20)
                                .foregroundStyle(clipReadableSecondary)
                            Text(type)
                            Spacer()
                            Text("\(count)")
                                .foregroundStyle(clipReadableSecondary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.fill.quaternary)
                )
            }

            Spacer()
        }
        .onAppear { calculateStats() }
    }

    private func calculateStats() {
        Task { @MainActor in
            guard let manager = ClipboardManager.shared else { return }
            historyCount = manager.history.count
            pinnedCount = manager.pinnedItems.count

            // Calculate file size
            let historyPath = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first?.appendingPathComponent("SaneClip/history.json")

            if let path = historyPath,
               let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
               let size = attrs[.size] as? Int64 {
                fileSize = formatBytes(size)
            } else {
                fileSize = "0 KB"
            }

            // Count items by type
            var typeCounts: [String: Int] = [:]
            for item in manager.history {
                switch item.content {
                case .text(let string):
                    if item.isURL {
                        typeCounts["Links", default: 0] += 1
                    } else if item.isCode {
                        typeCounts["Code", default: 0] += 1
                    } else if string.count > 500 {
                        typeCounts["Long Text", default: 0] += 1
                    } else {
                        typeCounts["Text", default: 0] += 1
                    }
                case .image:
                    typeCounts["Images", default: 0] += 1
                }
            }

            itemsByType = typeCounts.sorted { $0.value > $1.value }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "Links": return "link"
        case "Code": return "chevron.left.forwardslash.chevron.right"
        case "Images": return "photo"
        case "Long Text": return "doc.text"
        default: return "text.alignleft"
        }
    }
}

/// Individual stat card for displaying a single metric
private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.clipBlue)

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()

            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(clipReadableSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark
                    ? Color.white.opacity(0.08)
                    : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(colorScheme == .dark
                    ? Color.white.opacity(0.12)
                    : Color.clipBlue.opacity(0.15), lineWidth: 1
            )
        )
    }
}
