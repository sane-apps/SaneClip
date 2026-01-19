# SaneApps Design Language

A cohesive design system for all SaneApps (SaneClip, SaneHosts, SaneBar, etc.) ensuring a premium, unified user experience across macOS applications.

## Core Principles

1. **Glass Morphism** - Translucent backgrounds with subtle blur effects
2. **Semantic Colors** - Teal as primary accent, consistent status colors
3. **Compact Density** - Efficient use of space without feeling cramped
4. **Dark Mode First** - Designed for dark mode, adapted for light mode
5. **Meaningful Icons** - SF Symbols with semantic naming

---

## Color System

### Accent Colors
```swift
// Primary accent
Color.teal  // Main brand color, buttons, highlights

// Status colors
extension Color {
    static let saneSuccess = Color.green      // Success states, active indicators
    static let saneDanger = Color.red         // Destructive actions, errors
    static let saneWarning = Color.orange     // Caution, warnings
}
```

### Dark Mode Gradients
```swift
LinearGradient(
    colors: [
        Color.teal.opacity(0.08),
        Color.blue.opacity(0.05),
        Color.teal.opacity(0.03)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

### Light Mode Gradients
```swift
LinearGradient(
    colors: [
        Color(red: 0.95, green: 0.98, blue: 0.99),
        Color(red: 0.92, green: 0.96, blue: 0.98),
        Color(red: 0.94, green: 0.97, blue: 0.99)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

### Border Colors
```swift
// Dark mode
Color.white.opacity(0.12)

// Light mode
Color.teal.opacity(0.15)
```

---

## Spacing System

| Token | Value | Usage |
|-------|-------|-------|
| `tight` | 8pt | Tight element spacing |
| `compact` | 10pt | Compact row padding |
| `default` | 12pt | Standard horizontal padding |
| `section` | 20pt | Outer section padding |
| `major` | 24pt | Major section gaps |

---

## Typography

- **Section titles**: `.font(.headline)`
- **Body text**: `.font(.body)`
- **Secondary text**: `.font(.caption)` + `.foregroundStyle(.secondary)`
- **Monospace**: `.font(.system(.body, design: .monospaced))` for code/paths

---

## Corner Radius

**Standard radius**: `10pt` for all rounded rectangles (sections, cards, buttons)

---

## Glass Morphism Implementation

### VisualEffectBlur (NSViewRepresentable)
```swift
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material  // .hudWindow for dark mode
        view.blendingMode = blendingMode  // .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
```

### SaneGradientBackground
```swift
struct SaneGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                // Teal-to-blue gradient overlay
            } else {
                // Subtle blue-gray gradient
            }
        }
        .ignoresSafeArea()
    }
}
```

---

## Component Library

### CompactSection
Grouped content with header, glass background, and shadow.

```swift
struct CompactSection<Content: View>: View {
    let title: String
    let icon: String?
    let iconColor: Color
    let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with icon and title
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }
                Text(title)
                    .font(.headline)
            }
            .padding(.leading, 4)

            // Content with glass background
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 3)
        }
    }
}
```

### CompactRow
Standard row with icon, label, and trailing content.

```swift
struct CompactRow<Content: View>: View {
    let label: String
    let icon: String?
    let iconColor: Color
    let content: Content

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
            }
            Text(label)
            Spacer()
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
```

### CompactToggle
Toggle switch with icon and label.

```swift
struct CompactToggle: View {
    let label: String
    let icon: String?
    let iconColor: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
            }
            Text(label)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
```

### CompactDivider
Inset divider for separating rows.

```swift
struct CompactDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 12)
    }
}
```

### StatusBadge
Rounded capsule badge for status indicators.

```swift
struct StatusBadge: View {
    let text: String
    let color: Color
    let icon: String?

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}
```

### SaneEmptyState
Centered empty state with icon, title, description, and action.

```swift
struct SaneEmptyState: View {
    let icon: String
    let title: String
    let description: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

### LoadingOverlay
Semi-transparent overlay with progress indicator.

```swift
struct LoadingOverlay: View {
    let message: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                if let message = message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
```

---

## Icon System (SaneIcons)

Semantic SF Symbol naming for consistent iconography across apps.

```swift
enum SaneIcons {
    // Actions
    static let add = "plus"
    static let remove = "trash"
    static let edit = "pencil"
    static let duplicate = "doc.on.doc"
    static let activate = "power"
    static let deactivate = "pause.circle"

    // Status
    static let success = "checkmark.circle.fill"
    static let warning = "exclamationmark.triangle.fill"
    static let error = "xmark.circle.fill"

    // Navigation
    static let profiles = "folder.fill"
    static let settings = "gear"

    // Content
    static let network = "network"
    static let globe = "globe"
    static let hosts = "server.rack"
    static let lock = "lock.fill"

    // Data
    static let import_ = "arrow.down.circle"
    static let export = "arrow.up.circle"
    static let sync = "arrow.triangle.2.circlepath"

    // Entry states
    static let entryEnabled = "checkmark.circle"
    static let entryDisabled = "circle"

    // Profile sources
    static let profileLocal = "externaldrive"
    static let profileRemote = "cloud"
    static let profileSystem = "gearshape"
    static let profileInactive = "circle.dashed"

    // Templates
    static let templateAdBlock = "hand.raised.slash"
    static let templateDev = "hammer"
    static let templateSocial = "bubble.left.and.bubble.right"
    static let templatePrivacy = "eye.slash"
}
```

---

## Shadow System

### Dark Mode
```swift
.shadow(
    color: .black.opacity(0.15),
    radius: 8,
    x: 0,
    y: 3
)
```

### Light Mode
```swift
.shadow(
    color: .teal.opacity(0.08),
    radius: 6,
    x: 0,
    y: 3
)
```

---

## Button Styling

### Primary Action
```swift
Button("Action") { }
    .buttonStyle(.borderedProminent)
    .tint(.teal)
```

### Secondary Action
```swift
Button("Cancel") { }
    .buttonStyle(.bordered)
```

### Destructive Action
```swift
Button("Delete", role: .destructive) { }
    .buttonStyle(.bordered)
    .tint(.red)
```

---

## Sheet/Modal Styling

```swift
VStack(spacing: 24) {
    // Header with icon
    HStack {
        Image(systemName: "icon.name")
            .font(.title2)
            .foregroundStyle(.teal)
        Text("Title")
            .font(.headline)
    }

    // Form content using CompactSection
    VStack(spacing: 16) {
        CompactSection("Section") { /* content */ }
    }

    // Action buttons
    HStack(spacing: 12) {
        Button("Cancel") { }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(.bordered)

        Button("Primary Action") { }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(.teal)
    }
}
.padding(24)
.frame(width: 380)
.background(SaneGradientBackground())
```

---

## Implementation Checklist

When building a new SaneApp:

- [ ] Import/copy the DesignSystem.swift file
- [ ] Use `SaneGradientBackground()` for main content areas
- [ ] Use `CompactSection` for grouped settings/content
- [ ] Use `CompactRow`, `CompactToggle`, `CompactDivider` for rows
- [ ] Use `StatusBadge` for status indicators
- [ ] Use `SaneEmptyState` for empty views
- [ ] Use `SaneIcons` enum for all SF Symbols
- [ ] Apply `.buttonStyle(.borderedProminent).tint(.teal)` for primary actions
- [ ] Use 10pt corner radius consistently
- [ ] Follow the spacing system (8, 10, 12, 20, 24pt)
- [ ] Test in both dark and light modes

---

## Apps Using This Design Language

- **SaneClip** - Clipboard manager (origin of the design system)
- **SaneHosts** - Hosts file manager
- **SaneBar** - Menu bar manager (planned)

---

*Last updated: January 2026*
