// Genera el icono de la app (dollar-sign sobre gradiente) como .iconset
// y luego `iconutil -c icns` lo convierte a AppIcon.icns.
import AppKit
import Foundation

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func drawIcon(px: Int) -> NSImage {
    let px = CGFloat(px)
    let image = NSImage(size: NSSize(width: px, height: px))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let rect = CGRect(x: 0, y: 0, width: px, height: px)

    // Fondo: rect redondeado con gradiente (esmeralda → azul).
    let radius = px * 0.225
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let colors = [
        CGColor(red: 0.13, green: 0.65, blue: 0.50, alpha: 1.0),
        CGColor(red: 0.08, green: 0.40, blue: 0.80, alpha: 1.0),
    ] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: px), end: CGPoint(x: px, y: 0), options: [])
    ctx.restoreGState()

    // Glifo "$" centrado.
    let fontSize = px * 0.52
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
        .foregroundColor: NSColor.white,
        .paragraphStyle: para,
    ]
    let s = NSAttributedString(string: "$", attributes: attrs)
    let size = s.size()
    let pt = CGPoint(x: (px - size.width) / 2, y: (px - size.height) / 2 - px * 0.02)
    s.draw(at: pt)

    image.unlockFocus()
    return image
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for s in sizes {
    let img = drawIcon(px: s.px)
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("fallo renderizando \(s.name)\n".data(using: .utf8)!)
        exit(1)
    }
    try png.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(s.name))
    print("ok \(s.name) (\(s.px)px)")
}
print("iconset completo en: \(outDir)")
