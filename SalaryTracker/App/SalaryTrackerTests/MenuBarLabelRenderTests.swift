import Foundation
import XCTest
import SwiftUI
import AppKit
import SalaryTrackerCore

/// Smoke test de rendering del indicador de barra (debug 2026-10-03: los dígitos
/// de 7 segmentos no aparecían en la barra real). Rasteriza `MenuBarLabel` y
/// `DigiSeven` con `ImageRenderer` para confirmar que efectivamente pintan
/// píxeles opacos (no solo el glifo) y para inspección visual del PNG.
@MainActor
final class MenuBarLabelRenderTests: XCTestCase {

    /// Config de referencia (mismo patrón que el usuario): 1 800 000 CLP,
    /// inicio 2026-08-10 09:00, último viernes.
    private func config() -> SalaryConfig {
        SalaryConfig(
            salaryAmount: 1_800_000,
            currencyCode: "CLP",
            contractStart: LocalDate(year: 2026, month: 8, day: 10),
            contractStartTime: LocalTime(hour: 9, minute: 0),
            paymentRule: .lastWeekdayOfMonth(weekday: 5)
        )
    }

    private func fixedDate() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 10; c.day = 3
        c.hour = 12; c.minute = 0; c.second = 0
        return Calendar.gregorian(timeZone: .current).date(from: c)!
    }

    /// Cuenta píxeles con alpha > 16 en el bitmap de una `NSImage`.
    private func opaquePixelCount(_ image: NSImage) -> Int {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return 0 }
        let w = rep.pixelsWide, h = rep.pixelsHigh
        var count = 0
        // Muestreo en celdas de 2 px para velocidad.
        for y in stride(from: 0, to: h, by: 2) {
            for x in stride(from: 0, to: w, by: 2) {
                if let cg = rep.colorAt(x: x, y: y), cg.alphaComponent > 0.063 {
                    count += 1
                }
            }
        }
        return count
    }

    private func writePNG(_ image: NSImage, to url: URL) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }

    @discardableResult
    private func render<V: View>(_ view: V, scale: CGFloat = 3) -> NSImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.nsImage
    }

    func testDigiSevenRendersOpaqueDigits() {
        let v = DigiSeven(text: "417.384", color: .green, digitWidth: 8)
            .padding(6)
        guard let image = render(v) else {
            XCTFail("ImageRenderer no produjo imagen de DigiSeven"); return
        }
        let out = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("digiseven_417384.png")
        writePNG(image, to: out)
        let opaque = opaquePixelCount(image)
        // 7 dígitos + punto: si solo apareciera el punto o nada, el conteo sería
        // muy bajo. Con dígitos completos el área opaca debe superar el umbral.
        XCTAssertGreaterThan(opaque, 400, "DigiSeven pintó muy pocos píxeles opacos: \(opaque) (archivo \(out.path))")
    }

    func testMenuBarLabelRendersIconAndDigits() {
        let state = TrackerEngine().state(config: config(), now: fixedDate())
        guard case .active = state else {
            XCTFail("Se esperaba estado activo, era: \(state)"); return
        }
        let v = MenuBarLabel(state: state).padding(4)
        guard let image = render(v) else {
            XCTFail("ImageRenderer no produjo imagen de MenuBarLabel"); return
        }
        let out = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("menubar_label.png")
        writePNG(image, to: out)
        let opaque = opaquePixelCount(image)
        // El label debe incluir glifo + dígitos: área opaca considerablemente
        // mayor que la de un glifo solo (~pequeño). Umbral generoso.
        XCTAssertGreaterThan(opaque, 300, "MenuBarLabel pintó muy pocos píxeles opacos: \(opaque) (archivo \(out.path))")
    }

    /// El chip de la barra debe caber en la altura de la status item (~22 pt) y
    /// ser claramente más ancho que el glifo solo.
    func testMenuBarChipFitsStatusItemHeight() {
        let state = TrackerEngine().state(config: config(), now: fixedDate())
        guard case .active = state else {
            XCTFail("Se esperaba estado activo, era: \(state)"); return
        }
        guard let image = render(MenuBarLabel(state: state), scale: 4) else {
            XCTFail("ImageRenderer no produjo imagen del chip"); return
        }
        XCTAssertLessThanOrEqual(image.size.height, 20,
            "El chip mide \(image.size.height) pt y no cabe en la status item")
        XCTAssertGreaterThan(image.size.width, 40,
            "El chip debería incluir los dígitos (ancho \(image.size.width) pt)")
    }

    // MARK: - Geometría de los dígitos

    /// Regresión del bug de diseño (2026-10-03): con `VStack`/`HStack` el
    /// segmento central `g` quedaba centrado en su fila (y `d` también), así que
    /// los dígitos se veían deformados. Este test sondea el centro de los 7
    /// segmentos de cada dígito y compara con el mapa canónico.
    func testDigiSevenLightsExpectedSegmentsPerDigit() {
        let w: CGFloat = 30, h = w * 2
        let t = max(1, w * 0.18), g = max(0.6, w * 0.07)
        let lenV = (h - t - 2 * g) / 2
        let upperY = t + g + lenV / 2
        let lowerY = h - t - g - lenV / 2
        let probes: [(name: String, cx: CGFloat, cy: CGFloat)] = [
            ("a", w / 2, t / 2),
            ("f", t / 2, upperY),
            ("g", w / 2, h / 2),
            ("b", w - t / 2, upperY),
            ("e", t / 2, lowerY),
            ("d", w / 2, h - t / 2),
            ("c", w - t / 2, lowerY),
        ]
        let expected: [Character: Set<String>] = [
            "0": ["a", "b", "c", "d", "e", "f"],
            "1": ["b", "c"],
            "2": ["a", "b", "g", "e", "d"],
            "3": ["a", "b", "g", "c", "d"],
            "4": ["f", "g", "b", "c"],
            "5": ["a", "f", "g", "c", "d"],
            "6": ["a", "f", "g", "e", "c", "d"],
            "7": ["a", "b", "c"],
            "8": ["a", "b", "c", "d", "e", "f", "g"],
            "9": ["a", "b", "c", "d", "f", "g"],
        ]

        let scale: CGFloat = 6
        for ch in "0123456789" {
            let view = DigiSeven(text: String(ch), color: .white,
                                 dimColor: .black, digitWidth: w)
                .padding(6)
                .background(Color.white)
            guard let image = render(view, scale: scale),
                  let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff) else {
                XCTFail("No se pudo rasterizar el dígito \(ch)"); continue
            }
            var lit = Set<String>()
            for p in probes {
                let px = Int((p.cx + 6) * scale)
                let py = Int((p.cy + 6) * scale)   // origen arriba-izquierda
                var isLit = false
                for dy in -2...2 {
                    for dx in -2...2 {
                        if let c = rep.colorAt(x: px + dx, y: py + dy) {
                            let lum = 0.2126 * c.redComponent + 0.7152 * c.greenComponent
                                + 0.0722 * c.blueComponent
                            if lum > 0.6 { isLit = true }
                        }
                    }
                }
                if isLit { lit.insert(p.name) }
            }
            XCTAssertEqual(lit, expected[ch],
                "Dígito \(ch): segmentos encendidos \(lit.sorted()) ≠ \(expected[ch]!.sorted())")
        }
    }
}
