import SaneUI

// MARK: - SaneClip Pro Feature Definitions

enum ProFeature: String, ProFeatureDescribing, CaseIterable {
    case historyLock = "Touch ID History Lock"
    case plainTextPaste = "Paste as Plain Text"
    case smartPaste = "Smart Paste"
    case textTransforms = "Text Transforms"
    case ocrCapture = "OCR Capture"
    case pasteStack = "Paste Stack"
    case snippets = "Snippets"
    case organization = "Organize Items"
    case itemNotes = "Item Notes"
    case clipboardRules = "Clipboard Rules"
    case encryption = "History Encryption"
    case exportImport = "Export / Import"
    case unlimitedHistory = "Unlimited History"

    var id: String { rawValue }
    var featureName: String { rawValue }

    var featureDescription: String {
        switch self {
        case .historyLock:
            "Lock clipboard history behind Touch ID before viewing or pasting sensitive clips."
        case .plainTextPaste:
            "Strip rich formatting and paste pure text — no hidden fonts, colors, or styles carried over."
        case .smartPaste:
            "Auto-detects code and URLs. Code pastes as plain text; URLs are cleaned of tracking parameters."
        case .textTransforms:
            "Paste with one-tap transforms: UPPERCASE, lowercase, Title Case, camelCase, and more."
        case .ocrCapture:
            "Capture text from windows and screenshots, and save OCR sidecar text for searchable image history."
        case .pasteStack:
            "Queue multiple items for sequential pasting — perfect for filling forms or structured workflows."
        case .snippets:
            "Save reusable text templates with dynamic placeholders like {{date}}, {{name}}, and {{clipboard}}."
        case .organization:
            "Add titles, tags, and collections so important clips stay organized and easy to find."
        case .itemNotes:
            "Attach private notes to any clipboard item for context, tags, or reminders."
        case .clipboardRules:
            "Auto-clean every copy: strip tracking params, trim whitespace, normalize line endings, and more."
        case .encryption:
            "Protect your clipboard history at rest with AES-256-GCM encryption — your data stays private."
        case .exportImport:
            "Back up your clipboard history to JSON and restore it anytime — even on a new Mac."
        case .unlimitedHistory:
            "Free tier stores your last 50 clips. Pro removes the cap — keep your entire clipboard history."
        }
    }

    var featureIcon: String {
        switch self {
        case .historyLock:
            "touchid"
        case .plainTextPaste:
            "textformat.alt"
        case .smartPaste:
            "wand.and.stars"
        case .textTransforms:
            "textformat.abc"
        case .ocrCapture:
            "text.viewfinder"
        case .pasteStack:
            "square.stack.3d.up"
        case .snippets:
            "text.quote"
        case .organization:
            "tag.fill"
        case .itemNotes:
            "note.text"
        case .clipboardRules:
            "ruler"
        case .encryption:
            "lock.shield.fill"
        case .exportImport:
            "arrow.up.arrow.down.circle"
        case .unlimitedHistory:
            "infinity"
        }
    }
}
