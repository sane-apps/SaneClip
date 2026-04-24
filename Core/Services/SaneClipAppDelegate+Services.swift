import AppKit

@MainActor
extension SaneClipAppDelegate {
    @objc func saveToSaneClip(
        _ pboard: NSPasteboard,
        userData _: String?,
        error errorPointer: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = pboard.string(forType: .string), !text.isEmpty else {
            errorPointer.pointee = "No text found on pasteboard" as NSString
            return
        }

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontmostApp?.bundleIdentifier
        let appName = frontmostApp?.localizedName

        if let bundleID, SettingsModel.shared.isAppExcluded(bundleID) {
            return
        }

        let item = ClipboardItem(
            content: .text(text),
            sourceAppBundleID: bundleID,
            sourceAppName: appName
        )
        clipboardManager.addItemFromService(item)

        SettingsModel.shared.pasteSound.play()
    }
}
