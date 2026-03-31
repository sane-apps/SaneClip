import Foundation

enum SaneClipSettingsCopy {
    static let startupSectionTitle = String(
        localized: "saneclip.settings.section.startup",
        defaultValue: "Startup"
    )

    static let appearanceSectionTitle = String(
        localized: "saneclip.settings.section.appearance",
        defaultValue: "Appearance"
    )

    static let menuBarIconLabel = String(
        localized: "saneclip.settings.appearance.menu_bar_icon",
        defaultValue: "Menu Bar Icon"
    )

    static let menuBarIconListTitle = String(
        localized: "saneclip.settings.appearance.menu_bar_icon.list",
        defaultValue: "List"
    )

    static let menuBarIconMinimalTitle = String(
        localized: "saneclip.settings.appearance.menu_bar_icon.minimal",
        defaultValue: "Minimal"
    )

    static let pasteSoundLabel = String(
        localized: "saneclip.settings.appearance.paste_sound",
        defaultValue: "Paste sound"
    )

    static let pasteSoundPreviewHelp = String(
        localized: "saneclip.settings.appearance.paste_sound_preview_help",
        defaultValue: "Preview sound"
    )

    static let pasteStackNewestFirstLabel = String(
        localized: "saneclip.settings.appearance.paste_stack_newest_first",
        defaultValue: "Paste stack: newest first"
    )

    static let keepStackPanelOpenLabel = String(
        localized: "saneclip.settings.appearance.keep_stack_panel_open",
        defaultValue: "Keep stack panel open while pasting"
    )

    static let autoCloseStackPanelLabel = String(
        localized: "saneclip.settings.appearance.auto_close_stack_panel",
        defaultValue: "Auto-close panel when stack is empty"
    )

    static let collapseDuplicateStackItemsLabel = String(
        localized: "saneclip.settings.appearance.collapse_duplicate_stack_items",
        defaultValue: "Collapse duplicate stack items"
    )

    static let defaultPasteModeLabel = String(
        localized: "saneclip.settings.appearance.default_paste_mode",
        defaultValue: "Default paste mode"
    )

    static let perAppPasteModeLabel = String(
        localized: "saneclip.settings.appearance.per_app_paste_mode",
        defaultValue: "Per-app paste mode"
    )

    static let appPresetPlaceholder = String(
        localized: "saneclip.settings.appearance.app_preset_placeholder",
        defaultValue: "com.apple.TextEdit"
    )

    static let saveButtonTitle = String(
        localized: "saneclip.settings.button.save",
        defaultValue: "Save"
    )

    static let noOverridesConfigured = String(
        localized: "saneclip.settings.appearance.no_overrides",
        defaultValue: "No overrides configured"
    )

    static let removeButtonTitle = String(
        localized: "saneclip.settings.button.remove",
        defaultValue: "Remove"
    )

    static let pasteStackOrderLockedLabel = String(
        localized: "saneclip.settings.appearance.paste_stack_order_locked",
        defaultValue: "Paste stack order (FIFO / LIFO)"
    )

    static let defaultPasteModeLockedLabel = String(
        localized: "saneclip.settings.appearance.default_paste_mode_locked",
        defaultValue: "Default paste mode (Plain / Smart)"
    )

    static let securitySectionTitle = String(
        localized: "saneclip.settings.section.security",
        defaultValue: "Security"
    )

    static let detectPasswordsLabel = String(
        localized: "saneclip.settings.security.detect_passwords",
        defaultValue: "Detect & skip passwords"
    )

    static let touchIDLabel = String(
        localized: "saneclip.settings.security.touch_id",
        defaultValue: "Require Touch ID to view history"
    )

    static let touchIDHelp = String(
        localized: "saneclip.settings.security.touch_id_help",
        defaultValue: "Unlock history with Touch ID or your password"
    )

    static let encryptHistoryLabel = String(
        localized: "saneclip.settings.security.encrypt_history",
        defaultValue: "Encrypt history at rest"
    )

    static let encryptHistoryHelp = String(
        localized: "saneclip.settings.security.encrypt_history_help",
        defaultValue: "Protect clipboard history on this Mac with local encryption"
    )

