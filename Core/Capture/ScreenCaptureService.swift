import AppKit
import Foundation
import OSLog
@preconcurrency import ScreenCaptureKit

enum ScreenCaptureError: LocalizedError {
    case captureAlreadyInProgress
    case cancelled
    case timedOut
    case pickerStartFailed
    case imageUnavailable
    case invalidImage
    case noRecognizedText

    var errorDescription: String? {
        switch self {
        case .captureAlreadyInProgress:
            "A capture is already in progress."
        case .cancelled:
            nil
        case .timedOut:
            "The capture picker timed out. Try again."
        case .pickerStartFailed:
            "SaneClip couldn't start the capture picker."
        case .imageUnavailable:
            "SaneClip couldn't capture the selected content."
        case .invalidImage:
            "SaneClip couldn't process the captured image."
        case .noRecognizedText:
            "No text was found in the captured content."
        }
    }
}

private final class CaptureResumeGate<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<Value, Error>

    init(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Swift.Result<Value, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true

        switch result {
        case let .success(value):
            continuation.resume(returning: value)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }
}

final class ScreenCaptureService: NSObject, SCContentSharingPickerObserver, @unchecked Sendable {
    struct CaptureResult: Sendable {
        let image: NSImage
        let sourceAppBundleID: String?
        let sourceAppName: String?
    }

    private typealias CaptureContinuation = CheckedContinuation<CaptureResult, Error>
    nonisolated static let captureTimeoutNanoseconds: UInt64 = 600 * 1_000_000_000
    nonisolated static let pickerDismissalDelayNanoseconds: UInt64 = 200_000_000
    nonisolated static let stillCaptureTimeoutNanoseconds: UInt64 = 5 * 1_000_000_000

    private let picker = SCContentSharingPicker.shared
    private let logger = Logger(subsystem: "com.saneclip.app", category: "Capture")
    private var continuation: CaptureContinuation?
    private var captureTimeoutTask: Task<Void, Never>?
    private var isResolvingSelection = false

    override init() {
        super.init()
        picker.add(self)
    }

    deinit {
        picker.remove(self)
    }

    @MainActor
    func captureImage() async throws -> CaptureResult {
        guard continuation == nil else {
            if !isResolvingSelection {
                picker.present()
            }
            throw ScreenCaptureError.captureAlreadyInProgress
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.isResolvingSelection = false

            var configuration = SCContentSharingPickerConfiguration()
            configuration.allowedPickerModes = [.singleWindow, .singleDisplay]
            configuration.excludedBundleIDs = Bundle.main.bundleIdentifier.map { [$0] } ?? []
            configuration.allowsChangingSelectedContent = false

            picker.defaultConfiguration = configuration
            picker.maximumStreamCount = 1
            picker.isActive = true
            picker.present()
            startCaptureTimeout()
        }
    }

    nonisolated func contentSharingPicker(_: SCContentSharingPicker, didCancelFor _: SCStream?) {
        Task { @MainActor in
            self.finish(with: .failure(ScreenCaptureError.cancelled))
        }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        Task { @MainActor in
            self.finish(with: .failure(error))
        }
    }

    nonisolated func contentSharingPicker(
        _: SCContentSharingPicker,
        didUpdateWith filter: SCContentFilter,
        for _: SCStream?
    ) {
        Task { @MainActor in
            guard self.continuation != nil, !self.isResolvingSelection else { return }
            self.isResolvingSelection = true
            self.captureSelectedContent(from: filter)
        }
    }

