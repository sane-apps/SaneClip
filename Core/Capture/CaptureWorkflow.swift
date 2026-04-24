enum CaptureWorkflow {
    case screenshot
    case text

    var menuTitle: String {
        switch self {
        case .screenshot:
            "Capture Screenshot..."
        case .text:
            "Capture Text..."
        }
    }

    var alertTitle: String {
        switch self {
        case .screenshot:
            "Capture Screenshot"
        case .text:
            "Capture Text"
        }
    }
}
