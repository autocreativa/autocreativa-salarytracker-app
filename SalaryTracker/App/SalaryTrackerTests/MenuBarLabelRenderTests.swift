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
}
