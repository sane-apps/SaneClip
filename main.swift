import AppKit
import Foundation

// Entry point for SaneClip
// Using manual main.swift instead of @main to control initialization timing

let app = NSApplication.shared

// Set activation policy to .accessory - this is a menu bar app
app.setActivationPolicy(.accessory)
app.appearance = NSAppearance(named: .darkAqua)

let delegate = SaneClipAppDelegate()
app.delegate = delegate
app.run()
