#!/usr/bin/env swift
// swiftlint:disable all

import AppKit
import Foundation
import CoreGraphics
import UniformTypeIdentifiers

// Generate app icons matching marketing design: cyan outline clipboard with neon glow
// Output: opaque full-square PNGs (no alpha, no squircle — macOS applies its own mask)
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

// Colors matching marketing icon
let darkNavy = NSColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 1.0)
let midNavy = NSColor(red: 0.10, green: 0.13, blue: 0.22, alpha: 1.0)
let cyanBright = NSColor(red: 0.30, green: 0.90, blue: 1.0, alpha: 1.0)
let cyanMid = NSColor(red: 0.20, green: 0.70, blue: 0.85, alpha: 1.0)
let cyanDeep = NSColor(red: 0.10, green: 0.50, blue: 0.70, alpha: 1.0)

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
    let s = CGFloat(size)

    // === BACKGROUND ===
    // Full-square dark navy base
    darkNavy.setFill()
    rect.fill()

    // Subtle radial glow behind clipboard area
    let bgGradient = NSGradient(colors: [
        midNavy.withAlphaComponent(0.7),
        darkNavy.withAlphaComponent(0.0)
    ])!
    let bgGlowRect = rect.insetBy(dx: -s * 0.05, dy: -s * 0.05)
    bgGradient.draw(in: NSBezierPath(ovalIn: bgGlowRect), relativeCenterPosition: NSPoint(x: 0, y: 0.05))

    // === CLIPBOARD GEOMETRY ===
    let clipW = s * 0.52
    let clipH = s * 0.58
    let clipX = (s - clipW) / 2
    let clipY = (s - clipH) / 2 - s * 0.03
    let clipRect = NSRect(x: clipX, y: clipY, width: clipW, height: clipH)
    let clipRadius = s * 0.045

    let strokeW = max(s * 0.028, 1.5)

    // === GLOW EFFECT (multiple soft layers) ===
    // Wide outer glow
    for i in stride(from: 6, through: 1, by: -1) {
        let spread = CGFloat(i) * s * 0.018
        let alpha = 0.06 * (1.0 / CGFloat(i))
        cyanDeep.withAlphaComponent(alpha).setStroke()
        let glowRect = clipRect.insetBy(dx: -spread, dy: -spread)
        let glowPath = NSBezierPath(roundedRect: glowRect, xRadius: clipRadius + spread * 0.4, yRadius: clipRadius + spread * 0.4)
        glowPath.lineWidth = strokeW + spread * 1.5
        glowPath.stroke()
    }

    // Medium glow (brighter)
    for i in stride(from: 3, through: 1, by: -1) {
        let spread = CGFloat(i) * s * 0.008
        let alpha = 0.15 * (1.0 / CGFloat(i))
        cyanBright.withAlphaComponent(alpha).setStroke()
        let glowRect = clipRect.insetBy(dx: -spread, dy: -spread)
        let glowPath = NSBezierPath(roundedRect: glowRect, xRadius: clipRadius + spread * 0.3, yRadius: clipRadius + spread * 0.3)
        glowPath.lineWidth = strokeW * 2.0
        glowPath.stroke()
    }

    // === CLIPBOARD OUTLINE ===
    // Base stroke (deeper cyan)
    cyanMid.setStroke()
    let clipPath = NSBezierPath(roundedRect: clipRect, xRadius: clipRadius, yRadius: clipRadius)
    clipPath.lineWidth = strokeW
    clipPath.stroke()

    // Bright highlight stroke on top
    cyanBright.setStroke()
    let brightPath = NSBezierPath(roundedRect: clipRect, xRadius: clipRadius, yRadius: clipRadius)
    brightPath.lineWidth = strokeW * 0.5
    brightPath.stroke()

    // === CLIP TAB ===
    let tabW = s * 0.24
    let tabH = s * 0.10
    let tabX = (s - tabW) / 2
    let tabY = clipY + clipH - tabH * 0.45
    let tabRect = NSRect(x: tabX, y: tabY, width: tabW, height: tabH)
    let tabRadius = s * 0.028

    // Tab glow
    cyanDeep.withAlphaComponent(0.2).setStroke()
    let tabGlowPath = NSBezierPath(roundedRect: tabRect.insetBy(dx: -s * 0.01, dy: -s * 0.01), xRadius: tabRadius + s * 0.005, yRadius: tabRadius + s * 0.005)
    tabGlowPath.lineWidth = strokeW * 2
    tabGlowPath.stroke()

    // Tab fill (dark, slightly lighter than background)
    NSColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: tabRect, xRadius: tabRadius, yRadius: tabRadius).fill()

    // Tab outline
    cyanMid.setStroke()
    let tabOutline = NSBezierPath(roundedRect: tabRect, xRadius: tabRadius, yRadius: tabRadius)
    tabOutline.lineWidth = strokeW * 0.8
    tabOutline.stroke()

    // Bright tab highlight
    cyanBright.withAlphaComponent(0.7).setStroke()
    let tabBright = NSBezierPath(roundedRect: tabRect, xRadius: tabRadius, yRadius: tabRadius)
    tabBright.lineWidth = strokeW * 0.35
    tabBright.stroke()

    // Circle hole in tab
    let holeSize = s * 0.038
    let holeX = (s - holeSize) / 2
    let holeY = tabY + (tabH - holeSize) / 2
    let holeRect = NSRect(x: holeX, y: holeY, width: holeSize, height: holeSize)

    cyanMid.withAlphaComponent(0.8).setStroke()
    let holePath = NSBezierPath(ovalIn: holeRect)
    holePath.lineWidth = strokeW * 0.6
    holePath.stroke()

    // === TEXT LINES (cyan on dark) ===
    let lineH = max(s * 0.024, 1.0)
    let lineSpacing = s * 0.065
    let lineInset = s * 0.10
    let lineStartY = clipY + clipH * 0.52

    for i in 0..<4 {
        let lineW = i == 3 ? clipW * 0.45 : clipW - lineInset * 2
        let lineX = clipX + lineInset
        let lineY = lineStartY - CGFloat(i) * lineSpacing
        let lineRect = NSRect(x: lineX, y: lineY, width: lineW, height: lineH)

        // Line glow
        cyanBright.withAlphaComponent(0.12).setFill()
        let lineGlowRect = lineRect.insetBy(dx: -s * 0.005, dy: -s * 0.005)
        NSBezierPath(roundedRect: lineGlowRect, xRadius: lineH, yRadius: lineH).fill()

        // Line fill
        cyanMid.withAlphaComponent(0.85).setFill()
        NSBezierPath(roundedRect: lineRect, xRadius: lineH / 2, yRadius: lineH / 2).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// Generate all sizes, flatten to opaque output
for (name, size) in sizes {
    let rep = createIcon(size: size)

    // Flatten onto opaque CGContext (no alpha in final PNG)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let opaqueCtx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        print("FAIL: \(name) opaque context"); continue
    }

    // Fill with dark navy background
    opaqueCtx.setFillColor(CGColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 1.0))
    opaqueCtx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // Composite icon drawing on top
    if let cgImg = rep.cgImage {
        opaqueCtx.draw(cgImg, in: CGRect(x: 0, y: 0, width: size, height: size))
    }

    // Save as opaque PNG
    guard let finalImage = opaqueCtx.makeImage() else {
        print("FAIL: \(name) makeImage"); continue
    }

    let url = URL(fileURLWithPath: "\(outputDir)/\(name).png") as CFURL
    guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
        print("FAIL: \(name) dest"); continue
    }
    CGImageDestinationAddImage(dest, finalImage, nil)
    CGImageDestinationFinalize(dest)
    print("Generated: \(name).png (\(size)x\(size)) [opaque]")
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
print("Done! Marketing-style icons generated (opaque, full-square, no white border).")
