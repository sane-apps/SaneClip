import AppKit

extension GeneralSettingsView {
    func popupSymbolImage(_ systemImage: String) -> NSImage {
        let weightConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: .white)
        let resolvedConfig = weightConfig.applying(colorConfig)

        guard let symbol = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)?
            .withSymbolConfiguration(resolvedConfig)
        else {
            return NSImage()
        }

        symbol.isTemplate = false
        return symbol
    }
}