    static let authenticatePasswordManagerMessage = String(
        localized: "saneclip.settings.security.authenticate_password_manager",
        defaultValue: "Authenticate to allow password manager copies in history"
    )

    static let softwareUpdatesSectionTitle = String(
        localized: "saneclip.settings.section.software_updates",
        defaultValue: "Software Updates"
    )

    static let updateAutomaticallyLabel = String(
        localized: "saneclip.settings.updates.automatically_label",
        defaultValue: "Check for updates automatically"
    )

    static let updateAutomaticallyHelp = String(
        localized: "saneclip.settings.updates.automatically_help",
        defaultValue: "Periodically check for new versions"
    )

    static let updateFrequencyLabel = String(
        localized: "saneclip.settings.updates.frequency_label",
        defaultValue: "Check frequency"
    )

    static let updateFrequencyHelp = String(
        localized: "saneclip.settings.updates.frequency_help",
        defaultValue: "Choose how often automatic update checks run"
    )

    static let updatesActionsLabel = String(
        localized: "saneclip.settings.updates.actions_label",
        defaultValue: "Actions"
    )

    static let checkingButtonTitle = String(
        localized: "saneclip.settings.updates.checking_button",
        defaultValue: "Checking..."
    )

    static let checkNowButtonTitle = String(
        localized: "saneclip.settings.updates.check_now_button",
        defaultValue: "Check Now"
    )

    static let checkNowHelp = String(
        localized: "saneclip.settings.updates.check_now_help",
        defaultValue: "Check for updates right now"
    )

    static let historySectionTitle = String(
        localized: "saneclip.settings.section.history",
        defaultValue: "History"
    )

    static let maximumItemsLabel = String(
        localized: "saneclip.settings.history.maximum_items",
        defaultValue: "Maximum Items"
    )

    static let autoDeleteAfterLabel = String(
        localized: "saneclip.settings.history.auto_delete_after",
        defaultValue: "Auto-delete After"
    )

    static let pinnedItemsHelp = String(
        localized: "saneclip.settings.history.pinned_items_help",
        defaultValue: "Pinned items are never deleted"
    )

    static let storageLabel = String(
        localized: "saneclip.settings.history.storage",
        defaultValue: "Storage"
    )

    static let dataLabel = String(
        localized: "saneclip.settings.history.data",
        defaultValue: "Data"
    )

    static let exportButtonTitle = String(
        localized: "saneclip.settings.button.export",
        defaultValue: "Export..."
    )

    static let importButtonTitle = String(
        localized: "saneclip.settings.button.import",
        defaultValue: "Import..."
    )

    static let exportImportLabel = String(
        localized: "saneclip.settings.history.export_import",
        defaultValue: "Export / Import"
    )

    static let textSizeLabel = String(
        localized: "saneclip.settings.history.max_text_size",
        defaultValue: "Max Text Size"
    )

    static let imageSizeLabel = String(
        localized: "saneclip.settings.history.max_image_size",
        defaultValue: "Max Image Size"
    )

    static let backupRestoreSectionTitle = String(
        localized: "saneclip.settings.section.backup_restore",
        defaultValue: "Backup & Restore"
    )

    static let settingsLabel = String(
        localized: "saneclip.settings.label.settings",
        defaultValue: "Settings"
    )

    static let captureControlsSectionTitle = String(
        localized: "saneclip.settings.section.capture_controls",
        defaultValue: "Capture Controls"
    )

    static let ignoreNextCopyLabel = String(
        localized: "saneclip.settings.capture.ignore_next_copy",
        defaultValue: "Ignore Next Copy"
    )

    static let ignoreOnceButtonTitle = String(
        localized: "saneclip.settings.capture.ignore_once_button",
        defaultValue: "Ignore Once"
    )

    static let pauseCaptureLabel = String(
        localized: "saneclip.settings.capture.pause_capture",
        defaultValue: "Pause Capture"
    )

    static let pause5mTitle = String(
        localized: "saneclip.settings.capture.pause_5m",
        defaultValue: "5m"
    )

    static let pause15mTitle = String(
        localized: "saneclip.settings.capture.pause_15m",
        defaultValue: "15m"
    )

