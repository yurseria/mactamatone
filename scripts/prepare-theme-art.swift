#!/usr/bin/env swift
import AppKit

// Identify the five instruments by connected alpha, then register their full
// bounds on square canvases. Generated strips need not use exact cell spacing.
// Adjacent antialiased edges are retained; disconnected speckles are excluded.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let canvas = 1024
let targetHeight = 948.0
let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
for theme in ["Pink", "Cat", "Chick", "Galaxy", "Shiba"] {
    let url = root.appendingPathComponent("design/Themes/\(theme).png")
    guard let source = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("Missing theme strip: \(url.path)")
    }
    let width = source.width, height = source.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)!
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    var labels = [Int](repeating: 0, count: width * height)
    var regions: [(id: Int, size: Int, minX: Int, minY: Int, maxX: Int, maxY: Int)] = []
    for start in labels.indices where labels[start] == 0 && pixels[start * 4 + 3] >= 128 {
        let id = regions.count + 1
        var queue = [start]
        labels[start] = id
        var cursor = 0
        var minX = width, minY = height, maxX = 0, maxY = 0
        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1
            let x = index % width, y = index / width
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
            for (nx, ny) in [(x-1,y), (x+1,y), (x,y-1), (x,y+1)] {
                guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                let neighbor = ny * width + nx
                if labels[neighbor] == 0 && pixels[neighbor * 4 + 3] >= 128 {
                    labels[neighbor] = id
                    queue.append(neighbor)
                }
            }
        }
        regions.append((id, queue.count, minX, minY, maxX, maxY))
    }
    let instruments = regions.sorted { $0.size > $1.size }.prefix(5).sorted { $0.minX < $1.minX }
    precondition(instruments.count == 5)
    for (level, region) in instruments.enumerated() {
        precondition(region.size > width * height / 40, "No complete instrument in \(theme) frame \(level)")
        let left = max(0, region.minX-1), top = max(0, region.minY-1)
        let right = min(width-1, region.maxX+1), bottom = min(height-1, region.maxY+1)
        let artWidth = right-left+1, artHeight = bottom-top+1
        var cutout = [UInt8](repeating: 0, count: artWidth * artHeight * 4)
        for y in top...bottom {
            for x in left...right {
                let index = y * width + x
                var keep = labels[index] == region.id
                if !keep && pixels[index * 4 + 3] > 0 {
                    for ny in max(0, y-1)...min(height-1, y+1) {
                        for nx in max(0, x-1)...min(width-1, x+1) where labels[ny * width + nx] == region.id {
                            keep = true
                        }
                    }
                }
                if keep {
                    let destination = ((y-top) * artWidth + x-left) * 4
                    for channel in 0..<4 { cutout[destination+channel] = pixels[index*4+channel] }
                }
            }
        }
        let art = cutout.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: artWidth, height: artHeight, bitsPerComponent: 8,
                      bytesPerRow: artWidth * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)!.makeImage()!
        }
        let scaledWidth = Double(artWidth) * targetHeight / Double(artHeight)
        let output = CGContext(data: nil, width: canvas, height: canvas, bitsPerComponent: 8,
                               bytesPerRow: canvas * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)!
        output.interpolationQuality = .high
        output.draw(art, in: CGRect(x: (Double(canvas)-scaledWidth)/2, y: 38, width: scaledWidth, height: targetHeight))
        let bitmap = NSBitmapImageRep(cgImage: output.makeImage()!)
        let destination = root.appendingPathComponent("Sources/Mactamatone/Resources/Otamatone\(theme)Level\(level).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination)
        print(destination.lastPathComponent)
    }
}
