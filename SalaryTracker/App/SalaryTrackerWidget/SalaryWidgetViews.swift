import SwiftUI
import SalaryTrackerCore

/// Paleta del widget (misma familia que `Theme` de la app; duplicada
/// porque la extensión no puede importar el target de la app).
enum WidgetTheme {
    static let base = Color(light: 0xFAF8F5, dark: 0x12241A)
    static let ink = Color(light: 0x2D3A30, dark: 0xF1F5EF)
    static let inkSoft = Color(light: 0x5F7A65, dark: 0xA6BCAA)
    static let mint = Color(light: 0x2C5237, dark: 0x86EFAC)
    static let lcdBg = Color(hex: 0x15291C)
    static let lcdBorder = Color(hex: 0x284C34)
    static let lcdDigit = Color(hex: 0x8CF59B)
    static let lcdDim = Color(hex: 0x20432E)
    static let disabledGray = Color(hex: 0x5A6B5E)
}

extension Color {
    /// Color adaptativo light/dark (mismo patrón que `Theme` de la app).
    init(light: UInt32, dark: UInt32) {
        self.init(
            light: NSColor(srgbRed: Double((light >> 16) & 0xFF) / 255,
                           green: Double((light >> 8) & 0xFF) / 255,
                           blue: Double(light & 0xFF) / 255, alpha: 1),
            dark: NSColor(srgbRed: Double((dark >> 16) & 0xFF) / 255,
                          green: Double((dark >> 8) & 0xFF) / 255,
                          blue: Double(dark & 0xFF) / 255, alpha: 1)
        )
    }

    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark ? dark : light
        })
    }

    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// Fondo del widget: `containerBackground` (macOS 14+) o `background`
/// (macOS 13).
private struct WidgetBackgroundModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.containerBackground(color, for: .widget)
        } else {
            content.background(color)
        }
    }
}

extension View {
    func widgetBackground(_ color: Color) -> some View {
        modifier(WidgetBackgroundModifier(color: color))
    }
}

/// Cuerpo de mensaje compartido por ambos widgets (estado + icono/título/
/// detalle localizados).
struct WidgetMessageView: View {
    let message: WidgetMessage

    var body: some View {
        let (icon, title, detail, accent): (String, String, String?, Color) =
            switch message {
            case .futureStart(let startsAt):
                ("hourglass", L10nWidget.str("widget.futureStart"), startsAt,
                 WidgetTheme.mint)
            case .notConfigured:
                ("gearshape", L10nWidget.str("widget.notConfigured"),
                 L10nWidget.str("widget.notConfigured.hint"), WidgetTheme.inkSoft)
            case .invalid:
                ("exclamationmark.triangle", L10nWidget.str("widget.invalid"),
                 nil, WidgetTheme.inkSoft)
            case .disabled:
                ("pause.circle", L10nWidget.str("widget.disabled"), nil,
                 WidgetTheme.disabledGray)
            }
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetTheme.ink)
                    .lineLimit(2)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(WidgetTheme.inkSoft)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Widget principal «SalaryTracker» (small + medium): dinero ganado (LCD),
/// progreso y próximo pago.
struct SalaryWidgetView: View {

    @Environment(\.widgetFamily) private var family

    let entry: SalaryEntry

    var body: some View {
        Group {
            switch entry.data.status {
            case .active(let earned, let progress, let progressValue, let nextPayment, _):
                if family == .systemMedium {
                    mediumActive(earned: earned, progress: progress,
                                 progressValue: progressValue, nextPayment: nextPayment)
                } else {
                    smallActive(earned: earned, progress: progress,
                                progressValue: progressValue, nextPayment: nextPayment)
                }
            case .message(let msg):
                WidgetMessageView(message: msg)
            }
        }
        .widgetBackground(WidgetTheme.base)
    }

    // MARK: - Estados