    static let pause60mTitle = String(
        localized: "saneclip.settings.capture.pause_60m",
        defaultValue: "60m"
    )

    static let resumeTitle = String(
        localized: "saneclip.settings.capture.resume",
        defaultValue: "Resume"
    )

    static let clipRulesSectionTitle = String(
        localized: "saneclip.settings.section.clipboard_rules",
        defaultValue: "Clipboard Rules"
    )

    static let stripTrackingParametersLabel = String(
        localized: "saneclip.settings.rules.strip_tracking_parameters",
        defaultValue: "Strip URL tracking parameters"
    )

    static let stripTrackingParametersHelp = String(
        localized: "saneclip.settings.rules.strip_tracking_parameters_help",
        defaultValue: "Remove utm_*, fbclid, and other tracking params from URLs — requires Pro"
    )

    static let autoTrimWhitespaceLabel = String(
        localized: "saneclip.settings.rules.auto_trim_whitespace",
        defaultValue: "Auto-trim whitespace"
    )

    static let autoTrimWhitespaceHelp = String(
        localized: "saneclip.settings.rules.auto_trim_whitespace_help",
        defaultValue: "Remove leading/trailing spaces from copied text — requires Pro"
    )

    static let normalizeLineEndingsLabel = String(
        localized: "saneclip.settings.rules.normalize_line_endings",
        defaultValue: "Normalize line endings"
    )

    static let normalizeLineEndingsHelp = String(
        localized: "saneclip.settings.rules.normalize_line_endings_help",
        defaultValue: "Convert Windows (CRLF) to Unix (LF) line endings — requires Pro"
    )

    static let removeDuplicateSpacesLabel = String(
        localized: "saneclip.settings.rules.remove_duplicate_spaces",
        defaultValue: "Remove duplicate spaces"
    )

    static let removeDuplicateSpacesHelp = String(
        localized: "saneclip.settings.rules.remove_duplicate_spaces_help",
        defaultValue: "Collapse multiple consecutive spaces into one — requires Pro"
    )

    static let lowercaseURLHostsLabel = String(
        localized: "saneclip.settings.rules.lowercase_url_hosts",
        defaultValue: "Lowercase URL hosts"
    )

    static let lowercaseURLHostsHelp = String(
        localized: "saneclip.settings.rules.lowercase_url_hosts_help",
        defaultValue: "Convert URL hostnames to lowercase — requires Pro"
    )

    static let proLabel = String(
        localized: "saneclip.settings.pro.label",
        defaultValue: "Pro"
    )

    static let upgradeButtonTitle = String(
        localized: "saneclip.settings.pro.upgrade_button",
        defaultValue: "Upgrade"
    )

    static let snippetsGateTitle = String(
        localized: "saneclip.settings.snippets.gate_title",
        defaultValue: "Snippets require SaneClip Pro"
    )

    static let snippetsSearchPlaceholder = String(
        localized: "saneclip.settings.snippets.search_placeholder",
        defaultValue: "Search snippets..."
    )

    static let noSnippetsTitle = String(
        localized: "saneclip.settings.snippets.no_snippets_title",
        defaultValue: "No Snippets"
    )

    static let noResultsTitle = String(
        localized: "saneclip.settings.snippets.no_results_title",
        defaultValue: "No Results"
    )

    static let noSnippetsDescription = String(
        localized: "saneclip.settings.snippets.no_snippets_description",
        defaultValue: "Create snippets to quickly paste common text"
    )

    static let noResultsDescription = String(
        localized: "saneclip.settings.snippets.no_results_description",
        defaultValue: "Try a different search"
    )

    static let editButtonTitle = String(
        localized: "saneclip.settings.snippets.edit_button",
        defaultValue: "Edit"
    )

    static let duplicateButtonTitle = String(
        localized: "saneclip.settings.snippets.duplicate_button",
        defaultValue: "Duplicate"
    )

    static let deleteButtonTitle = String(
        localized: "saneclip.settings.snippets.delete_button",
        defaultValue: "Delete"
    )

    static let unlockProButtonTitle = String(
        localized: "saneclip.settings.snippets.unlock_pro_button",
        defaultValue: "Unlock Pro"
    )

