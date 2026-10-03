import SwiftUI
import AppKit
import SalaryTrackerCore

/// Verde "dinero" adaptativo: en barra oscura un verde legible, en barra clara
/// un verde oscuro (money green).
private let moneyGreenNS = NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        ? NSColor(calibratedRed: 0.22, green: 0.83, blue: 0.40, alpha: 1) // ≈ #38D466
        : NSColor(calibratedRed: 0.05, green: 0.45, blue: 0.21, alpha: 1) // ≈ #0D7336
}
private let moneyGreen = Color(nsColor: moneyGreenNS)

/// Indicador compacto de la barra de menú (specs/menubar-experience
/// "Indicador de Menu Bar").
///
/// Restricción descubierta el 2026-10-03: `MenuBarExtra` SOLO renderiza en el
/// status item el `Image` del label (el contenido custom —shapes— se descarta).
/// Por eso el número de 7 segmentos se PRE-RENDERIZA a un `NSImage` y se pasa
/// como `Image(nsImage:)`: el glifo + los dígitos viajan en una sola imagen
/// coloreada (verde dinero), sin símbolo en el texto.
struct MenuBarLabel: View {
    let state: TrackerState

    var body: some View {
        switch state {
        case .notConfigured:
            // Glifo estático (system image sí la renderiza MenuBarExtra).
            Image(systemName: "dollarsign")
                .imageScale(.medium)
                .accessibilityLabel("Salary Tracker: no configurado")
        case .invalid:
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.medium)
                .accessibilityLabel("Salary Tracker: configuración inválida")
        case .active(let view):
            labelImage(earned: view.earned, code: view.currencyCode,
                       full: CurrencyFormatter.format(view.earned, code: view.currencyCode))
        case .futureStart(startsAt: _, firstPayment: _, salary: _, currencyCode: let code):
            labelImage(earned: 0, code: code,
                       full: CurrencyFormatter.format(Decimal(0), code: code))
        case .openEnded(let view):
            labelImage(earned: view.salary, code: view.currencyCode,
                       full: CurrencyFormatter.format(view.salary, code: view.currencyCode))
        }
    }

    /// Renderiza glifo + dígitos de 7 segmentos a un NSImage (non-template,
    /// para conservar el verde dinero) y lo expone como `Image(nsImage:)`.
    @ViewBuilder
    private func labelImage(earned: Decimal, code: String, full: String) -> some View {
        let image = renderLabel(earned: earned, code: code)
        if let image {
            Image(nsImage: image)
                .accessibilityLabel("Dinero ganado: \(full)")
        } else {
            // Fallback: texto plano (sin 7 segmentos) si el render fallara.
            let compact = CurrencyFormatter.formatCompact(earned, code: code)
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle")
                    .imageScale(.small)
                Text(compact)
            }
            .accessibilityLabel("Dinero ganado: \(full)")
        }
    }

    /// Pre-renderiza el contenido del indicador (glifo + DigiSeven) a un
    /// `NSImage` non-template para que `MenuBarExtra` lo muestre íntegro.
    private func renderLabel(earned: Decimal, code: String) -> NSImage? {
        let compact = CurrencyFormatter.formatCompact(earned, code: code)
        let content = HStack(spacing: 4) {
            Image(systemName: "dollarsign.circle")
                .imageScale(.small)
                .foregroundStyle(moneyGreen)
            DigiSeven(text: compact, color: moneyGreen, digitWidth: 6.5)
        }
        .padding(.vertical, 1)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }
}
