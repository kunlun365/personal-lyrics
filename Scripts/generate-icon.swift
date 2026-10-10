import AppKit

// Renders a simple 1024x1024 rounded-square app icon (green gradient + music note glyph)
// and writes it as PNG to the path given as the first argument. Run once via
// `swift Scripts/generate-icon.swift <output.png>`; the resulting PNG is then converted
// to .icns by Scripts/generate-icon.sh. Not part of the app target.

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write("usage: generate-icon.swift <output.png>\n".data(using: .utf8)!)
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let size: CGFloat = 1024
let cornerRadius = size * 0.2237

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
path.addClip()

let gradient = NSGradient(
    starting: NSColor(calibratedRed: 0.16, green: 0.82, blue: 0.42, alpha: 1),
    ending: NSColor(calibratedRed: 0.04, green: 0.42, blue: 0.22, alpha: 1)
)
gradient?.draw(in: rect, angle: -90)

if let symbol = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .semibold)
    let symbolImage = symbol.withSymbolConfiguration(config) ?? symbol

    // Tint the template glyph white: draw it, then fill white over the drawn (non-transparent)
    // pixels using sourceAtop compositing.
    let tinted = NSImage(size: symbolImage.size)
    tinted.lockFocus()
    symbolImage.draw(in: NSRect(origin: .zero, size: symbolImage.size))
    NSColor.white.set()
    NSRect(origin: .zero, size: symbolImage.size).fill(using: .sourceAtop)
    tinted.unlockFocus()

    let symbolRect = NSRect(
        x: (size - symbolImage.size.width) / 2,
        y: (size - symbolImage.size.height) / 2,
        width: symbolImage.size.width,
        height: symbolImage.size.height
    )
    tinted.draw(in: symbolRect)
}

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("error: failed to render icon\n".data(using: .utf8)!)
    exit(1)
}

try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
