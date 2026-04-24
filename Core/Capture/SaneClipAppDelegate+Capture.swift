import AppKit
import os.log
import SaneUI

private let captureWorkflowLogger = Logger(subsystem: "com.saneclip.app", category: "Capture")

@MainActor
extension SaneClipAppDelegate {
    @objc func captureScreenshotFromMenu() {
        Task { @MainActor in
            await runCaptureWorkflow(.screenshot)
        }
    }

    @objc func captureTextFromMenu() {
        Task { @MainActor in
            await runCaptureWorkflow(.text)
        }
    }

    func runCaptureWorkflow(_ workflow: CaptureWorkflow) async {
        NSApp.activate(ignoringOtherApps: true)

        if workflow == .text, licenseService.isPro == false {
            ProUpsellWindow.show(feature: ProFeature.ocrCapture, licenseService: licenseService)
            return
        }

        do {
            let result = try await screenCaptureService.captureImage()
            let ocrLanguage = SettingsModel.shared.captureOCRLanguage
            switch workflow {
            case .screenshot:
                let ocrText = await recognizedTextForScreenshot(result.image, language: ocrLanguage)
                try clipboardManager.importCapturedImage(
                    result.image,
                    sourceAppBundleID: result.sourceAppBundleID,
                    sourceAppName: result.sourceAppName,
                    ocrText: ocrText
                )
            case .text:
                let recognizedText = try await captureOCRService.recognizeText(in: result.image, language: ocrLanguage)
                guard !recognizedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else {
                    throw ScreenCaptureError.noRecognizedText
                }
                try clipboardManager.importCapturedText(
                    recognizedText,
                    sourceAppBundleID: result.sourceAppBundleID,
                    sourceAppName: result.sourceAppName
                )
            }
        } catch ScreenCaptureError.cancelled {
            return
        } catch ScreenCaptureError.captureAlreadyInProgress {
            captureWorkflowLogger.info("Capture request ignored because the picker is already active.")
            return
        } catch ScreenCaptureError.screenCapturePermissionDenied {
            presentScreenCapturePermissionAlert(title: workflow.alertTitle)
        } catch ClipboardManager.CaptureImportError.emptyText {
            presentCaptureAlert(
                title: workflow.alertTitle,
                message: ScreenCaptureError.noRecognizedText.errorDescription ?? "No text was found in the captured content."
            )
        } catch {
            presentCaptureAlert(
                title: workflow.alertTitle,
                message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
    }

    private func recognizedTextForScreenshot(_ image: NSImage, language: CaptureOCRLanguage) async -> String? {
        guard licenseService.isPro else { return nil }
        guard SettingsModel.shared.autoOCRCapturedScreenshots else { return nil }
        do {
            let text = try await captureOCRService.recognizeText(in: image, language: language)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            captureWorkflowLogger.warning("Screenshot OCR failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func presentCaptureAlert(title: String, message: String) {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func presentScreenCapturePermissionAlert(title: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "SaneClip needs Screen Recording permission for Capture Screenshot and Pro OCR capture. Turn it on in System Settings, then try again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Screen Recording Settings")
        alert.addButton(withTitle: "Not Now")

        if alert.runModal() == .alertFirstButtonReturn {
            ScreenCapturePermissionService.openSettings()
        }
    }
}