    @MainActor
    private func finish(with result: Swift.Result<CaptureResult, Error>) {
        captureTimeoutTask?.cancel()
        captureTimeoutTask = nil
        isResolvingSelection = false
        picker.isActive = false

        guard let continuation else { return }
        self.continuation = nil

        switch result {
        case let .success(value):
            continuation.resume(returning: value)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }

    @MainActor
    private func startCaptureTimeout() {
        captureTimeoutTask?.cancel()
        captureTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.captureTimeoutNanoseconds)
            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                guard let self, self.continuation != nil else { return }
                self.finish(with: .failure(ScreenCaptureError.timedOut))
            }
        }
    }

    @MainActor
    private func captureSelectedContent(from filter: SCContentFilter) {
        let configuration = SCStreamConfiguration()
        let contentRect = filter.contentRect
        let scale = max(CGFloat(filter.pointPixelScale), 1)
        configuration.width = max(Int(ceil(contentRect.width * scale)), 1)
        configuration.height = max(Int(ceil(contentRect.height * scale)), 1)
        configuration.showsCursor = false

        let metadata = selectedSourceMetadata(from: filter)
        logger.info("Capture selection received style=\(Int(filter.style.rawValue), privacy: .public) width=\(configuration.width, privacy: .public) height=\(configuration.height, privacy: .public)")
        picker.isActive = false

        Task { [weak self] in
            guard let self else { return }

            do {
                try? await Task.sleep(nanoseconds: Self.pickerDismissalDelayNanoseconds)
                let image = try await self.captureCGImage(from: filter, configuration: configuration)
                let nsImage = NSImage(
                    cgImage: image,
                    size: NSSize(width: image.width, height: image.height)
                )
                await MainActor.run {
                    self.logger.info("Capture completed width=\(image.width, privacy: .public) height=\(image.height, privacy: .public)")
                    self.finish(with: .success(CaptureResult(
                        image: nsImage,
                        sourceAppBundleID: metadata.bundleID,
                        sourceAppName: metadata.name
                    )))
                }
            } catch {
                await MainActor.run {
                    self.logger.error("Capture failed: \(error.localizedDescription, privacy: .public)")
                    self.finish(with: .failure(error))
                }
            }
        }
    }

    private func captureCGImage(from filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> CGImage {
        if #available(macOS 26.0, *) {
            do {
                return try await captureModernScreenshot(from: filter, streamConfiguration: configuration)
            } catch {
                logger.warning("Modern ScreenCaptureKit screenshot failed; trying compatibility capture: \(error.localizedDescription, privacy: .public)")
            }
        }

        return try await captureScreenCaptureKitImage(from: filter, configuration: configuration)
    }

    @available(macOS 26.0, *)
    private func captureModernScreenshot(
        from filter: SCContentFilter,
        streamConfiguration: SCStreamConfiguration
    ) async throws -> CGImage {
        let configuration = SCScreenshotConfiguration()
        configuration.width = streamConfiguration.width
        configuration.height = streamConfiguration.height
        configuration.showsCursor = false
        configuration.ignoreShadows = true
        configuration.includeChildWindows = true
        configuration.displayIntent = .local
        configuration.dynamicRange = .sdr

        return try await withCheckedThrowingContinuation { continuation in
            let gate = CaptureResumeGate<CGImage>(continuation)
            SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration) { output, error in
                if let image = output?.sdrImage {
                    gate.resume(.success(image))
                } else {
                    gate.resume(.failure(error ?? ScreenCaptureError.imageUnavailable))
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: Self.stillCaptureTimeoutNanoseconds)
                gate.resume(.failure(ScreenCaptureError.timedOut))
            }
        }
    }

    private func captureScreenCaptureKitImage(
        from filter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            let gate = CaptureResumeGate<CGImage>(continuation)
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
                if let image {
                    gate.resume(.success(image))
                } else {
                    gate.resume(.failure(error ?? ScreenCaptureError.imageUnavailable))
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: Self.stillCaptureTimeoutNanoseconds)
                gate.resume(.failure(ScreenCaptureError.timedOut))
            }
        }
    }

    @MainActor
    private func selectedSourceMetadata(from filter: SCContentFilter) -> (bundleID: String?, name: String?) {
        if #available(macOS 15.2, *),
           let application = filter.includedApplications.first {
            return (application.bundleIdentifier, application.applicationName)
        }

        return (nil, "Screen Capture")
    }
}
