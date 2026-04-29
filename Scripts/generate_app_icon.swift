import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDir = root.appendingPathComponent("PDFReader/Resources/Assets.xcassets/AppIcon.appiconset")

struct IconSpec {
    let filename: String
    let pixels: Int
}

let specs: [IconSpec] = [
    IconSpec(filename: "AppIcon-20x20@1x.png", pixels: 20),
    IconSpec(filename: "AppIcon-20x20@2x.png", pixels: 40),
    IconSpec(filename: "AppIcon-20x20@3x.png", pixels: 60),
    IconSpec(filename: "AppIcon-29x29@1x.png", pixels: 29),
    IconSpec(filename: "AppIcon-29x29@2x.png", pixels: 58),
    IconSpec(filename: "AppIcon-29x29@3x.png", pixels: 87),
    IconSpec(filename: "AppIcon-40x40@1x.png", pixels: 40),
    IconSpec(filename: "AppIcon-40x40@2x.png", pixels: 80),
    IconSpec(filename: "AppIcon-40x40@3x.png", pixels: 120),
    IconSpec(filename: "AppIcon-60x60@2x.png", pixels: 120),
    IconSpec(filename: "AppIcon-60x60@3x.png", pixels: 180),
    IconSpec(filename: "AppIcon-76x76@1x.png", pixels: 76),
    IconSpec(filename: "AppIcon-76x76@2x.png", pixels: 152),
    IconSpec(filename: "AppIcon-83.5x83.5@2x.png", pixels: 167),
    IconSpec(filename: "AppIcon-1024x1024@1x.png", pixels: 1024)
]

func drawIcon(size: Int) -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
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
    ) else {
        fatalError("Could not create bitmap context")
    }

    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Could not create graphics context")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext

    let context = graphicsContext.cgContext

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            NSColor(calibratedRed: 0.95, green: 0.23, blue: 0.13, alpha: 1).cgColor,
            NSColor(calibratedRed: 1.00, green: 0.56, blue: 0.20, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.32, alpha: 1).cgColor
        ] as CFArray,
        locations: [0.0, 0.62, 1.0]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY),
        options: []
    )

    let scale = CGFloat(size)
    let shadowBlur = scale * 0.045
    context.setShadow(
        offset: CGSize(width: 0, height: -scale * 0.018),
        blur: shadowBlur,
        color: NSColor.black.withAlphaComponent(0.24).cgColor
    )

    let bookTop = scale * 0.30
    let bookBottom = scale * 0.72
    let leftOuter = scale * 0.18
    let rightOuter = scale * 0.82
    let centerX = scale * 0.50
    let fold = scale * 0.035

    let leftPage = CGMutablePath()
    leftPage.move(to: CGPoint(x: centerX - fold, y: bookBottom))
    leftPage.addCurve(
        to: CGPoint(x: leftOuter, y: bookBottom - scale * 0.05),
        control1: CGPoint(x: centerX - scale * 0.16, y: bookBottom + scale * 0.03),
        control2: CGPoint(x: leftOuter + scale * 0.05, y: bookBottom + scale * 0.01)
    )
    leftPage.addLine(to: CGPoint(x: leftOuter, y: bookTop))
    leftPage.addCurve(
        to: CGPoint(x: centerX - fold, y: bookTop + scale * 0.03),
        control1: CGPoint(x: leftOuter + scale * 0.12, y: bookTop - scale * 0.01),
        control2: CGPoint(x: centerX - scale * 0.16, y: bookTop + scale * 0.02)
    )
    leftPage.closeSubpath()

    let rightPage = CGMutablePath()
    rightPage.move(to: CGPoint(x: centerX + fold, y: bookBottom))
    rightPage.addCurve(
        to: CGPoint(x: rightOuter, y: bookBottom - scale * 0.05),
        control1: CGPoint(x: centerX + scale * 0.16, y: bookBottom + scale * 0.03),
        control2: CGPoint(x: rightOuter - scale * 0.05, y: bookBottom + scale * 0.01)
    )
    rightPage.addLine(to: CGPoint(x: rightOuter, y: bookTop))
    rightPage.addCurve(
        to: CGPoint(x: centerX + fold, y: bookTop + scale * 0.03),
        control1: CGPoint(x: rightOuter - scale * 0.12, y: bookTop - scale * 0.01),
        control2: CGPoint(x: centerX + scale * 0.16, y: bookTop + scale * 0.02)
    )
    rightPage.closeSubpath()

    context.setFillColor(NSColor.white.cgColor)
    context.addPath(leftPage)
    context.fillPath()
    context.addPath(rightPage)
    context.fillPath()

    context.setShadow(offset: .zero, blur: 0)
    context.setStrokeColor(NSColor(calibratedRed: 0.85, green: 0.23, blue: 0.14, alpha: 0.28).cgColor)
    context.setLineWidth(max(1, scale * 0.015))
    context.addPath(leftPage)
    context.strokePath()
    context.addPath(rightPage)
    context.strokePath()

    context.setStrokeColor(NSColor(calibratedRed: 0.74, green: 0.16, blue: 0.11, alpha: 0.18).cgColor)
    context.setLineWidth(max(1, scale * 0.010))
    for offset in [0.11, 0.18, 0.25] {
        context.move(to: CGPoint(x: leftOuter + scale * offset, y: bookTop + scale * 0.10))
        context.addCurve(
            to: CGPoint(x: centerX - scale * 0.07, y: bookTop + scale * (0.12 + offset * 0.08)),
            control1: CGPoint(x: leftOuter + scale * (offset + 0.06), y: bookTop + scale * 0.12),
            control2: CGPoint(x: centerX - scale * 0.13, y: bookTop + scale * 0.13)
        )
        context.strokePath()

        context.move(to: CGPoint(x: rightOuter - scale * offset, y: bookTop + scale * 0.10))
        context.addCurve(
            to: CGPoint(x: centerX + scale * 0.07, y: bookTop + scale * (0.12 + offset * 0.08)),
            control1: CGPoint(x: rightOuter - scale * (offset + 0.06), y: bookTop + scale * 0.12),
            control2: CGPoint(x: centerX + scale * 0.13, y: bookTop + scale * 0.13)
        )
        context.strokePath()
    }

    let bookmarkPath = CGMutablePath()
    bookmarkPath.move(to: CGPoint(x: centerX + scale * 0.12, y: bookBottom + scale * 0.02))
    bookmarkPath.addLine(to: CGPoint(x: centerX + scale * 0.22, y: bookBottom - scale * 0.005))
    bookmarkPath.addLine(to: CGPoint(x: centerX + scale * 0.22, y: bookTop + scale * 0.16))
    bookmarkPath.addLine(to: CGPoint(x: centerX + scale * 0.17, y: bookTop + scale * 0.11))
    bookmarkPath.addLine(to: CGPoint(x: centerX + scale * 0.12, y: bookTop + scale * 0.16))
    bookmarkPath.closeSubpath()
    context.setFillColor(NSColor(calibratedRed: 0.08, green: 0.16, blue: 0.24, alpha: 1).cgColor)
    context.addPath(bookmarkPath)
    context.fillPath()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

for spec in specs {
    let bitmap = drawIcon(size: spec.pixels)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not render \(spec.filename)")
    }
    try png.write(to: outputDir.appendingPathComponent(spec.filename), options: .atomic)
}
