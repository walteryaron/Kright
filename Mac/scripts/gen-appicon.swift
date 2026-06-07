#!/usr/bin/env swift
// Renders the Kright app icon: a macOS-style rounded-square with a blue gradient
// and a white keyboard glyph. Writes a 1024×1024 PNG to the path given as arg 1.
//
//   swift scripts/gen-appicon.swift /tmp/kright-icon-1024.png
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/kright-icon-1024.png"
let S: CGFloat = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Rounded-square plate (macOS icon grid: ~824 inset in 1024, radius ~0.225·side).
let inset: CGFloat = 100
let plate = NSRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
let radius = plate.width * 0.225
let path = NSBezierPath(roundedRect: plate, xRadius: radius, yRadius: radius)

// Blue vertical gradient.
let top = NSColor(srgbRed: 0.36, green: 0.58, blue: 1.00, alpha: 1)
let bottom = NSColor(srgbRed: 0.16, green: 0.34, blue: 0.86, alpha: 1)
NSGradient(starting: top, ending: bottom)!.draw(in: path, angle: -90)

// Subtle top highlight for depth.
path.addClip()
NSGradient(starting: NSColor(white: 1, alpha: 0.18), ending: NSColor(white: 1, alpha: 0))!
    .draw(in: NSRect(x: plate.minX, y: plate.midY, width: plate.width, height: plate.height / 2), angle: -90)
NSGraphicsContext.current?.cgContext.resetClip()

// White keyboard glyph, centered.
let config = NSImage.SymbolConfiguration(pointSize: 540, weight: .regular)
let sym = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)!
    .withSymbolConfiguration(config)!
let tinted = NSImage(size: sym.size)
tinted.lockFocus()
NSColor.white.set()
let symRect = NSRect(origin: .zero, size: sym.size)
sym.draw(in: symRect)
symRect.fill(using: .sourceAtop)
tinted.unlockFocus()

let g = tinted.size
let drawRect = NSRect(x: (S - g.width) / 2, y: (S - g.height) / 2, width: g.width, height: g.height)
tinted.draw(in: drawRect)

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
try! data.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
