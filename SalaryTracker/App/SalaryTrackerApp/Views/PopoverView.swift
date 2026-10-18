import SwiftUI
import Foundation
import SalaryTrackerCore

/// Formateadores de fecha del popover/settings (locale del idioma vigente,
/// zona horaria actual). Se construyen por locale (factory) para poder
/// recrearlos al cambiar de idioma.
enum DateFmt {
    /// "25 sep" (etiqueta compacta de período / próximo pago).
    static func short(_ locale: Locale) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "dd MMM"
        return f
    }
    /// "25 de septiembre de 2026, 09:00" (texto legible completo).
    static func full(_ locale: Locale) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }
    /// "30 de octubre de 2026" (solo día, mes y año; resumen de configuración).
    static func dateOnly(_ locale: Locale) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }
    /// "30 oct 2026" / "Oct 30, 2026" (tarjetas del popover: estilo medio,
    /// totalmente localizable; sin año fijo para no romper el layout).
    static func medium(_ locale: Locale) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }
}

/// Popover de detalle en tiempo real (specs/menubar-experience "Popover de
/// detalle"), con la identidad visual de la landing: base crema, tarjeta LCD
/// oscura con dígitos de 7 segmentos en verde menta, barra de progreso
/// degradada y tarjetas de datos.
///
/// Multilenguaje: los textos salen de `L10n` (recursos `Localizable.strings`)
/// y el locale de fechas/números viene de `model.language.effectiveLocale`.
struct PopoverView: View {
    @EnvironmentObject var model: AppModel

