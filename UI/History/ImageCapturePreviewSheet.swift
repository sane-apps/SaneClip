import AppKit
import SwiftUI

struct ImageCapturePreviewSheet: View {
    let item: ClipboardItem
    let clipboardManager: ClipboardManager
    @Environment(\.dismiss) private var dismiss

    private var image: NSImage? {
        if case let .image(image) = item.content {
            return image
        }
        return nil
    }

    private var ocrText: String {
        item.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                imagePreview
                    .frame(minWidth: 460, minHeight: 360)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Recognized Text")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if ocrText.isEmpty {
                        ContentUnavailableView("No Text Found", systemImage: "text.viewfinder")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            Text(ocrText)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                    }
                }
                .frame(width: 320)
            }
            .padding(18)

            Divider()

            HStack {
                Text(item.sourceAppName ?? "Screen Capture")
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.75))
                Spacer()
                Button("Copy Image") {
                    clipboardManager.copyWithoutPaste(item: item, notifyUser: true)
                }
                Button("Copy OCR Text") {
                    clipboardManager.copyOCRTextWithoutPaste(item: item, notifyUser: true)
                }
                .disabled(ocrText.isEmpty)
                Button("Save As...") {
                    clipboardManager.exportImageAsPNG(item: item)
                }
                Button("Delete", role: .destructive) {
                    clipboardManager.delete(item: item)
                    dismiss()
                }
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 840, minHeight: 520)
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(12)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.14), lineWidth: 1)
                )
        } else {
            ContentUnavailableView("Image Unavailable", systemImage: "photo")
        }
    }
}