    /// Small: glifo + ganado (LCD) + mini-barra de progreso + %.
    private func smallActive(earned: String, progress: String,
                             progressValue: Double, nextPayment: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetTheme.mint)
                Text(L10nWidget.str("widget.earnedLabel"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetTheme.inkSoft)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            LcdText(earned)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                MiniProgressBar(ratio: progressValue)
                    .frame(height: 5)
                Text(progress)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WidgetTheme.inkSoft)
                    .lineLimit(1)
            }
        }
    }

    /// Medium: glifo + etiqueta + %, ganado grande (LCD), barra de progreso
    /// y próximo pago.
    private func mediumActive(earned: String, progress: String,
                              progressValue: Double, nextPayment: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WidgetTheme.mint)
                Text(L10nWidget.str("widget.earnedLabel"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetTheme.inkSoft)
                Spacer(minLength: 0)
                Text(progress)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WidgetTheme.inkSoft)
            }
            Spacer(minLength: 0)
            LcdText(earned)
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.45)
            Spacer(minLength: 0)
            MiniProgressBar(ratio: progressValue)
                .frame(height: 6)
            if let nextPayment {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundStyle(WidgetTheme.inkSoft)
                    Text(L10nWidget.str("widget.nextPayment"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WidgetTheme.inkSoft)
                    Text(nextPayment)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WidgetTheme.ink)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// Widget «SalaryTracker · Avance» (small + medium): % grande, barra de
/// progreso y cuenta atrás al próximo pago.
struct ProgressWidgetView: View {

    @Environment(\.widgetFamily) private var family

    let entry: SalaryEntry

    var body: some View {
        Group {
            switch entry.data.status {
            case .active(_, let progress, let progressValue, let nextPayment, let remaining):
                if family == .systemMedium {
                    mediumProgress(progress: progress, progressValue: progressValue,
                                   nextPayment: nextPayment, remaining: remaining)
                } else {
                    smallProgress(progress: progress, progressValue: progressValue,
                                  nextPayment: nextPayment, remaining: remaining)
                }
            case .message(let msg):
                WidgetMessageView(message: msg)
            }
        }
        .widgetBackground(WidgetTheme.base)
    }

    // MARK: - Estados

    /// Small: glifo + «Avance» + % grande + mini-barra + fecha del pago.
    private func smallProgress(progress: String, progressValue: Double,
                               nextPayment: String?, remaining: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetTheme.mint)
                Text(L10nWidget.str("widget.progressLabel"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetTheme.inkSoft)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            Text(progress)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(WidgetTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                MiniProgressBar(ratio: progressValue)
                    .frame(height: 5)
                if let nextPayment {
                    Text(nextPayment)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(WidgetTheme.inkSoft)
                        .lineLimit(1)
                }
            }
        }
    }

    /// Medium: glifo + «Avance del período» + % grande (LCD), barra de
    /// progreso, próximo pago y cuenta atrás.
    private func mediumProgress(progress: String, progressValue: Double,
                                nextPayment: String?, remaining: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WidgetTheme.mint)
                Text(L10nWidget.str("widget.progressLabel"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetTheme.inkSoft)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            LcdText(progress)
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.45)
            Spacer(minLength: 0)
            MiniProgressBar(ratio: progressValue)
                .frame(height: 6)
            HStack(spacing: 12) {
                if let nextPayment {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundStyle(WidgetTheme.inkSoft)
                        Text(L10nWidget.str("widget.nextPayment"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(WidgetTheme.inkSoft)
                        Text(nextPayment)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(WidgetTheme.ink)
                            .lineLimit(1)
                    }
                }
                if let remaining {
                    HStack(spacing: 5) {
                        Image(systemName: "timer")
                            .font(.system(size: 11))
                            .foregroundStyle(WidgetTheme.inkSoft)
                        Text(L10nWidget.str("widget.remaining"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(WidgetTheme.inkSoft)
                        Text(remaining)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(WidgetTheme.ink)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Texto con estilo "LCD" (fondo verde oscuro, dígito verde neón).
private struct LcdText: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(WidgetTheme.lcdBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(WidgetTheme.lcdBorder, lineWidth: 1)
            )
            .foregroundStyle(WidgetTheme.lcdDigit)
    }
}

/// Barra de progreso simple (el ratio lo aporta la entrada del timeline).
private struct MiniProgressBar: View {
    let ratio: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WidgetTheme.lcdDim)
                Capsule()
                    .fill(WidgetTheme.lcdDigit)
                    .frame(width: geo.size.width * min(max(ratio, 0), 1))
            }
        }
    }
}