    static let addSnippetButtonTitle = String(
        localized: "saneclip.settings.snippets.add_button",
        defaultValue: "Add Snippet"
    )

    static let addSnippetLockedButtonTitle = String(
        localized: "saneclip.settings.snippets.add_button_locked",
        defaultValue: "Add Snippet 🔒"
    )

    static let snippetsCountFormat = String(
        localized: "saneclip.settings.snippets.count_format",
        defaultValue: "%d snippets"
    )

    static let newSnippetTitle = String(
        localized: "saneclip.settings.snippets.new_title",
        defaultValue: "New Snippet"
    )

    static let editSnippetTitle = String(
        localized: "saneclip.settings.snippets.edit_title",
        defaultValue: "Edit Snippet"
    )

    static let nameFieldPlaceholder = String(
        localized: "saneclip.settings.snippets.name_placeholder",
        defaultValue: "Name"
    )

    static let categoryFieldPlaceholder = String(
        localized: "saneclip.settings.snippets.category_placeholder",
        defaultValue: "Category (optional)"
    )

    static let templateFieldTitle = String(
        localized: "saneclip.settings.snippets.template_title",
        defaultValue: "Template"
    )

    static let placeholdersTitle = String(
        localized: "saneclip.settings.snippets.placeholders_title",
        defaultValue: "Placeholders"
    )

    static let previewTitle = String(
        localized: "saneclip.settings.snippets.preview_title",
        defaultValue: "Preview"
    )

    static let detectedPlaceholdersTitle = String(
        localized: "saneclip.settings.snippets.detected_placeholders_title",
        defaultValue: "Detected Placeholders"
    )

    static let cancelButtonTitle = String(
        localized: "saneclip.settings.button.cancel",
        defaultValue: "Cancel"
    )

    static let snippetsCopySuffix = String(
        localized: "saneclip.settings.snippets.copy_suffix",
        defaultValue: "Copy"
    )

    static let currentDateDescription = String(
        localized: "saneclip.settings.snippets.current_date_description",
        defaultValue: "Current date"
    )

    static let currentTimeDescription = String(
        localized: "saneclip.settings.snippets.current_time_description",
        defaultValue: "Current time"
    )

    static let clipboardDescription = String(
        localized: "saneclip.settings.snippets.clipboard_description",
        defaultValue: "Clipboard"
    )

    static let userPromptDescription = String(
        localized: "saneclip.settings.snippets.user_prompt_description",
        defaultValue: "User prompt"
    )

    static func pasteSoundDisplayName(_ sound: PasteSound) -> String {
        switch sound {
        case .off:
            return String(localized: "saneclip.settings.appearance.paste_sound.off", defaultValue: "Off")
        case .tink:
            return String(localized: "saneclip.settings.appearance.paste_sound.tink", defaultValue: "Tink")
        case .pop:
            return String(localized: "saneclip.settings.appearance.paste_sound.pop", defaultValue: "Pop")
        case .glass:
            return String(localized: "saneclip.settings.appearance.paste_sound.glass", defaultValue: "Glass")
        }
    }

    static func pasteModeDisplayName(_ mode: PasteMode) -> String {
        switch mode {
        case .standard:
            return String(localized: "saneclip.settings.appearance.paste_mode.standard", defaultValue: "Standard")
        case .plain:
            return String(localized: "saneclip.settings.appearance.paste_mode.plain", defaultValue: "Plain Text")
        case .smart:
            return String(localized: "saneclip.settings.appearance.paste_mode.smart", defaultValue: "Smart")
        }
    }

    static func pasteModeDescription(_ mode: PasteMode) -> String {
        switch mode {
        case .standard:
            return String(localized: "saneclip.settings.appearance.paste_mode.standard_description", defaultValue: "Paste with original formatting")
        case .plain:
            return String(localized: "saneclip.settings.appearance.paste_mode.plain_description", defaultValue: "Always strip formatting")
        case .smart:
            return String(localized: "saneclip.settings.appearance.paste_mode.smart_description", defaultValue: "Auto-detect: code→plain, URL→cleaned, else→standard")
        }
    }

    static func snippetsCount(_ count: Int) -> String {
        String(format: snippetsCountFormat, count)
    }
}
