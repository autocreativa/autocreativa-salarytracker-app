import SwiftUI
import AppKit
import SalaryTrackerCore

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Color
// ═══════════════════════════════════════════════════════════════════════════

extension Color {
    /// Color sRGB desde un literal `0xRRGGBB`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Color dinámico: un valor para Light Mode y otro para Dark Mode
    /// (scenario "Adaptación a modo oscuro y claro").
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(srgbRed: Double((dark >> 16) & 0xFF) / 255,
                          green: Double((dark >> 8) & 0xFF) / 255,
                          blue: Double(dark & 0xFF) / 255, alpha: 1)
                : NSColor(srgbRed: Double((light >> 16) & 0xFF) / 255,
                          green: Double((light >> 8) & 0xFF) / 255,
                          blue: Double(light & 0xFF) / 255, alpha: 1)
        })
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Theme
// ═══════════════════════════════════════════════════════════════════════════

/// Sistema de diseño de SalaryTracker: replica la identidad visual de la landing
/// (`autocreativa-salarytracker-app-landing`, Tailwind `botanical` + LCD).
///
/// - Superficies: `cream` / `surface` / `card`, bordes `sageBorder`.
/// - Texto: `ink` / `inkSoft` / `inkFaint`.
/// - Marca: `forest` / `sage` / `mint`.
/// - LCD: panel **siempre oscuro** (`lcdBg`→`lcdBg2`) con dígitos `lcdDigit`,
///   segmentos apagados `lcdDim` y brillo verde (glow), tal como el mockup de la
///   landing.
///
/// Dark Mode: cada token de superficie/texto tiene su variante oscura
/// manteniendo el mismo tono (verde bosque de fondo, verde menta como acento).
enum Theme {

    // MARK: Superficies

    /// Fondo base de la app (popover y ventana de configuración).
    static let base = Color(light: 0xFAF8F5, dark: 0x12241A)
    /// Tarjetas blancas / elevado.
    static let card = Color(light: 0xFFFFFF, dark: 0x1C3323)
    /// Superficie secundaria (filas, campos, chips).
    static let surface = Color(light: 0xF5F3ED, dark: 0x1F3B2A)
    /// Bordes visibles.
    static let border = Color(light: 0xCAD5C6, dark: 0x2C5237)
    /// Bordes suaves (separadores internos).
    static let borderSoft = Color(light: 0xE7ECE4, dark: 0x24422E)

    // MARK: Texto

    static let ink = Color(light: 0x2D3A30, dark: 0xF1F5EF)
    static let inkSoft = Color(light: 0x5F7A65, dark: 0xA6BCAA)
    static let inkFaint = Color(light: 0x8FA590, dark: 0x7E9585)

    // MARK: Marca

    /// Verde bosque: acción primaria, progreso, acentos.
    static let forest = Color(light: 0x24422E, dark: 0x86EFAC)
    static let sage = Color(light: 0x5F7A65, dark: 0x5F7A65)
    static let mint = Color(light: 0x2C5237, dark: 0x86EFAC)

    // MARK: LCD (siempre oscuro, igual que en la landing)

    static let lcdBg = Color(hex: 0x15291C)
    static let lcdBgDeep = Color(hex: 0x0F2016)
    static let lcdBorder = Color(hex: 0x284C34)
    static let lcdBorderSoft = Color(hex: 0x3E6B4C)
    static let lcdDigit = Color(hex: 0x8CF59B)
    static let lcdDim = Color(hex: 0x20432E)
    static let lcdLabel = Color(hex: 0x8FA590)

    // MARK: Tipografías
    //
    // La landing usa Epilogue (display), Manrope (texto) y Share Tech Mono
    // (datos/LCD). Aquí se usan las del sistema equivalentes, para no añadir
    // ~1 MB de fuentes al bundle: SF Pro ≈ Epilogue/Manrope, SF Mono ≈ Share Tech Mono.

    /// Display/títulos (≈ Epilogue).
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight)
    }

    /// Texto de UI (≈ Manrope).
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Datos numéricos / etiquetas de terminal (≈ Share Tech Mono).
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Etiqueta en versalitas espaciada (como los `text-[10px] uppercase
    /// tracking-wider` de la landing).
    static func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .bold)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Componentes
// ═══════════════════════════════════════════════════════════════════════════

/// Tarjeta blanca con borde redondeado (equivalente a `.planner-card`).
struct BotanicalCard<Content: View>: View {
    var padding: CGFloat = 14
    var tint: Color = Theme.card
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }
}

/// Chip / pastilla (`bg-sageLight border-sageBorder`).
struct Chip: View {
    let text: String
    var systemImage: String?
    var foreground: Color = Theme.mint
    var background: Color = Theme.surface

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 8, weight: .bold))
            }
            Text(text).font(Theme.label(9))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous).fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 0.8)
        )
    }
}

