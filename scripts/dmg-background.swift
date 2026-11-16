import AppKit

// Draws the background of the installer window: "Drag ElmScanner to Applications" and an arrow.
// Run: swift scripts/dmg-background.swift scripts/dmg-background.png   (1200 x 800 px, 144 dpi = 600 x 400 pt)
let size = NSSize(width: 1200, height: 800)
let image = NSImage(size: size)
image.lockFocus()
NSGradient(colors: [NSColor(white: 0.97, alpha: 1), NSColor(white: 0.90, alpha: 1)])!.draw(in: NSRect(origin: .zero, size: size), angle: 270)
let title = "Drag ElmScanner to Applications" as NSString
let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 40, weight: .semibold), .foregroundColor: NSColor(white: 0.25, alpha: 1)]
let textSize = title.size(withAttributes: attributes)
title.draw(at: NSPoint(x: (size.width - textSize.width) / 2, y: 640), withAttributes: attributes)
// An arrow between the two icons (app at x=300, Applications at x=900, both at y=400 in this image).
let arrow = NSBezierPath()
arrow.lineWidth = 14
arrow.lineCapStyle = .round
arrow.move(to: NSPoint(x: 470, y: 400))
arrow.line(to: NSPoint(x: 700, y: 400))
NSColor(white: 0.55, alpha: 1).setStroke()
arrow.stroke()
let head = NSBezierPath()
head.lineWidth = 14
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.move(to: NSPoint(x: 660, y: 445))
head.line(to: NSPoint(x: 710, y: 400))
head.line(to: NSPoint(x: 660, y: 355))
head.stroke()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
