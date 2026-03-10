import AppKit
import Foundation

// Entry point for SaneClip
// Using manual main.swift instead of @main to control initialization timing

let app = NSApplication.shared

// Set activation policy to .accessory - this is a menu bar app
app.setActivationPolicy(.accessory)
app.appearance = NSAppearance(named: .darkAqua)

let mainMenu = NSMenu()
let appMenuItem = NSMenuItem()
mainMenu.addItem(appMenuItem)

let appMenu = NSMenu()
let quitItem = NSMenuItem(title: "Quit SaneClip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
quitItem.keyEquivalentModifierMask = [.command]
appMenu.addItem(quitItem)
appMenuItem.submenu = appMenu
app.mainMenu = mainMenu

let delegate = SaneClipAppDelegate()
app.delegate = delegate
app.run()
