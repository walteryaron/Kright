#!/usr/bin/env swift
// Renders the DMG window background: a clean light panel with a subtle ">"
// chevron between where the app icon and the Applications folder sit.
// 660×440 (matches the window in build-dmg.sh). Writes PNG to arg 1.
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/kright-dmg-bg.png"
let W: CGFloat = 660, H: CGFloat = 440

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// AppKit y is bottom-up; Finder icon positions are top-down.
func top(_ y: CGFloat) -> CGFloat { H - y }

// Soft light-lavender panel (subtle vertical gradient).
NSGradient(starting: NSColor(srgbRed: 0.945, green: 0.945, blue: 0.96, alpha: 1),
           ending:   NSColor(srgbRed: 0.90,  green: 0.905, blue: 0.93, alpha: 1))!
    .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

// A thin ">" chevron centered between the two icons (which sit at x≈180 / x≈480,
// y≈250 from the top).
let cx: CGFloat = 330, cy = top(250), d: CGFloat = 26, reach: CGFloat = 16
let chevron = NSBezierPath()
chevron.lineWidth = 11
chevron.lineCapStyle = .round
chevron.lineJoinStyle = .round
chevron.move(to: NSPoint(x: cx - reach, y: cy + d))
chevron.line(to: NSPoint(x: cx + reach, y: cy))
chevron.line(to: NSPoint(x: cx - reach, y: cy - d))
NSColor(white: 0.30, alpha: 1).setStroke()
chevron.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
