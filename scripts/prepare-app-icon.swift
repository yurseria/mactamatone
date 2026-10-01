import AppKit

// Normalize artwork to a rounded macOS icon tile. Inset full-bleed sources;
// generated sources already contain the tile and only need their outer mask.
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let layout = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "inset"
precondition(["inset", "generated"].contains(layout), "Expected inset or generated layout")
guard let image = NSImage(contentsOf: source),
      let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Cannot load or render app icon")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
let tile = layout == "inset"
    ? NSRect(x: 64, y: 64, width: 896, height: 896)
    : NSRect(x: 54, y: 82, width: 895, height: 879)
let cornerRadius: CGFloat = layout == "inset" ? 200 : 224
NSBezierPath(roundedRect: tile, xRadius: cornerRadius, yRadius: cornerRadius).addClip()
image.draw(in: layout == "inset" ? tile : NSRect(x: 0, y: 0, width: 1024, height: 1024))
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
