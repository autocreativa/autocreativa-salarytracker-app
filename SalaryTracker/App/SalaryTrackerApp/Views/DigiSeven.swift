import SwiftUI
import SalaryTrackerCore

/// Dígitos de 7 segmentos al estilo de los relojes digitales antiguos.
/// Usado en el indicador de la barra de menú (specs/menubar-experience
/// "Indicador de Menu Bar", cambio de diseño 2026-10-03).
///
/// - Cada dígito se dibuja con 7 segmentos (a–g) + punto decimal.
/// - Los segmentos "apagados" se muestran tenue (como en un display real).
/// - Al encender/apagar un segmento hay una microanimación de brillo/escala.
struct DigiSeven: View {
    let text: String
    var color: Color = .green
    /// Ancho de cada dígito en puntos; la altura se deriva (≈ 2.3×).
    var digitWidth: CGFloat = 7

    /// Mapa 7 segmentos estándar: a = superior, b = superior-der,
    /// c = inferior-der, d = inferior, e = inferior-izq, f = superior-izq,
    /// g = central.
    private static let segments: [Character: Set<Character>] = [
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

    private var thickness: CGFloat { digitWidth * 0.24 }
    private var segLengthH: CGFloat { digitWidth - thickness }
    private var segLengthV: CGFloat { (digitWidth * 2.3 - 3 * thickness) / 2 }

    var body: some View {
        HStack(spacing: digitWidth * 0.3) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                if ch == "." {
                    decimalPoint
                } else if let on = Self.segments[ch] {
                    digit(on)
                } else {
                    // Glifo no representable: espacio de dígito (no rompen layout).
                    Color.clear
                        .frame(width: digitWidth, height: digitWidth * 2.3)
                }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Dígito

    private func digit(_ on: Set<Character>) -> some View {
        VStack(spacing: thickness) {
            seg("a", isOn: on.contains("a"), horizontal: true)
            HStack(spacing: 0) {
                seg("f", isOn: on.contains("f"), horizontal: false)
                seg("g", isOn: on.contains("g"), horizontal: true)
                seg("b", isOn: on.contains("b"), horizontal: false)
            }
            HStack(spacing: 0) {
                seg("e", isOn: on.contains("e"), horizontal: false)
                seg("d", isOn: on.contains("d"), horizontal: true)
                seg("c", isOn: on.contains("c"), horizontal: false)
            }
        }
        .frame(width: digitWidth, height: digitWidth * 2.3)
    }

    private func seg(_ id: Character, isOn: Bool, horizontal: Bool) -> some View {
        // Geometría por segmento (los bordes exteriores se recortan levemente
        // para dar la forma de "L" invertida clásica de los displays).
        let size = horizontal
            ? CGSize(width: segLengthH, height: thickness)
            : CGSize(width: thickness, height: segLengthV)
        return RoundedRectangle(cornerRadius: thickness * 0.5, style: .continuous)
            .fill(isOn
                  ? AnyShapeStyle(color)
                  : AnyShapeStyle(color.opacity(0.10)))
            .frame(width: size.width, height: size.height)
            .brightness(isOn ? 0.08 : 0)
            .scaleEffect(isOn ? 1.0 : 0.98)
            .animation(.easeInOut(duration: 0.12), value: isOn)
    }

    private var decimalPoint: some View {
        let t = digitWidth * 0.2
        return RoundedRectangle(cornerRadius: t * 0.5, style: .continuous)
            .fill(color)
            .frame(width: t, height: t)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, thickness * 0.4)
    }
}
