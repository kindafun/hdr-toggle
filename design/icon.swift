// Renders the HDR Toggle app icon.
// Usage: swift design/icon.swift assets/icon.png
//
// Design: a monitor silhouette on a charcoal tile. The screen is split at 42%:
// muted slate on the left (SDR), pure white on the right (HDR). No text, so it
// survives translation and small sizes.

import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets/icon.png"
let side: CGFloat = 1024
let radius: CGFloat = 224

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
  NSColor(
    srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
    green: CGFloat((hex >> 8) & 0xff) / 255,
    blue: CGFloat(hex & 0xff) / 255,
    alpha: alpha
  )
}

guard
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(side), pixelsHigh: Int(side),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
  ),
  let context = NSGraphicsContext(bitmapImageRep: rep)
else {
  FileHandle.standardError.write(Data("icon: could not create bitmap context\n".utf8))
  exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let ctx = context.cgContext
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

func rounded(_ rect: CGRect, _ r: CGFloat) -> CGPath {
  CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}

func fill(_ rect: CGRect, r: CGFloat, _ fillColor: NSColor) {
  ctx.addPath(rounded(rect, r))
  ctx.setFillColor(fillColor.cgColor)
  ctx.fillPath()
}

// Tile with a shallow vertical gradient.
ctx.saveGState()
ctx.addPath(rounded(CGRect(x: 0, y: 0, width: side, height: side), radius))
ctx.clip()
let tile = CGGradient(
  colorsSpace: CGColorSpaceCreateDeviceRGB(),
  colors: [color(0x1B1F25).cgColor, color(0x0B0D10).cgColor] as CFArray,
  locations: [0, 1]
)!
ctx.drawLinearGradient(tile, start: CGPoint(x: 0, y: side), end: CGPoint(x: 0, y: 0), options: [])

// Faint light spill from the bright half.
let spill = CGGradient(
  colorsSpace: CGColorSpaceCreateDeviceRGB(),
  colors: [color(0xFFFFFF, 0.10).cgColor, color(0xFFFFFF, 0).cgColor] as CFArray,
  locations: [0, 1]
)!
ctx.drawRadialGradient(
  spill,
  startCenter: CGPoint(x: 690, y: 545), startRadius: 0,
  endCenter: CGPoint(x: 690, y: 545), endRadius: 360,
  options: []
)
ctx.restoreGState()

// Bezel and stand.
fill(CGRect(x: 196, y: 340, width: 632, height: 420), r: 36, color(0x2A3038))
fill(CGRect(x: 492, y: 296, width: 40, height: 48), r: 6, color(0x2A3038))
fill(CGRect(x: 388, y: 260, width: 248, height: 40), r: 20, color(0x2A3038))

// Screen, clipped so the two halves stay inside the rounded corners.
let screen = CGRect(x: 214, y: 358, width: 596, height: 384)
ctx.saveGState()
ctx.addPath(rounded(screen, 22))
ctx.clip()

let split = screen.minX + screen.width * 0.42
ctx.setFillColor(color(0x414B59).cgColor)
ctx.fill(CGRect(x: screen.minX, y: screen.minY, width: split - screen.minX, height: screen.height))
ctx.setFillColor(NSColor.white.cgColor)
ctx.fill(CGRect(x: split, y: screen.minY, width: screen.maxX - split, height: screen.height))

// A whisper of falloff in the bright half so it reads as light, not paint.
let glow = CGGradient(
  colorsSpace: CGColorSpaceCreateDeviceRGB(),
  colors: [color(0xFFFFFF, 0).cgColor, color(0xF4F8FF, 0.55).cgColor] as CFArray,
  locations: [0, 1]
)!
ctx.drawLinearGradient(
  glow,
  start: CGPoint(x: split, y: 0),
  end: CGPoint(x: screen.maxX, y: 0),
  options: []
)
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
  FileHandle.standardError.write(Data("icon: could not encode PNG\n".utf8))
  exit(1)
}

do {
  try png.write(to: URL(fileURLWithPath: output))
  print("wrote \(output) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
} catch {
  FileHandle.standardError.write(Data("icon: \(error)\n".utf8))
  exit(1)
}
