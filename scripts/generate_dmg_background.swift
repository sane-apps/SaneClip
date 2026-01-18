#!/usr/bin/env swift

import Cocoa
import CoreGraphics
import UniformTypeIdentifiers

// Configuration
let width = 660
let height = 400
let scale: CGFloat = 2.0 // Retina support
let outputPath = "scripts/dmg-resources/dmg-background.png"

// Create context
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
let context = CGContext(
    data: nil,
    width: Int(CGFloat(width) * scale),
    height: Int(CGFloat(height) * scale),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: bitmapInfo.rawValue
)!

// Scale for Retina
context.scaleBy(x: scale, y: scale)

// 1. Fill Background
// Dark Navy matching app icon style (approx #141A2E)
let backgroundColor = NSColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1.0)
context.setFillColor(backgroundColor.cgColor)
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

// 2. Draw "Install SaneClip" Text
let title = "SaneClip" as NSString
let subTitle = "Drag to Applications to install" as NSString

let titleFont = NSFont.systemFont(ofSize: 36, weight: .bold)
let subTitleFont = NSFont.systemFont(ofSize: 14, weight: .medium)
let textColor = NSColor.white

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: textColor
]
let subTitleAttributes: [NSAttributedString.Key: Any] = [
    .font: subTitleFont,
    .foregroundColor: NSColor(white: 0.8, alpha: 1.0)
]

let titleSize = title.size(withAttributes: titleAttributes)
let subTitleSize = subTitle.size(withAttributes: subTitleAttributes)

// Draw Title centered horizontally, near top
// Add shadow for better contrast/depth
context.setShadow(offset: CGSize(width: 0, height: -2), blur: 4, color: NSColor.black.withAlphaComponent(0.3).cgColor)

let titleRect = CGRect(
    x: (CGFloat(width) - titleSize.width) / 2.0,
    y: CGFloat(height) - 80, // Top area
    width: titleSize.width,
    height: titleSize.height
)
title.draw(in: titleRect, withAttributes: titleAttributes)

// Draw Subtitle below title
let subTitleRect = CGRect(
    x: (CGFloat(width) - subTitleSize.width) / 2.0,
    y: CGFloat(height) - 110,
    width: subTitleSize.width,
    height: subTitleSize.height
)
subTitle.draw(in: subTitleRect, withAttributes: subTitleAttributes)

// Reset shadow for other elements if needed, but keeping it for arrow is fine
// context.setShadow(offset: .zero, blur: 0, color: nil)

// 3. Draw Applications Folder Icon (visible against dark background)
// Position: 500, 220 from top (center of icon) -> 500, 180 from bottom
let folderCenterX: CGFloat = 500
let folderCenterY: CGFloat = 180
let folderSize: CGFloat = 80

// Draw folder shape with light gray/white outline
let folderPath = CGMutablePath()

// Folder body - rounded rectangle
let folderBodyRect = CGRect(
    x: folderCenterX - folderSize/2,
    y: folderCenterY - folderSize/2.5,
    width: folderSize,
    height: folderSize * 0.65
)
folderPath.addRoundedRect(in: folderBodyRect, cornerWidth: 6, cornerHeight: 6)

// Folder tab at top
let tabWidth = folderSize * 0.4
let tabHeight: CGFloat = 12
let tabRect = CGRect(
    x: folderCenterX - folderSize/2 + 8,
    y: folderCenterY + folderSize * 0.15,
    width: tabWidth,
    height: tabHeight
)
folderPath.addRoundedRect(in: tabRect, cornerWidth: 3, cornerHeight: 3)

context.addPath(folderPath)
// Subtle fill
let folderFillColor = NSColor(white: 0.25, alpha: 1.0)
context.setFillColor(folderFillColor.cgColor)
context.fillPath()

// Draw outline
context.addPath(folderPath)
let folderStrokeColor = NSColor(white: 0.6, alpha: 1.0)
context.setStrokeColor(folderStrokeColor.cgColor)
context.setLineWidth(2.0)
context.strokePath()

// 4. Draw Arrow (between app icon and folder)
// Positions from release.sh: App (160, 220), Link (500, 220)
// Center Y is 220 from top -> 180 from bottom.

let startX: CGFloat = 210 // Start after App Icon
let endX: CGFloat = 450   // End before App Drop Link
let yPos: CGFloat = 180

let arrowPath = CGMutablePath()
arrowPath.move(to: CGPoint(x: startX, y: yPos))
arrowPath.addLine(to: CGPoint(x: endX, y: yPos))

// Arrow head
let arrowHeadSize: CGFloat = 12
arrowPath.move(to: CGPoint(x: endX - arrowHeadSize, y: yPos + arrowHeadSize/2.0))
arrowPath.addLine(to: CGPoint(x: endX, y: yPos))
arrowPath.addLine(to: CGPoint(x: endX - arrowHeadSize, y: yPos - arrowHeadSize/2.0))

context.addPath(arrowPath)

// Cyan accent color
let arrowColor = NSColor(red: 0.35, green: 0.70, blue: 0.85, alpha: 1.0)
context.setStrokeColor(arrowColor.cgColor)
context.setLineWidth(4.0)
context.setLineCap(.round)
context.setLineJoin(.round)

// Add specific shadow for arrow (glow effect)
context.setShadow(offset: .zero, blur: 8, color: arrowColor.withAlphaComponent(0.5).cgColor)

context.strokePath()

// 5. Save Image
guard let image = context.makeImage() else {
    print("Failed to create image")
    exit(1)
}

let destURL = URL(fileURLWithPath: outputPath)
let destination = CGImageDestinationCreateWithURL(destURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
if CGImageDestinationFinalize(destination) {
    print("Generated premium DMG background at \(outputPath)")
} else {
    print("Failed to save image")
    exit(1)
}
