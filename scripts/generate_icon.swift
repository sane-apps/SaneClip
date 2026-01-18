#!/usr/bin/env swift
// swiftlint:disable all

import AppKit
import Foundation

// Generate app icons matching SaneBar's dark navy + cyan glow style
let sizes: [(name: String, size: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024)
]

let outputDir = "Resources/Assets.xcassets/AppIcon.appiconset"

func createIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let sizeF = CGFloat(size)

    // SaneBar-style dark navy gradient background
    let darkNavy = NSColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1.0)
    let midNavy = NSColor(red: 0.12, green: 0.15, blue: 0.25, alpha: 1.0)

    // Fill with dark base
    darkNavy.setFill()
    rect.fill()

    // Add subtle lighter center gradient
    let centerGradient = NSGradient(colors: [
        midNavy.withAlphaComponent(0.8),
        darkNavy.withAlphaComponent(0.0)
    ])!
    let gradientPath = NSBezierPath(ovalIn: rect.insetBy(dx: -sizeF * 0.2, dy: -sizeF * 0.2))
    centerGradient.draw(in: gradientPath, relativeCenterPosition: NSPoint(x: 0, y: 0))

    // Cyan accent color (matching SaneBar's glow)
    let cyanGlow = NSColor(red: 0.35, green: 0.70, blue: 0.85, alpha: 1.0)

    // Draw clipboard shape
    let clipboardWidth = sizeF * 0.5
    let clipboardHeight = sizeF * 0.6
    let clipX = (sizeF - clipboardWidth) / 2
    let clipY = (sizeF - clipboardHeight) / 2 - sizeF * 0.02

    let clipboardRect = NSRect(x: clipX, y: clipY, width: clipboardWidth, height: clipboardHeight)
    let clipRadius = sizeF * 0.04

    // Glow effect (draw larger blurred version behind)
    let glowColor = cyanGlow.withAlphaComponent(0.4)
    glowColor.setFill()
    let glowRect = clipboardRect.insetBy(dx: -sizeF * 0.03, dy: -sizeF * 0.03)
    let glowPath = NSBezierPath(roundedRect: glowRect, xRadius: clipRadius * 1.5, yRadius: clipRadius * 1.5)
    glowPath.fill()

    // Main clipboard body
    cyanGlow.setFill()
    let clipPath = NSBezierPath(roundedRect: clipboardRect, xRadius: clipRadius, yRadius: clipRadius)
    clipPath.fill()

    // Clipboard clip at top
    let clipTabWidth = sizeF * 0.2
    let clipTabHeight = sizeF * 0.08
    let clipTabX = (sizeF - clipTabWidth) / 2
    let clipTabY = clipY + clipboardHeight - clipTabHeight * 0.5
    let clipTabRect = NSRect(x: clipTabX, y: clipTabY, width: clipTabWidth, height: clipTabHeight)
    let clipTabPath = NSBezierPath(roundedRect: clipTabRect, xRadius: sizeF * 0.02, yRadius: sizeF * 0.02)
    clipTabPath.fill()

    // Dark lines on clipboard (representing text/content)
    let lineColor = darkNavy
    lineColor.setFill()

    let lineHeight = sizeF * 0.025
    let lineSpacing = sizeF * 0.06
    let lineInset = sizeF * 0.08
    let lineStartY = clipY + clipboardHeight * 0.6

    for i in 0..<3 {
        let lineWidth = i == 2 ? clipboardWidth * 0.5 : clipboardWidth - lineInset * 2
        let lineX = clipX + lineInset
        let lineY = lineStartY - CGFloat(i) * lineSpacing
        let lineRect = NSRect(x: lineX, y: lineY, width: lineWidth, height: lineHeight)
        let linePath = NSBezierPath(roundedRect: lineRect, xRadius: lineHeight / 2, yRadius: lineHeight / 2)
        linePath.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// Generate all sizes
for (name, size) in sizes {
    let rep = createIcon(size: size)
    if let pngData = rep.representation(using: .png, properties: [:]) {
        let url = URL(fileURLWithPath: "\(outputDir)/\(name).png")
        try? pngData.write(to: url)
        print("Generated: \(name).png (\(size)x\(size))")
    }
}

// Update Contents.json
let contentsJson = """
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""

try? contentsJson.write(toFile: "\(outputDir)/Contents.json", atomically: true, encoding: .utf8)
print("Done! SaneBar-style icons generated.")
