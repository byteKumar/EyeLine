// Renders the app icon: a dark tile with a notch-shaped prompter, text lines and the warm voice glow.
// Usage: swift scripts/make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "icon.png"
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Tile (macOS icon grid: 824pt body inside 1024 canvas).
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.addPath(tilePath); ctx.clip()
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [NSColor(calibratedRed: 0.20, green: 0.21, blue: 0.25, alpha: 1).cgColor,
                             NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.09, alpha: 1).cgColor] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

// Prompter panel hanging from the top edge.
let panel = CGRect(x: 232, y: 470, width: 560, height: 454)
let p = CGMutablePath()
let r: CGFloat = 90
p.move(to: CGPoint(x: panel.minX, y: panel.maxY))
p.addLine(to: CGPoint(x: panel.minX, y: panel.minY + r))
p.addArc(tangent1End: CGPoint(x: panel.minX, y: panel.minY), tangent2End: CGPoint(x: panel.minX + r, y: panel.minY), radius: r)
p.addLine(to: CGPoint(x: panel.maxX - r, y: panel.minY))
p.addArc(tangent1End: CGPoint(x: panel.maxX, y: panel.minY), tangent2End: CGPoint(x: panel.maxX, y: panel.minY + r), radius: r)
p.addLine(to: CGPoint(x: panel.maxX, y: panel.maxY))
p.closeSubpath()
ctx.saveGState()
ctx.addPath(p); ctx.clip()
ctx.setFillColor(NSColor.black.cgColor); ctx.fill(panel)

// Glow at the bottom of the panel.
let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [NSColor(calibratedRed: 1, green: 0.84, blue: 0.45, alpha: 0.95).cgColor,
                               NSColor(calibratedRed: 1, green: 0.62, blue: 0.25, alpha: 0.35).cgColor,
                               NSColor(calibratedRed: 1, green: 0.6, blue: 0.2, alpha: 0).cgColor] as CFArray,
                      locations: [0, 0.45, 1])!
ctx.saveGState()
ctx.translateBy(x: 512, y: panel.minY + 10); ctx.scaleBy(x: 1.7, y: 0.75)
ctx.drawRadialGradient(glow, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 210, options: [])
ctx.restoreGState()

// Text lines.
ctx.setFillColor(NSColor(white: 1, alpha: 0.95).cgColor)
for (i, w) in [380.0, 440.0, 330.0].enumerated() {
    let y = 800 - CGFloat(i) * 92
    ctx.addPath(CGPath(roundedRect: CGRect(x: 512 - w / 2, y: y, width: w, height: 40), cornerWidth: 20, cornerHeight: 20, transform: nil))
}
ctx.fillPath()
ctx.restoreGState()

// Camera dot.
ctx.setFillColor(NSColor(white: 0.25, alpha: 1).cgColor)
ctx.fillEllipse(in: CGRect(x: 494, y: 884, width: 36, height: 36))
ctx.setFillColor(NSColor(calibratedRed: 0.2, green: 0.35, blue: 0.55, alpha: 1).cgColor)
ctx.fillEllipse(in: CGRect(x: 504, y: 894, width: 16, height: 16))

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
