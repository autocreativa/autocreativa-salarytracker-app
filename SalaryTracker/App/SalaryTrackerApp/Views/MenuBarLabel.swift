import SwiftUI
import AppKit
import SalaryTrackerCore

/// Indicador compacto de la barra de menú (specs/menubar-experience
/// "Indicador de Menu Bar").
///
/// Identidad visual tomada de la landing: pastilla oscura (`lcdBg`) con borde
/// `lcdBorder`, punto verde con halo y el valor en **dígitos de 7 segmentos**
/// verdes (`lcdDigit`) con brillo, sin símbolo de moneda.
///
/// > Restricción de `MenuBarExtra` (descubierta el 2026-10-03): el status item
/// > solo conserva el `Image` del label; cualquier shape custom (el `DigiSeven`
/// > en vivo) se descarta. Por eso el contenido se **pre-renderiza** a un
/// > `NSImage` non-template con `ImageRenderer` y se expone como
/// > `Image(nsImage:)`: así el chip conserva su color en Light y Dark Mode.
struct MenuBarLabel: View {
    let state: TrackerState

    var body: some View {
        switch state {
        case .notConfigured:
            // Glifo estático (los system image sí los renderiza MenuBarExtra).
            Image(systemName: "dollarsign")
                .imageScale(.medium)
                .accessibilityLabel("Salary Tracker: no configurado")
        case .invalid:
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.medium)
                .accessibilityLabel("Salary Tracker: configuración inválida")
        case .active(let view):
            chip(earned: view.earned, code: view.currencyCode)
        case .futureStart(startsAt: _, firstPayment: _, salary: _, currencyCode: let code):
            chip(earned: 0, code: code)
        case .openEnded(let view):
            chip(earned: view.salary, code: view.currencyCode)
        }
    }

    // MARK: - Chip LCD

    /// Pastilla de la barra: punto + dígitos de 7 segmentos sobre fondo LCD.
    @ViewBuilder
    private func chip(earned: Decimal, code: String) -> some View {
        let compact = CurrencyFormatter.formatCompact(earned, code: code)
        if let image = renderChip(compact, code: code) {
            Image(nsImage: image)
                .accessibilityLabel(
                    "Dinero ganado: \(CurrencyFormatter.format(earned, code: code))")
        } else {
            // Fallback (si el render fallara): chips SF Symbol + texto.
            HStack(spacing: 3) {
                Text(CurrencyCatalog.symbol(forCode: code)).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.lcdDigit)
                Text(compact).font(Theme.mono(10, .bold))
            }
            .foregroundStyle(Theme.lcdDigit)
            .accessibilityLabel(
                "Dinero ganado: \(CurrencyFormatter.format(earned, code: code))")
        }
    }

    /// Pre-renderiza el chip a `NSImage` non-template (coloreado) para que
    /// `MenuBarExtra` lo muestre íntegro.
    private func renderChip(_ compact: String, code: String) -> NSImage? {
        let symbol = CurrencyCatalog.symbol(forCode: code)
        let content = HStack(spacing: 5) {
            Text(symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.lcdDigit)
            DigiSeven(text: compact,
                      color: Theme.lcdDigit,
                      dimColor: Theme.lcdDim,
                      digitWidth: 8.5)
                .shadow(color: Theme.lcdDigit.opacity(0.5), radius: 2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Theme.lcdBorderSoft, lineWidth: 0.8)
        )

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }
}