    /// Locale del idioma vigente (para fechas y porcentajes).
    private var locale: Locale { model.language.effectiveLocale }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.borderSoft)
            content
                .padding(16)
        }
        .frame(width: 344)
        .background(Theme.base)
        .id(model.language.selection)   // re-renderiza al cambiar de idioma
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
                Chip(text: L10n.str("chip.configOk"), systemImage: "checkmark.seal.fill")
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
            .accessibilityLabel(L10n.str("a11y.settings"))
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
                compactText: CurrencyFormatter.formatCompact(v.earned, code: v.currencyCode, locale: locale),
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
                DataCard(label: L10n.str("popover.nextPayment"),
                         value: DateFmt.medium(locale).string(from: end))
                DataCard(label: L10n.str("popover.timeRemaining"),
                         value: v.remainingSeconds
                             .map { CurrencyFormatter.formatRemaining($0, daysSuffix: L10n.str("time.daysSuffix")) } ?? "—")
            } else {
                DataCard(label: L10n.str("popover.nextPayment"), value: L10n.str("popover.noNextPayment"))
                DataCard(label: L10n.str("popover.period"), value: L10n.str("popover.open"))
            }
        }
    }

    private func earnedHeader(value: Decimal, code: String) -> some View {
        HStack {
            SectionLabel(text: L10n.str("popover.earnedHeader"))
            Spacer()
            Chip(text: L10n.str("chip.realtime"), systemImage: "eye")
        }
    }

    private func progressCard(_ v: PeriodView) -> some View {
        BotanicalCard(padding: 11, tint: Theme.surface) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    SectionLabel(text: L10n.str("popover.progress"))
                    Spacer()
                    Text(CurrencyFormatter.formatProgress(v.progress, locale: locale))
                        .font(Theme.mono(11, .bold))
                        .foregroundStyle(Theme.forest)
                }
                BotanicalProgressBar(progress: v.progress)
                HStack {
                    Text("\(DateFmt.short(locale).string(from: v.start)) → \(DateFmt.short(locale).string(from: v.end ?? v.start))")
                        .font(Theme.mono(10, .medium))
                        .foregroundStyle(Theme.inkFaint)
                    Spacer()
                    Text(L10n.str("popover.salaryAmount",
                                  CurrencyFormatter.format(v.salary, code: v.currencyCode, locale: locale)))
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
        LCDPanel(compactText: CurrencyFormatter.formatCompact(0, code: code, locale: locale),
                 ghostText: ghostPattern(for: 0, code: code),
                 digitWidth: 28,
                 prefix: CurrencyCatalog.symbol(forCode: code),
                 rightLabel: L10n.str("lcd.notStarted"),
                 footer: L10n.str("lcd.notStartedFooter"))
        BotanicalCard(padding: 11, tint: Theme.surface) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    SectionLabel(text: L10n.str("section.contractStart"))
                    Spacer()
                    Text(DateFmt.dateOnly(locale).string(from: starts))
                        .font(Theme.mono(11, .bold))
                        .foregroundStyle(Theme.ink)
                }
                if let firstPay {
                    HStack {
                        SectionLabel(text: L10n.str("popover.firstPayment"))
                        Spacer()
                        Text(DateFmt.dateOnly(locale).string(from: firstPay))
                            .font(Theme.mono(11, .medium))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                HStack {
                    SectionLabel(text: L10n.str("label.baseSalary"))
                    Spacer()
                    Text(CurrencyFormatter.format(salary, code: code, locale: locale))
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
        Chip(text: L10n.str("chip.openEnded"), systemImage: "infinity")
    }

    // MARK: - Invalid / notConfigured

    @ViewBuilder
    private func invalidBody(_ reason: TrackerState.InvalidReason) -> some View {
        BotanicalCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(hex: 0xD9822B))
                    Text(L10n.str("popover.invalidTitle"))
                        .font(Theme.display(13, .bold))
                        .foregroundStyle(Theme.ink)
                }
                // El detalle del error de archivo (si existe) tiene prioridad;
                // si no, el mensaje localizable de la causa estable.
                Text(model.loadIssue ?? reason.localizedMessage)
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
                        Text(L10n.str("welcome.title"))
                            .font(Theme.display(13, .bold))
                            .foregroundStyle(Theme.ink)
                    }
                    Text(L10n.str("welcome.body"))
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    configureButton
                }
            }
        }
    }

    private var configureButton: some View {
        Button(L10n.str("button.configure")) { openSettings() }
            .buttonStyle(ForestButtonStyle())
    }

    // MARK: - Utilidades de formato

    /// Patrón de dígitos fantasma del LCD: misma forma que el valor, todo en 8
    /// (como el "$ 8,888,888.88" de fondo de la landing).
    private func ghostPattern(for value: Decimal, code: String) -> String {
        let compact = CurrencyFormatter.formatCompact(value, code: code, locale: locale)
        return String(compact.map { $0.isNumber ? "8" : $0 })
    }

    /// Ajusta el ancho de dígito al espacio disponible para que el valor siempre
    /// quepa en el panel.
    private func lcdDigitWidth(for value: Decimal, code: String) -> CGFloat {
        let compact = CurrencyFormatter.formatCompact(value, code: code, locale: locale)
        let digits = Double(compact.filter { $0.isNumber }.count)
        let avail: CGFloat = 226   // ancho útil del panel (con prefijo y margen)
        return min(26, max(11, avail / CGFloat(digits * 1.85 + 1.2)))
    }

    /// "RATE: $0.59 / SEG" — ritmo de ganancia por segundo.
    private func rateLabel(_ v: PeriodView) -> String {
        guard let end = v.end, end > v.start else { return L10n.str("lcd.rateIdle") }
        let perSecond = (v.salary as NSDecimalNumber).doubleValue / end.timeIntervalSince(v.start)
        let amount = CurrencyFormatter.format(perSecond, code: v.currencyCode, locale: locale)
        return L10n.str("lcd.rate", amount)
    }

    /// "Ganando ahora mismo: +$0.595/s"
    private func rateFooter(_ v: PeriodView) -> String {
        guard let end = v.end, end > v.start else {
            return L10n.str("lcd.openEndedFooter")
        }
        let perSecond = (v.salary as NSDecimalNumber).doubleValue / end.timeIntervalSince(v.start)
        let sym = CurrencyCatalog.symbol(forCode: v.currencyCode)
        let amount = "\(sym)\(String(format: "%.3f", perSecond))"
        return L10n.str("lcd.earningNow", amount)
    }
}
