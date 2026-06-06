#!/usr/bin/env swift
// Renders the DMG window background: title, subtitle, and an arrow pointing from
// the app icon to the Applications folder. 660×440 (matches the window in
// build-dmg.sh). Writes PNG to the path given as arg 1.
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/kysy-dmg-bg.png"
let W: CGFloat = 660, H: CGFloat = 440

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// AppKit y is bottom-up; Finder positions are top-down. Convert top→appkit.
func top(_ y: CGFloat) -> CGFloat { H - y }

// Soft light background (white → faint blue), so dark app/folder icons read well.
NSGradient(starting: NSColor(srgbRed: 0.98, green: 0.98, blue: 0.99, alpha: 1),
           ending:   NSColor(srgbRed: 0.91, green: 0.94, blue: 1.00, alpha: 1))!
    .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

// Title + subtitle (near the top).
func drawText(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centerY topY: CGFloat) {
    let style = NSMutableParagraphStyle(); style.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color, .paragraphStyle: style]
    let str = NSAttributedString(string: s, attributes: attrs)
    let h = str.size().height
    str.draw(in: NSRect(x: 0, y: top(topY) - h / 2, width: W, height: h))
}
drawText("Kysy", size: 34, weight: .bold, color: NSColor(white: 0.12, alpha: 1), centerY: 64)
drawText("Drag Kysy onto the Applications folder to install",
         size: 14, weight: .regular, color: NSColor(white: 0.42, alpha: 1), centerY: 104)

// Arrow from the app (x≈180) to Applications (x≈480), at the icon row (y≈250).
let cy = top(250)
let x0: CGFloat = 268, x1: CGFloat = 392
let blue = NSColor(srgbRed: 0.23, green: 0.51, blue: 0.96, alpha: 1)
blue.setStroke(); blue.setFill()
let shaft = NSBezierPath()
shaft.lineWidth = 12; shaft.lineCapStyle = .round
shaft.move(to: NSPoint(x: x0, y: cy))
shaft.line(to: NSPoint(x: x1, y: cy))
shaft.stroke()
let head = NSBezierPath()                       // triangle arrowhead
head.move(to: NSPoint(x: x1 + 26, y: cy))
head.line(to: NSPoint(x: x1 - 6, y: cy + 22))
head.line(to: NSPoint(x: x1 - 6, y: cy - 22))
head.close(); head.fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
