#!/usr/bin/env swift

import Cocoa
import CoreGraphics
import UniformTypeIdentifiers

// Configuration - must match create-dmg --window-size exactly
// Background fills the OUTER window bounds (600x400 includes title bar)
// Title bar is ~28pt on modern macOS, so top 28px should be solid bg color
let widthPt = 600
let heightPt = 400
let outputDir = "scripts/dmg-resources"

// Icon positions from create-dmg (in points, origin top-left of window)
let appIconX = 150
let dropLinkX = 450
let iconFinderY = 190  // from top
let iconSize = 100     // --icon-size

func generateBackground(scaleFactor: Int, outputPath: String, dpi: Int) {
    let w = widthPt * scaleFactor
    let h = heightPt * scaleFactor
    let sf = CGFloat(scaleFactor)

    // Convert icon positions to pixel coords (CG origin = bottom-left)
    let dropXpx = CGFloat(dropLinkX) * sf
    let appXpx = CGFloat(appIconX) * sf
    let iconYpx = CGFloat(heightPt - iconFinderY) * sf
    let iconSzPx = CGFloat(iconSize) * sf

    // Create bitmap context
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: w, height: h,
        bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("Failed to create context for \(scaleFactor)x")
        exit(1)
    }

    // 1. Fill background - dark navy matching app icon
    ctx.setFillColor(NSColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 1.0).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

    // 2. Subtle gradient
    let gradColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.03),
        CGColor(red: 0, green: 0, blue: 0, alpha: 0)
    ]
    if let grad = CGGradient(colorsSpace: colorSpace, colors: gradColors as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(grad,
            start: CGPoint(x: CGFloat(w) / 2, y: CGFloat(h)),
            end: CGPoint(x: CGFloat(w) / 2, y: 0), options: [])
    }

    // 3. Arrow
    let arrowStart = appXpx + 62 * sf
    let arrowEnd = dropXpx - 62 * sf
    let headSz: CGFloat = 14 * sf

    let line = CGMutablePath()
    line.move(to: CGPoint(x: arrowStart, y: iconYpx))
    line.addLine(to: CGPoint(x: arrowEnd, y: iconYpx))

    let head = CGMutablePath()
    head.move(to: CGPoint(x: arrowEnd - headSz, y: iconYpx + headSz * 0.6))
    head.addLine(to: CGPoint(x: arrowEnd, y: iconYpx))
    head.addLine(to: CGPoint(x: arrowEnd - headSz, y: iconYpx - headSz * 0.6))

    let arrowColor = NSColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 0.7).cgColor
    ctx.setShadow(offset: .zero, blur: 10 * sf, color: NSColor(red: 0, green: 0.6, blue: 1, alpha: 0.4).cgColor)
    ctx.setStrokeColor(arrowColor)
    ctx.setLineWidth(3 * sf)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(line); ctx.strokePath()
    ctx.addPath(head); ctx.strokePath()

    // 7. Save PNG with specified DPI
    guard let cgImage = ctx.makeImage() else {
        print("Failed to create image"); exit(1)
    }

    let destURL = URL(fileURLWithPath: outputPath) as CFURL
    guard let dest = CGImageDestinationCreateWithURL(destURL, UTType.png.identifier as CFString, 1, nil) else {
        print("Failed to create destination"); exit(1)
    }

    let props: [CFString: Any] = [
        kCGImagePropertyDPIWidth: Double(dpi),
        kCGImagePropertyDPIHeight: Double(dpi)
    ]
    CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)

    guard CGImageDestinationFinalize(dest) else {
        print("Failed to save \(outputPath)"); exit(1)
    }
    print("  \(scaleFactor)x: \(w)x\(h)px @ \(dpi)dpi → \(outputPath)")
}

// Generate 1x (72 DPI) and 2x (144 DPI)
print("Generating DMG backgrounds...")
let bg1x = "\(outputDir)/dmg-background.png"
let bg2x = "\(outputDir)/dmg-background@2x.png"

generateBackground(scaleFactor: 1, outputPath: bg1x, dpi: 72)
generateBackground(scaleFactor: 2, outputPath: bg2x, dpi: 144)

print("Done. Bundle into TIFF with:")
print("  tiffutil -cathidpicheck \(bg1x) \(bg2x) -out \(outputDir)/dmg-background.tiff")
