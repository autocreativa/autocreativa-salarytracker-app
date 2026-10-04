// Genera el icono de la app para SalaryTracker v1.0.0.
//
// Concepto "LCD $": un signo de dólar dibujado con la geometría canónica de
// 7 segmentos de la app (misma proporción que `DigiSeven`: alto ≈ 1.9× ancho,
// trazo 19 %, hueco 8.5 %) con glow mint sobre fondo verde bosque — la misma
// identidad "botanical/LCD" de `Theme.swift` (lcdBg/lcdDigit/lcdDim).
//
// Uso: `swift make_icon.swift <dir-destino>` genera un `.iconset`; después
// `iconutil -c icns <dir> -o AppIcon.icns`.
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

// MARK: - Paleta LCD (Theme.swift)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: a)
}

let bgTop = rgb(0x24462F)      // verde bosque, arriba (más claro)
let bgBottom = rgb(0x0B1811)   // casi negro botánico, abajo
let innerBorder = rgb(0x2E5A3D)
let digitOn = rgb(0x8CF59B)    // lcdDigit (mint)
let digitOff = rgb(0x20432E, 0.55)  // lcdDim atenuado (dígito fantasma)

// MARK: - Dibujo

/// Segmento redondeado centrado en (cx, cy) en coordenadas con origen
/// superior-izquierdo; devuelve la CGPath en coordenadas de CGContext
/// (origen inferior-izquierdo) dentro de un lienzo de `px`.
func segmentPath(cx: CGFloat, cy: CGFloat, length: CGFloat, thickness: CGFloat,
                 vertical: Bool, px: CGFloat) -> CGPath {
    let radius = thickness * 0.34
    let w: CGFloat, h: CGFloat
    if vertical { w = thickness; h = length } else { w = length; h = thickness }
    let x = cx - w / 2
    let y = px - (cy + h / 2)   // flip Y (origen superior-izquierdo → CG)
    return CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h),
                  cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIcon(px: Int) -> NSImage {
    let px = CGFloat(px)
    let image = NSImage(size: NSSize(width: px, height: px))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        fatalError("sin contexto gráfico")
    }
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // 1) Fondo: squircle full-bleed con gradiente vertical botánico.
    let radius = px * 0.2237
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: px, height: px),
                        cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [bgTop, bgBottom] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: 0, y: px),   // arriba
                           end: CGPoint(x: 0, y: 0),      // abajo
                           options: [])
    // Brillo suave superior (profundidad).
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [rgb(0xFFFFFF, 0.10), rgb(0xFFFFFF, 0)] as CFArray,
                          locations: [0, 1])!
    ctx.saveGState()
    ctx.translateBy(x: px / 2, y: px * 0.98)
    ctx.scaleBy(x: 1, y: 0.62)
    ctx.drawRadialGradient(glow,
                           startCenter: .zero, startRadius: 0,
                           endCenter: .zero, endRadius: px * 0.75,
                           options: [])
    ctx.restoreGState()
    ctx.restoreGState()

    // 2) Borde interior sutil (lcdBorder).
    let inset = px * 0.015
    let borderPath = CGPath(roundedRect: CGRect(x: inset, y: inset,
                                                width: px - 2 * inset,
                                                height: px - 2 * inset),
                            cornerWidth: radius - inset, cornerHeight: radius - inset,
                            transform: nil)
    ctx.addPath(borderPath)
    ctx.setStrokeColor(innerBorder)
    ctx.setLineWidth(max(1, px * 0.008))
    ctx.strokePath()

    // 3) Dígito "$" de 7 segmentos (geometría canónica de DigiSeven).
    let h = px * 0.60                    // alto del dígito
    let w = h / 1.9                      // ancho (proporción 7 seg real)
    let t = w * 0.19                     // trazo
    let g = w * 0.085                    // hueco
    let lenH = w - 2 * t - 2 * g
    let lenV = (h - 3 * t - 4 * g) / 2
    let x0 = (px - w) / 2                // origen superior-izq del dígito
    let y0 = (px - h) / 2
    let upperCy = y0 + t + g + lenV / 2
    let lowerCy = y0 + h - t - g - lenV / 2

    // Segmentos encendidos del "$": forma "S" (a, f, g, c, d) + barra central.
    let onSegments: [(cx: CGFloat, cy: CGFloat, len: CGFloat, vert: Bool)] = [
        (x0 + w / 2, y0 + t / 2, lenH, false),          // a
        (x0 + t / 2, upperCy, lenV, true),              // f
        (x0 + w / 2, y0 + h / 2, lenH, false),          // g
        (x0 + w - t / 2, lowerCy, lenV, true),          // c
        (x0 + w / 2, y0 + h - t / 2, lenH, false),      // d
    ]
    // Segmentos apagados (fantasma "8"): los cuatro restantes.
    let offSegments: [(cx: CGFloat, cy: CGFloat, len: CGFloat, vert: Bool)] = [
        (x0 + w - t / 2, upperCy, lenV, true),          // b
        (x0 + t / 2, lowerCy, lenV, true),              // e
    ]

    var litPaths: [CGPath] = onSegments.map {
        segmentPath(cx: $0.cx, cy: $0.cy, length: $0.len, thickness: t,
                    vertical: $0.vert, px: px)
    }
    let offPaths: [CGPath] = offSegments.map {
        segmentPath(cx: $0.cx, cy: $0.cy, length: $0.len, thickness: t,
                    vertical: $0.vert, px: px)
    }
    // Barra vertical del "$": cruza el dígito y asoma arriba y abajo.
    let barLen = h * 1.24
    let bar = segmentPath(cx: x0 + w / 2, cy: y0 + h / 2, length: barLen,
                          thickness: t, vertical: true, px: px)
    litPaths.append(bar)

    // 4) Dibujar: primero el fantasma (dim), luego el "$" con glow.
    ctx.saveGState()
    ctx.setFillColor(digitOff)
    for p in offPaths { ctx.addPath(p); ctx.fillPath() }
    ctx.restoreGState()

    ctx.saveGState()
    // Glow: dos pasadas con sombra (halo) + pasada nítida.
    for pass in 0..<2 {
        ctx.setShadow(offset: .zero,
                      blur: px * (pass == 0 ? 0.030 : 0.012),
                      color: rgb(0x8CF59B, pass == 0 ? 0.55 : 0.85))
        ctx.setFillColor(digitOn)
        for p in litPaths { ctx.addPath(p); ctx.fillPath() }
    }
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.setFillColor(digitOn)
    for p in litPaths { ctx.addPath(p); ctx.fillPath() }
    ctx.restoreGState()

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