/// Etiqueta de sección en versalitas (tracking amplio, `inkSoft`).
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(10))
            .tracking(0.9)
            .foregroundStyle(Theme.inkSoft)
    }
}

/// Botón primario verde bosque.
struct ForestButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(compact ? 12 : 13, .semibold))
            .foregroundStyle(Theme.base)
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 5 : 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isEnabled ? Theme.mint : Theme.inkFaint)
                    .opacity(configuration.isPressed ? 0.75 : 1)
            )
    }
}

/// Botón secundario (superficie + borde).
struct OutlineButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(compact ? 12 : 13, .medium))
            .foregroundStyle(Theme.inkSoft)
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 5 : 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.surface)
                    .opacity(configuration.isPressed ? 0.7 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }
}

/// Caja de campo (textfield/picker) con la superficie del tema y borde que
/// resalta al enfocar.
struct FieldBox<Content: View>: View {
    var focused: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(focused ? Theme.mint : Theme.border,
                                  lineWidth: focused ? 1.6 : 1)
            )
    }
}

/// Panel LCD: caja oscura con dígitos de 7 segmentos, dígitos fantasma de fondo
/// y etiquetas de terminal (`.digital-lcd` + contador de la landing).
///
/// - Parameters:
///   - compactText: valor principal ya formateado (p. ej. `$419.856`).
///   - ghostText: patrón de dígitos fantasma (p. ej. `888.888`).
///   - digitWidth: ancho de cada dígito; define el tamaño del display.
///   - leftLabel/rightLabel: línea superior de la terminal.
struct LCDPanel: View {
    let compactText: String
    let ghostText: String
    var digitWidth: CGFloat = 28
    var prefix: String? = nil
    var leftLabel: String = "DIGITAL DISPLAY"
    var rightLabel: String = ""
    var footer: String = ""

    var body: some View {
        VStack(spacing: 6) {
            // Terminal superior.
            HStack {
                Text(leftLabel)
                Spacer()
                if !rightLabel.isEmpty { Text(rightLabel) }
            }
            .font(Theme.mono(9, .medium))
            .tracking(1.1)
            .foregroundStyle(Theme.lcdLabel)

            // Display: dígitos fantasma al fondo + valor real con glow.
            HStack(alignment: .bottom, spacing: 5) {
                if let prefix {
                    Text(prefix)
                        .font(Theme.mono(max(11, digitWidth * 0.55), .bold))
                        .foregroundStyle(Theme.lcdDigit)
                        .padding(.bottom, digitWidth * 0.24)
                }
                ZStack {
                    DigiSeven(text: ghostText,
                              color: Theme.lcdDim,
                              dimColor: Theme.lcdDim.opacity(0.4),
                              digitWidth: digitWidth)
                    DigiSeven(text: compactText,
                              color: Theme.lcdDigit,
                              dimColor: Theme.lcdDim,
                              digitWidth: digitWidth)
                        .shadow(color: Theme.lcdDigit.opacity(0.55), radius: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            if !footer.isEmpty {
                HStack(spacing: 5) {
                    PulseDot()
                    Text(footer)
                        .font(Theme.mono(10, .medium))
                        .foregroundStyle(Theme.lcdDigit.opacity(0.9))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Theme.lcdBg, Theme.lcdBgDeep],
                        center: .center, startRadius: 4, endRadius: 190
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.lcdBorder, lineWidth: 1.4)
        )
    }
}

/// Punto verde con halo (equivalente al `animate-ping` de la landing).
struct PulseDot: View {
    @State private var on = false

    var body: some View {
        Circle()
            .fill(Theme.lcdDigit)
            .frame(width: 5, height: 5)
            .overlay(
                Circle()
                    .stroke(Theme.lcdDigit.opacity(0.6), lineWidth: 1)
                    .scaleEffect(on ? 1.9 : 1)
                    .opacity(on ? 0 : 1)
            )
            .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false),
                       value: on)
            .onAppear { on = true }
    }
}

/// Barra de progreso con degradado sage→forest (como la landing).
struct BotanicalProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surface).frame(height: 8)
                Capsule()
                    .fill(
                        LinearGradient(colors: [Theme.sage, Theme.forest],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(6, geo.size.width * min(max(progress, 0), 1)),
                           height: 8)
            }
        }
        .frame(height: 8)
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.8))
    }
}

/// Tarjeta de dato del popover (label en versalitas + valor mono).
struct DataCard: View {
    let label: String
    let value: String
    var accent: Bool = false

    var body: some View {
        BotanicalCard(padding: 9) {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: label)
                Text(value)
                    .font(Theme.mono(accent ? 14 : 12, .bold))
                    .foregroundStyle(accent ? Theme.forest : Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }
}