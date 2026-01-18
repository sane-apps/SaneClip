import SwiftUI
import KeyboardShortcuts
import ServiceManagement
import LocalAuthentication

// MARK: - Settings Model

@MainActor
@Observable
class SettingsModel {
    static let shared = SettingsModel()

    var maxHistorySize: Int {
        didSet {
            UserDefaults.standard.set(maxHistorySize, forKey: "maxHistorySize")
        }
    }

    var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: "showInDock")
            applyDockVisibility()
        }
    }

    var protectPasswords: Bool {
        didSet {
            UserDefaults.standard.set(protectPasswords, forKey: "protectPasswords")
        }
    }

    var requireTouchID: Bool {
        didSet {
            UserDefaults.standard.set(requireTouchID, forKey: "requireTouchID")
        }
    }

    init() {
        self.maxHistorySize = UserDefaults.standard.object(forKey: "maxHistorySize") as? Int ?? 50
        self.showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true
        self.protectPasswords = UserDefaults.standard.object(forKey: "protectPasswords") as? Bool ?? true
        self.requireTouchID = UserDefaults.standard.object(forKey: "requireTouchID") as? Bool ?? false
        applyDockVisibility()
    }

    private func applyDockVisibility() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @State private var selectedTab: SettingsTab? = .general

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case shortcuts = "Shortcuts"
        case about = "About"

        var id: String { rawValue }
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label {
                        Text(tab.rawValue)
                    } icon: {
                        Image(systemName: icon(for: tab))
                            .foregroundStyle(iconColor(for: tab))
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 170)
        } detail: {
            ZStack {
                // Gradient background for both modes
                SettingsGradientBackground()

                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .shortcuts:
                    ShortcutsSettingsView()
                case .about:
                    AboutSettingsView()
                case .none:
                    GeneralSettingsView()
                }
            }
        }
        .groupBoxStyle(GlassGroupBoxStyle())
        .frame(minWidth: 700, minHeight: 450)
    }

    private func icon(for tab: SettingsTab) -> String {
        switch tab {
        case .general: return "gear"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
        }
    }

    private func iconColor(for tab: SettingsTab) -> Color {
        switch tab {
        case .general: return .gray
        case .shortcuts: return .orange
        case .about: return .secondary
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @State private var settings = SettingsModel.shared
    @State private var launchAtLogin = false
    @State private var autoCheckUpdates = UpdateService.shared.automaticallyChecksForUpdates
    @State private var isAuthenticating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CompactSection("Startup") {
                    CompactToggle(label: "Start automatically at login", isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            launchAtLogin = newValue
                            setLaunchAtLogin(newValue)
                        }
                    ))
                    CompactDivider()
                    CompactToggle(label: "Show app in Dock", isOn: Binding(
                        get: { settings.showInDock },
                        set: { settings.showInDock = $0 }
                    ))
                }

                CompactSection("Updates") {
                    CompactToggle(label: "Automatically check for updates", isOn: Binding(
                        get: { autoCheckUpdates },
                        set: { newValue in
                            autoCheckUpdates = newValue
                            UpdateService.shared.automaticallyChecksForUpdates = newValue
                        }
                    ))
                }

                CompactSection("History") {
                    CompactRow("Maximum Items") {
                        Picker("", selection: Binding(
                            get: { settings.maxHistorySize },
                            set: { settings.maxHistorySize = $0 }
                        )) {
                            Text("25").tag(25)
                            Text("50").tag(50)
                            Text("100").tag(100)
                            Text("200").tag(200)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                    }
                }

                CompactSection("Privacy") {
                    CompactToggle(label: "Protect passwords (auto-clear)", isOn: Binding(
                        get: { settings.protectPasswords },
                        set: { settings.protectPasswords = $0 }
                    ))
                    CompactDivider()
                    CompactToggle(label: "Require Touch ID to view history", isOn: Binding(
                        get: { settings.requireTouchID },
                        set: { newValue in
                            if newValue {
                                // Turning ON - no auth needed
                                settings.requireTouchID = true
                            } else {
                                // Turning OFF - requires Touch ID first
                                authenticateToDisableTouchID()
                            }
                        }
                    ))
                    .disabled(isAuthenticating)
                }

                CompactSection("Storage") {
                    CompactRow("Location") {
                        Text("~/Library/Application Support/SaneClip/")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            checkLaunchAtLogin()
            autoCheckUpdates = UpdateService.shared.automaticallyChecksForUpdates
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
            launchAtLogin = !launchAtLogin
        }
    }

    private func checkLaunchAtLogin() {
        let status = SMAppService.mainApp.status
        launchAtLogin = (status == .enabled)
    }

    private func authenticateToDisableTouchID() {
        isAuthenticating = true
        let context = LAContext()
        var error: NSError?

        // Use biometrics if available, otherwise fall back to device password
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        context.evaluatePolicy(
            policy,
            localizedReason: "Authenticate to disable Touch ID protection"
        ) { success, _ in
            DispatchQueue.main.async {
                if success {
                    settings.requireTouchID = false
                }
                isAuthenticating = false
            }
        }
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CompactSection("Main Shortcuts") {
                    CompactRow("Show Clipboard History") {
                        KeyboardShortcuts.Recorder(for: .showClipboardHistory)
                    }
                    CompactDivider()
                    CompactRow("Paste as Plain Text") {
                        KeyboardShortcuts.Recorder(for: .pasteAsPlainText)
                    }
                }

                CompactSection("Quick Paste (Items 1-9)") {
                    CompactRow("Paste Item 1") {
                        KeyboardShortcuts.Recorder(for: .pasteItem1)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 2") {
                        KeyboardShortcuts.Recorder(for: .pasteItem2)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 3") {
                        KeyboardShortcuts.Recorder(for: .pasteItem3)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 4") {
                        KeyboardShortcuts.Recorder(for: .pasteItem4)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 5") {
                        KeyboardShortcuts.Recorder(for: .pasteItem5)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 6") {
                        KeyboardShortcuts.Recorder(for: .pasteItem6)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 7") {
                        KeyboardShortcuts.Recorder(for: .pasteItem7)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 8") {
                        KeyboardShortcuts.Recorder(for: .pasteItem8)
                    }
                    CompactDivider()
                    CompactRow("Paste Item 9") {
                        KeyboardShortcuts.Recorder(for: .pasteItem9)
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    @State private var showLicenses = false
    @State private var showSupport = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App identity
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)

            VStack(spacing: 8) {
                Text("SaneClip")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("Version \(version)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            // Trust info
            HStack(spacing: 0) {
                Text("Made by Mr. Sane in USA")
                    .fontWeight(.medium)
                Text(" • ")
                Text("100% Local")
                Text(" • ")
                Text("No Analytics")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.top, 4)

            // Links row
            HStack(spacing: 16) {
                Link(destination: URL(string: "https://github.com/stephanjoseph/SaneClip")!) {
                    Label("GitHub", systemImage: "link")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    showLicenses = true
                } label: {
                    Label("Licenses", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    showSupport = true
                } label: {
                    Label {
                        Text("Support")
                    } icon: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Link(destination: URL(string: "https://github.com/stephanjoseph/SaneClip/issues")!) {
                    Label("Report Issue", systemImage: "ladybug")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.top, 12)

            // Check for Updates
            Button {
                checkForUpdates()
            } label: {
                Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showLicenses) {
            licensesSheet
        }
        .sheet(isPresented: $showSupport) {
            supportSheet
        }
    }

    private func checkForUpdates() {
        UpdateService.shared.checkForUpdates()
    }

    // MARK: - Licenses Sheet

    private var licensesSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Open Source Licenses")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    showLicenses = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Link("KeyboardShortcuts", destination: URL(string: "https://github.com/sindresorhus/KeyboardShortcuts")!)
                                .font(.headline)

                            Text("""
                            MIT License

                            Copyright (c) Sindre Sorhus <sindresorhus@gmail.com> (https://sindresorhus.com)

                            Permission is hereby granted, free of charge, to any person obtaining a copy \
                            of this software and associated documentation files (the "Software"), to deal \
                            in the Software without restriction, including without limitation the rights \
                            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
                            copies of the Software, and to permit persons to whom the Software is \
                            furnished to do so, subject to the following conditions:

                            The above copyright notice and this permission notice shall be included in all \
                            copies or substantial portions of the Software.

                            THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
                            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
                            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
                            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
                            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
                            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
                            SOFTWARE.
                            """)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Link("Sparkle", destination: URL(string: "https://sparkle-project.org")!)
                                .font(.headline)

                            Text("""
                            Copyright (c) 2006-2013 Andy Matuschak.
                            Copyright (c) 2009-2013 Elgato Systems GmbH.
                            Copyright (c) 2011-2014 Kornel Lesiński.
                            Copyright (c) 2015-2017 Mayur Pawashe.
                            Copyright (c) 2014 C.W. Betts.
                            Copyright (c) 2014 Petroules Corporation.
                            Copyright (c) 2014 Big Nerd Ranch.
                            All rights reserved.

                            Permission is hereby granted, free of charge, to any person obtaining a copy of
                            this software and associated documentation files (the "Software"), to deal in
                            the Software without restriction, including without limitation the rights to
                            use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
                            of the Software, and to permit persons to whom the Software is furnished to do
                            so, subject to the following conditions:

                            The above copyright notice and this permission notice shall be included in all
                            copies or substantial portions of the Software.

                            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
                            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
                            FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
                            COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
                            IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
                            CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
                            """)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 400)
    }

    // MARK: - Support Sheet

    private var supportSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Support SaneClip")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    showSupport = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Quote
                    VStack(spacing: 4) {
                        Text("\"The worker is worthy of his wages.\"")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .italic()
                        Text("— 1 Timothy 5:18")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Personal message
                    Text("I need your help to keep SaneClip alive. Your support — whether one-time or monthly — makes this possible. Thank you.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Text("— Mr. Sane")
                        .font(.system(size: 13, weight: .medium))
                        .multilineTextAlignment(.center)

                    Divider()
                        .padding(.horizontal, 40)

                    // GitHub Sponsors
                    Link(destination: URL(string: "https://github.com/sponsors/stephanjoseph")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                            Text("Sponsor on GitHub")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.pink.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    // Crypto addresses
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Or send crypto:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                        CryptoAddressRow(label: "BTC", address: "3Go9nJu3dj2qaa4EAYXrTsTf5AnhcrPQke")
                        CryptoAddressRow(label: "SOL", address: "FBvU83GUmwEYk3HMwZh3GBorGvrVVWSPb8VLCKeLiWZZ")
                        CryptoAddressRow(label: "ZEC", address: "t1PaQ7LSoRDVvXLaQTWmy5tKUAiKxuE9hBN")
                    }
                    .padding()
                    .background(.fill.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
            }
        }
        .frame(width: 420, height: 360)
    }
}

// MARK: - Crypto Address Row

private struct CryptoAddressRow: View {
    let label: String
    let address: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.blue)
                .frame(width: 36, alignment: .leading)

            Text(address)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(address, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(copied ? .green : .secondary)
        }
    }
}

// MARK: - Settings Gradient Background

struct SettingsGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                // Dark mode: beautiful glass effect
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

                // Subtle blue/purple tint
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.08),
                        Color.purple.opacity(0.05),
                        Color.blue.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // Light mode: soft, warm gradient - not stark white
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.92, green: 0.95, blue: 0.99),
                        Color(red: 0.94, green: 0.96, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Visual Effect Blur (NSVisualEffectView wrapper)

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Compact Components

struct CompactSection<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.white)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(colorScheme == .dark
                        ? Color.white.opacity(0.12)
                        : Color.blue.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: colorScheme == .dark ? .black.opacity(0.15) : .blue.opacity(0.08), radius: colorScheme == .dark ? 8 : 6, x: 0, y: 3)
            .padding(.horizontal, 2)
        }
    }
}

struct CompactRow<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct CompactToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct CompactDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 12)
    }
}

// MARK: - Glass Group Box Style

struct GlassGroupBoxStyle: GroupBoxStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            configuration.content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? .thickMaterial : .regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.06), radius: 4, y: 2)
    }
}

// MARK: - Settings Window Controller

@MainActor
enum SettingsWindowController {
    private static var window: NSWindow?

    static func open() {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "SaneClip Settings"
        newWindow.styleMask = [.titled, .closable, .resizable]
        newWindow.setContentSize(NSSize(width: 700, height: 450))
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        // Standard window - glass effect handled in SwiftUI view
        newWindow.hasShadow = true

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
