import SwiftUI
import UIKit

/// Full-screen detail view for a clipboard item
struct ClipboardDetailView: View {
    let item: SharedClipboardItem
    let viewModel: ClipboardHistoryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showCopied = false

    private var isIPad: Bool { sizeClass == .regular }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: isIPad ? 28 : 16) {
                    // Content
                    contentView

                    // Metadata
                    metadataSection
                }
                .padding(isIPad ? 40 : 16)
            }
            .navigationTitle(contentTypeLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.copyToClipboard(item)
                        showCopied = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            showCopied = false
                        }
                    } label: {
                        Label(
                            showCopied ? "Copied" : "Copy",
                            systemImage: showCopied ? "checkmark" : "doc.on.doc"
                        )
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch item.content {
        case let .text(string):
            if item.isURL, let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                Link(destination: url) {
                    Text(string)
                        .font(isIPad ? .title2 : .body)
                        .foregroundStyle(.teal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(string)
                    .font(isIPad
                        ? (item.isCode ? .system(size: 22, design: .monospaced) : .title2)
                        : (item.isCode ? .system(.body, design: .monospaced) : .body))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(isIPad ? 28 : 16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: isIPad ? 14 : 8))
            }
        case let .imageData(data, width, height):
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: isIPad ? 14 : 8))
                    .overlay(alignment: .bottomTrailing) {
                        Text("\(width)×\(height)")
                            .font(isIPad ? .callout : .caption2)
                            .padding(isIPad ? 8 : 4)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(isIPad ? 12 : 6)
                    }
            }
        }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 16 : 8) {
            Divider()

            if let source = item.sourceAppName {
                metadataRow(icon: "app", label: "Source", value: source)
            }

            if !item.deviceName.isEmpty {
                metadataRow(icon: "desktopcomputer", label: "Device", value: item.deviceName)
            }

            metadataRow(
                icon: "clock",
                label: "Copied",
                value: item.timestamp.formatted(date: .abbreviated, time: .shortened)
            )

            if item.pasteCount > 0 {
                metadataRow(icon: "doc.on.doc", label: "Pasted", value: "\(item.pasteCount) times")
            }

            if case let .text(string) = item.content {
                metadataRow(icon: "character.cursor.ibeam", label: "Length", value: "\(string.count) characters")
            }
        }
    }

    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: isIPad ? 16 : 8) {
            Image(systemName: icon)
                .font(.system(size: isIPad ? 18 : 13))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: isIPad ? 26 : 18, alignment: .center)
            Text(label)
                .font(.system(size: isIPad ? 22 : 15))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: isIPad ? 180 : 100, alignment: .leading)
            Text(value)
                .font(.system(size: isIPad ? 22 : 15))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    // MARK: - Helpers

    private var contentTypeLabel: String {
        switch item.content {
        case .text:
            if item.isURL { return "Link" }
            if item.isCode { return "Code" }
            return "Text"
        case .imageData:
            return "Image"
        }
    }
}
