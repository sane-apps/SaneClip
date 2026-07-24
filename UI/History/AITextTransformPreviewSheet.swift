import SaneUI
import SwiftUI

struct AITextTransformRequest: Identifiable {
    let id = UUID()
    let action: AITextAction
    let sourceText: String
}

enum AITextTransformPhase: Equatable {
    case loading
    case result(String)
    case unavailable(String)
    case failed(String)
}

@MainActor
@Observable
final class AITextTransformPreviewModel {
    private(set) var phase: AITextTransformPhase = .loading
    private(set) var actionErrorMessage: String?

    var isLoading: Bool {
        phase == .loading
    }

    var resultText: String? {
        guard case let .result(text) = phase else { return nil }
        return text
    }

    private let generator: any AITextGenerating
    private var generationTask: Task<Void, Never>?
    private var activeRequestID: UUID?

    init(generator: any AITextGenerating = AITextGeneratorFactory.make()) {
        self.generator = generator
    }

    func start(action: AITextAction, text: String) {
        guard generationTask == nil else { return }

        let requestID = UUID()
        activeRequestID = requestID
        actionErrorMessage = nil
        phase = .loading
        generationTask = Task { [weak self] in
            guard let self else { return }

            do {
                try AITextInputPolicy.validate(text)
            } catch let error as AITextGenerationError {
                finish(.failed(error.userMessage), requestID: requestID)
                return
            } catch {
                finish(.failed(AITextGenerationError.generationFailed.userMessage), requestID: requestID)
                return
            }

            let availability = await generator.availability()
            guard !Task.isCancelled else { return }
            if case let .unavailable(reason) = availability {
                finish(.unavailable(reason.userMessage), requestID: requestID)
                return
            }

            do {
                let result = try await generator.generate(action: action, text: text)
                guard !Task.isCancelled else { return }
                finish(.result(result), requestID: requestID)
            } catch is CancellationError {
                return
            } catch let AITextGenerationError.unavailable(reason) {
                finish(.unavailable(reason.userMessage), requestID: requestID)
            } catch let error as AITextGenerationError {
                finish(.failed(error.userMessage), requestID: requestID)
            } catch {
                finish(.failed(AITextGenerationError.generationFailed.userMessage), requestID: requestID)
            }
        }
    }

    func cancel() {
        activeRequestID = nil
        generationTask?.cancel()
        generationTask = nil
        actionErrorMessage = nil
    }

    func showActionFailure() {
        actionErrorMessage = "SaneClip could not apply that result. Try again."
    }

    private func finish(_ newPhase: AITextTransformPhase, requestID: UUID) {
        guard activeRequestID == requestID else { return }
        activeRequestID = nil
        generationTask = nil
        actionErrorMessage = nil
        phase = newPhase
    }
}

struct AITextTransformPreviewSheet: View {
    let request: AITextTransformRequest
    let clipboardManager: ClipboardManager

    @Environment(\.dismiss) private var dismiss
    @State private var model: AITextTransformPreviewModel

    init(
        request: AITextTransformRequest,
        clipboardManager: ClipboardManager,
        generator: any AITextGenerating = AITextGeneratorFactory.make()
    ) {
        self.request = request
        self.clipboardManager = clipboardManager
        _model = State(initialValue: AITextTransformPreviewModel(generator: generator))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(20)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            footer
                .padding(20)
        }
        .frame(width: 520, height: 420)
        .background(Color.black.opacity(0.94))
        .task {
            model.start(action: request.action, text: request.sourceText)
        }
        .onDisappear {
            model.cancel()
        }
        .interactiveDismissDisabled()
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.saneAccent)
            VStack(alignment: .leading, spacing: 3) {
                Text(request.action.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("AI — On Device")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("Working entirely on this Mac…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .result(text):
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(text)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }

                if let actionErrorMessage = model.actionErrorMessage {
                    Text(actionErrorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
            }

        case let .unavailable(message):
            statusView(icon: "sparkles", title: "On-Device AI Unavailable", message: message)

        case let .failed(message):
            statusView(icon: "exclamationmark.triangle.fill", title: "Couldn’t Generate Result", message: message)
        }
    }

    private func statusView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Cancel") {
                model.cancel()
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(ClipActionButtonStyle(compact: true))
            .help("Close without copying the generated text")

            Spacer()

            if let result = model.resultText {
                Button("Copy") {
                    if clipboardManager.copyTextWithoutPaste(result) {
                        dismiss()
                    } else {
                        model.showActionFailure()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(ClipActionButtonStyle(prominent: true, compact: true))
                .help("Copy the generated text without changing clipboard history")
            }
        }
    }
}
