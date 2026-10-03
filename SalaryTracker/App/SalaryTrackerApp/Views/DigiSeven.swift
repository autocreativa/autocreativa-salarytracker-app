import SwiftUI
import SalaryTrackerCore

/// Dígitos de 7 segmentos al estilo de los relojes digitales antiguos
/// (specs/menubar-experience "Indicador de Menu Bar").
///
/// Proporciones (rediseño 2026-10-03 según el mockup LCD de la landing):
/// - altura ≈ 2× el ancho del dígito (proporción de un 7 segmentos real);
/// - trazo fino (18 % del ancho) con **hueco** entre segmentos (aspecto
///   "mitred", no bloques pegados);
/// - separación ancha entre dígitos;
/// - los segmentos apagados usan un color propio (`dimColor`, por defecto el
///   mismo color al 12 %), como los dígitos fantasma `8.888.888` de la landing.
struct DigiSeven: View {
    let text: String
    var color: Color = .green
    /// Color de los segmentos apagados (por defecto, el color encendido tenue).
    var dimColor: Color?
    /// Ancho de cada dígito en puntos; la altura se deriva (≈ 2×).
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

    /// Altura total de un dígito.
    private var digitHeight: CGFloat { digitWidth * 2 }
    /// Grosor del trazo (segmentos de los displays reales).
    private var thickness: CGFloat { max(1, digitWidth * 0.24) }
    /// Hueco entre segmentos: da el aspecto mitrado en vez de bloque macizo.
    private var gap: CGFloat { max(0.6, digitWidth * 0.09) }
    /// Separación entre dígitos.
    private var digitSpacing: CGFloat { digitWidth * 0.42 }
    /// Largo de los segmentos horizontales (a, g, d): el ancho del dígito menos
    /// los dos segmentos verticales y los huecos intermedios.
    private var segLengthH: CGFloat { digitWidth - 0.8 * thickness - 1.5 * gap }
    /// Largo de los segmentos verticales (b, c, e, f): la mitad de la altura útil.
    private var segLengthV: CGFloat { (digitHeight - thickness - 2 * gap) / 2 }

    private var offColor: Color { dimColor ?? color.opacity(0.12) }

    var body: some View {
        HStack(spacing: digitSpacing) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                if ch == "." {
                    decimalPoint
                } else if let on = Self.segments[ch] {
                    digit(on)
                } else {
                    // Glifo no representable (p. ej. "$"): hueco que conserva el
                    // ancho de un dígito, sin romper el layout del display.
                    Color.clear
                        .frame(width: digitWidth, height: digitHeight)
                }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Dígito

    /// Geometría canónica de un 7 segmentos: horizontales (a, g, d) de ancho
    /// `digitWidth - 2·trazo - 2·hueco`, verticales (f, b, e, c) de largo
    /// `(alto - 3·trazo - 4·hueco)/2`. El segmento central `g` cae en el medio
    /// exacto del dígito y el inferior `d` pegado al borde (posición absoluta:
    /// con `VStack`/`HStack` el `g` quedaba descentrado en el centro de su fila,
    /// y los dígitos se veían deformados).
    private func digit(_ on: Set<Character>) -> some View {
        let w = digitWidth, h = digitHeight, t = thickness, g = gap
        let lenH = segLengthH
        let lenV = segLengthV
        let upperCenterY = t + g + lenV / 2
        let lowerCenterY = h - t - g - lenV / 2

        return ZStack(alignment: .topLeading) {
            segH(on.contains("a"), cx: w / 2, cy: t / 2, length: lenH)
            segV(on.contains("f"), cx: t / 2, cy: upperCenterY, length: lenV)
            segH(on.contains("g"), cx: w / 2, cy: h / 2, length: lenH)
            segV(on.contains("b"), cx: w - t / 2, cy: upperCenterY, length: lenV)
            segV(on.contains("e"), cx: t / 2, cy: lowerCenterY, length: lenV)
            segH(on.contains("d"), cx: w / 2, cy: h - t / 2, length: lenH)
            segV(on.contains("c"), cx: w - t / 2, cy: lowerCenterY, length: lenV)
        }
        .frame(width: w, height: h)
    }

    /// Segmento horizontal centrado en (cx, cy).
    private func segH(_ isOn: Bool, cx: CGFloat, cy: CGFloat, length: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: thickness * 0.34, style: .continuous)
            .fill(isOn ? color : offColor)
            .frame(width: length, height: thickness)
            .position(x: cx, y: cy)
    }

    /// Segmento vertical centrado en (cx, cy).
    private func segV(_ isOn: Bool, cx: CGFloat, cy: CGFloat, length: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: thickness * 0.34, style: .continuous)
            .fill(isOn ? color : offColor)
            .frame(width: thickness, height: length)
            .position(x: cx, y: cy)
    }

    private var decimalPoint: some View {
        Circle()
            .fill(color)
            .frame(width: thickness, height: thickness)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, gap)
    }
}