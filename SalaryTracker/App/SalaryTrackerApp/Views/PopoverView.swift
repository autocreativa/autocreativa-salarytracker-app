import SwiftUI
import Foundation
import SalaryTrackerCore

/// Formateadores de fecha para el popover/settings (locale es_CL, zona actual).
enum DateFmt {
    /// "25 sep" (etiqueta compacta de período / próximo pago).
    static let short: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CL")
        f.dateFormat = "dd MMM"
        return f
    }()
    /// "25 de septiembre de 2026, 09:00" (texto legible completo).
    static let full: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CL")
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()
    /// "30 de octubre de 2026" (solo día, mes y año; resumen de configuración).
    static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CL")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()
    /// "30 de oct" (tarjetas del popover: día + mes, sin año).
    static let medium: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CL")
        f.dateFormat = "d 'de' MMM"
        return f
    }()
}

/// Popover de detalle en tiempo real (specs/menubar-experience "Popover de
/// detalle"), con la identidad visual de la landing: base crema, tarjeta LCD
/// oscura con dígitos de 7 segmentos en verde menta, barra de progreso
/// degradada y tarjetas de datos.
struct PopoverView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.borderSoft)
            content
                .padding(16)
        }
        .frame(width: 344)
        .background(Theme.base)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch model.state {
            case .notConfigured:      notConfiguredBody
            case .invalid(let reason): invalidBody(reason)
            case .futureStart(let starts, let firstPay, let salary, let code):
                futureBody(starts: starts, firstPay: firstPay, salary: salary, code: code)
            case .active(let v):      periodBody(v)
            case .openEnded(let v):   openEndedBody(v)
            }
        }
    }

    /// Abre la ventana dedicada de configuración (AppKit; al hacerse key, el
    /// popover de la barra se oculta solo).
    private func openSettings() {
        SettingsWindowController.shared.show(model: model)
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack(spacing: 8) {
            Text("SalaryTracker")
                .font(Theme.display(14, .heavy))
                .foregroundStyle(Theme.ink)
            if model.config != nil {
                Chip(text: "Config OK", systemImage: "checkmark.seal.fill")
            }
            Spacer()
            Button {
                openSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Configuración")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Cuerpo común (período activo o abierto)

    @ViewBuilder
    private func periodBody(_ v: PeriodView) -> some View {
        earnedHeader(value: v.earned, code: v.currencyCode)

        // Panel LCD (valor dominante).
        BotanicalCard(padding: 0, tint: .clear) {
            LCDPanel(
                compactText: CurrencyFormatter.formatCompact(v.earned, code: v.currencyCode),
                ghostText: ghostPattern(for: v.earned, code: v.currencyCode),
                digitWidth: lcdDigitWidth(for: v.earned, code: v.currencyCode) + 6,
                prefix: CurrencyCatalog.symbol(forCode: v.currencyCode),
                rightLabel: rateLabel(v),
                footer: rateFooter(v)
            )
        }

        // Progreso del período + sueldo (meta).
        progressCard(v)

        // Próximo pago / tiempo restante.
        HStack(spacing: 10) {
            if let end = v.end {
                DataCard(label: "Próximo pago",
                         value: DateFmt.medium.string(from: end))
                DataCard(label: "Tiempo restante",
                         value: v.remainingSeconds
                            .map(CurrencyFormatter.formatRemaining) ?? "—")
            } else {
                DataCard(label: "Próximo pago", value: "Sin próximo pago")
                DataCard(label: "Período", value: "Abierto")
            }
        }

    }

    private func earnedHeader(value: Decimal, code: String) -> some View {
        HStack {
            SectionLabel(text: "Sueldo ganado")
            Spacer()
            Chip(text: "Tiempo real", systemImage: "eye")
        }
    }

    private func progressCard(_ v: PeriodView) -> some View {
        BotanicalCard(padding: 11, tint: Theme.surface) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    SectionLabel(text: "Progreso del período")
                    Spacer()
                    Text(CurrencyFormatter.formatProgress(v.progress))
                        .font(Theme.mono(11, .bold))
                        .foregroundStyle(Theme.forest)
                }
                BotanicalProgressBar(progress: v.progress)
                HStack {
                    Text("\(DateFmt.short.string(from: v.start)) → \(DateFmt.short.string(from: v.end ?? v.start))")
                        .font(Theme.mono(10, .medium))
                        .foregroundStyle(Theme.inkFaint)
                    Spacer()
                    Text("Sueldo \(CurrencyFormatter.format(v.salary, code: v.currencyCode))")
                        .font(Theme.mono(10, .bold))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    // MARK: - Inicio futuro

    @ViewBuilder
    private func futureBody(starts: Date, firstPay: Date?, salary: Decimal, code: String) -> some View {
        earnedHeader(value: 0, code: code)
        LCDPanel(compactText: CurrencyFormatter.formatCompact(0, code: code),
                 ghostText: ghostPattern(for: 0, code: code),
                 digitWidth: 28,
                 prefix: CurrencyCatalog.symbol(forCode: code),
                 rightLabel: "FALTA INICIAR",
                 footer: "El contrato aún no comienza")
        BotanicalCard(padding: 11, tint: Theme.surface) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    SectionLabel(text: "Inicio del contrato")
                    Spacer()
                    Text(DateFmt.dateOnly.string(from: starts))
                        .font(Theme.mono(11, .bold))
                        .foregroundStyle(Theme.ink)
                }
                if let firstPay {
                    HStack {
                        SectionLabel(text: "Primer pago")
                        Spacer()
                        Text(DateFmt.dateOnly.string(from: firstPay))
                            .font(Theme.mono(11, .medium))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                HStack {
                    SectionLabel(text: "Sueldo base")
                    Spacer()
                    Text(CurrencyFormatter.format(salary, code: code))
                        .font(Theme.mono(11, .bold))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        configureButton
    }

    // MARK: - Período abierto (fecha única agotada)

    @ViewBuilder
    private func openEndedBody(_ v: PeriodView) -> some View {
        periodBody(v)
        Chip(text: "Período abierto: sin próximo pago", systemImage: "infinity")
    }

    // MARK: - Invalid / notConfigured

    @ViewBuilder
    private func invalidBody(_ reason: String) -> some View {
        BotanicalCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(hex: 0xD9822B))
                    Text("Configuración inválida")
                        .font(Theme.display(13, .bold))
                        .foregroundStyle(Theme.ink)
                }
                Text(reason)
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                configureButton
            }
        }
    }

    private var notConfiguredBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            BotanicalCard(padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundStyle(Theme.mint)
                        Text("Bienvenido a Salary Tracker")
                            .font(Theme.display(13, .bold))
                            .foregroundStyle(Theme.ink)
                    }
                    Text("Configura tu sueldo, moneda y regla de pago para empezar a ver tu dinero ganado en tiempo real.")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    configureButton
                }
            }
        }
    }

    private var configureButton: some View {
        Button("Configurar") { openSettings() }
            .buttonStyle(ForestButtonStyle())
    }

    // MARK: - Utilidades de formato

    /// Patrón de dígitos fantasma del LCD: misma forma que el valor, todo en 8
    /// (como el "$ 8,888,888.88" de fondo de la landing).
    private func ghostPattern(for value: Decimal, code: String) -> String {
        let compact = CurrencyFormatter.formatCompact(value, code: code)
        return String(compact.map { $0 == "." ? "." : "8" })
    }

    /// Ajusta el ancho de dígito al espacio disponible para que el valor siempre
    /// quepa en el panel.
    private func lcdDigitWidth(for value: Decimal, code: String) -> CGFloat {
        let compact = CurrencyFormatter.formatCompact(value, code: code)
        let digits = Double(compact.filter { $0 != "." }.count)
        let avail: CGFloat = 226   // ancho útil del panel (con prefijo y margen)
        return min(26, max(11, avail / CGFloat(digits * 1.85 + 1.2)))
    }

    /// "+$0.59 / SEG" — ritmo de ganancia por segundo.
    private func rateLabel(_ v: PeriodView) -> String {
        guard let end = v.end, end > v.start else { return "RATE: —" }
        let perSecond = (v.salary as NSDecimalNumber).doubleValue / end.timeIntervalSince(v.start)
        let sym = CurrencyCatalog.symbol(forCode: v.currencyCode)
        return "RATE: \(sym)\(String(format: "%.2f", perSecond)) / SEG"
    }

    /// "Ganando ahora mismo: +$0.595/s"
    private func rateFooter(_ v: PeriodView) -> String {
        guard let end = v.end, end > v.start else {
            return "Período abierto: sueldo completo"
        }
        let perSecond = (v.salary as NSDecimalNumber).doubleValue / end.timeIntervalSince(v.start)
        let sym = CurrencyCatalog.symbol(forCode: v.currencyCode)
        return "Ganando ahora mismo  \(sym)\(String(format: "%.3f", perSecond))/s"
    }
}