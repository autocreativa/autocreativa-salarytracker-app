import SwiftUI
import Foundation
import SalaryTrackerCore

/// Vista de configuración dedicada (specs/settings-view), con la identidad
/// visual de la landing: base crema, tarjetas blancas con borde `sageBorder`,
/// etiqueta de sección en versalitas y botón primario verde bosque.
///
/// Secciones: Sueldo, Inicio del contrato, Día de pago, Idioma, Inicio
/// automático. Validación + guardado explícito: el botón se habilita solo con
/// config válida; descartar no persiste. El resumen recalcula en vivo sobre
/// los valores pendientes.
///
/// Multilenguaje: los textos salen de `L10n`; el locale de fechas/números
/// viene de `model.language.effectiveLocale` (picker de idioma en
/// `languageSection`, persistido por `LanguageManager`).
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    /// Cierra la ventana de configuración (la provee `SettingsWindowController`).
    var onClose: () -> Void = {}

    // Valores pendientes (se inicializan desde la config vigente).
    @State private var salaryText: String = ""
    @State private var currencyCode: String = "CLP"
    @State private var startDate: Date = .now
    @State private var startTime: Date = .now
    @State private var ruleType: RuleType = .lastFriday
    @State private var monthDay: Int = 25
    @State private var specificDate: Date = .now
    @FocusState private var salaryFocused: Bool

    /// Login item ("abrir al iniciar sesión"); el toggle escribe en el sistema.
    @StateObject private var loginItem = LoginItemService()

    private let calculator = SalaryCalculator()

    /// Locale del idioma vigente (para fechas y números).
    private var locale: Locale { model.language.effectiveLocale }

    /// Reglas de pago (etiqueta nativa vía `L10n`; el rawValue es una clave
    /// estable, NO el texto visible).
    enum RuleType: String, CaseIterable, Identifiable {
        case lastFriday
        case monthDay
        case specificDate
        var id: String { rawValue }
        @MainActor
        var displayName: String {
            switch self {
            case .lastFriday:   return L10n.str("rule.lastFriday")
            case .monthDay:     return L10n.str("rule.monthDay")
            case .specificDate: return L10n.str("rule.specificDate")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.borderSoft).frame(height: 1)

            ScrollView {
                VStack(spacing: 14) {
                    salarySection
                    startSection
                    paymentRuleSection
                    languageSection
                    widgetsSection
                    menuBarSection
                    startupSection
                }
                .padding(16)
            }
        }
        .frame(minWidth: 420, minHeight: 560)
        .background(Theme.base)
        .onAppear(perform: loadCurrent)
        .id(model.language.selection)   // re-renderiza al cambiar de idioma
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            // `padding` extra a la izquierda: deja sitio a los botones de la
            // ventana (titlebar transparente) y replica el mockup de la landing.
            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.str("settings.title"))
                    .font(Theme.display(16, .heavy))
                    .foregroundStyle(Theme.ink)
                Text(L10n.str("settings.subtitle"))
                    .font(Theme.mono(10, .medium))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer()
            Button(L10n.str("button.discard")) { discard() }
                .buttonStyle(OutlineButtonStyle(compact: true))
            Button(L10n.str("button.save")) { save() }
                .buttonStyle(ForestButtonStyle(compact: true))
                .disabled(!validation.isValid)
        }
        .padding(.leading, 84)
        .padding(.trailing, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Secciones

    private var salarySection: some View {
        SectionCard(title: L10n.str("section.salary"), systemImage: "banknote") {
            VStack(spacing: 10) {
                FieldBox(focused: salaryFocused) {
                    TextField(L10n.str("field.salaryPlaceholder"), text: $salaryText)
                        .textFieldStyle(.plain)
                        .font(Theme.mono(14, .bold))
                        .foregroundStyle(Theme.ink)
                        .focused($salaryFocused)
                        .onSubmit { formatSalaryField() }
                }
                FieldBox {
                    Picker(L10n.str("label.currency"), selection: $currencyCode) {
                        ForEach(CurrencyCatalog.all, id: \.code) { c in
                            Text("\(c.code)  \(c.symbol)").tag(c.code)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 11))
                    Text(L10n.str("salary.hint"))
                        .font(Theme.body(11))
                }
                .foregroundStyle(Theme.inkFaint)
            }
        }
    }

    private var startSection: some View {
        SectionCard(title: L10n.str("section.contractStart"), systemImage: "calendar") {
            HStack(spacing: 10) {
                FieldBox {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, locale)
                }
                FieldBox {
                    DatePicker("", selection: $startTime,
                               displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .environment(\.locale, locale)
                        .frame(width: 140)
                }
            }
        }
    }

    private var paymentRuleSection: some View {
        SectionCard(title: L10n.str("section.paymentDay"), systemImage: "clock") {
            VStack(alignment: .leading, spacing: 10) {
                FieldBox {
                    Picker(L10n.str("label.rule"), selection: $ruleType) {
                        ForEach(RuleType.allCases) { t in Text(t.displayName).tag(t) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                switch ruleType {
                case .lastFriday:
                    hint(L10n.str("rule.hint.lastFriday"))
                case .monthDay:
                    HStack(spacing: 8) {
                        SectionLabel(text: L10n.str("label.dayOfMonth"))
                        FieldBox {
                            TextField("1-31", value: $monthDay, format: .number)
                                .textFieldStyle(.plain)
                                .font(Theme.mono(13, .bold))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                        }
                        .frame(width: 74)
                    }
                case .specificDate:
                    FieldBox {
                        DatePicker("", selection: $specificDate,
                                   displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.locale, locale)
                    }
                    hint(L10n.str("rule.hint.specificDate"))
                }

                if let next = nextPaymentPreview {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 11))
                        Text(L10n.str("settings.nextPaymentPreview",
                                      DateFmt.dateOnly(locale).string(from: next)))
                            .font(Theme.mono(11, .bold))
                    }
                    .foregroundStyle(Theme.mint)
                }
            }
        }
    }

    @ViewBuilder
    // MARK: - Idioma

    /// Selector de idioma de la app. El cambio se aplica al instante (los
    /// textos se re-leen vía `L10n` y el locale se re-inyecta) y persiste en
    /// `UserDefaults` para el próximo lanzamiento (override `AppleLanguages`).
    private var languageSection: some View {
        SectionCard(title: L10n.str("section.language"), systemImage: "globe") {
            FieldBox {
                Picker(L10n.str("label.language"), selection: $model.language.selection) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    @ViewBuilder
    // MARK: - Widgets

    /// Sección «Widgets»: dos toggles **idénticos y separados** (uno por
    /// superficie: barra superior/Control Center y centro de
    /// notificaciones), separados por un divisor. ON = ese widget muestra
    /// datos; OFF = si está colocado, muestra «desactivado» (macOS no
    /// permite quitarlo del lugar sin intervención del usuario, por lo que
    /// el toggle actúa como interruptor de contenido por superficie).
    ///
    /// Si la detección de `WidgetService` ve el kind instalado, bajo el
    /// título se muestra un check «instalado»; si no hay widgets colocados
    /// se muestra el guion inline de colocación (galería de widgets).
    private var widgetsSection: some View {
        SectionCard(title: L10n.str("section.widgets"), systemImage: "square.grid.2x2") {
            VStack(spacing: 10) {
                widgetToggleRow(labelKey: "widget.toggle.menuBar",
                                isOn: model.widgetService.menuBarBinding,
                                nameKey: "widget.name.main",
                                kind: WidgetService.mainKind)
                Rectangle().fill(Theme.borderSoft).frame(height: 1)
                widgetToggleRow(labelKey: "widget.toggle.notificationCenter",
                                isOn: model.widgetService.notificationCenterBinding,
                                nameKey: "widget.name.progress",
                                kind: WidgetService.progressKind)
                if model.widgetService.installedKinds.isEmpty {
                    Text(L10n.str("widget.guide"))
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Fila de toggle idéntica para cada superficie: título, estado de
    /// colocación y switch.
    @ViewBuilder
    private func widgetToggleRow(labelKey: String, isOn: Binding<Bool>,
                                 nameKey: String, kind: String) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.str(labelKey))
                    .font(Theme.body(13, .semibold))
                    .foregroundStyle(Theme.ink)
                installedLine(nameKey: nameKey, kind: kind)
            }
        }
        .toggleStyle(.switch)
        .tint(Theme.forest)
    }

    /// Línea de estado de un widget: «{nombre} — instalado» (check verde)
    /// si `WidgetService` detecta el kind colocado; `nil` en caso contrario.
    @ViewBuilder
    private func installedLine(nameKey: String, kind: String) -> some View {
        if model.widgetService.isInstalled(kind) {
            HStack(spacing: 4) {
                Text(L10n.str(nameKey))
                    .font(Theme.body(11, .medium))
                    .foregroundStyle(Theme.inkSoft)
                Label(L10n.str("widget.installed"), systemImage: "checkmark.circle.fill")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.forest)
            }
        }
    }

    @ViewBuilder
    // MARK: - Inicio automático

    /// Opción "Abrir al iniciar sesión" (login item). El estado vive en
    /// `LoginItemService`; el toggle aplica el cambio de inmediato y muestra
    /// el error si macOS lo rechaza (p. ej. la app no está en /Applications).
    private var menuBarSection: some View {
        SectionCard(title: L10n.str("section.menuBar"), systemImage: "menubar.rectangle") {
            Toggle(isOn: $model.showMenuBarChip) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.str("chip.toggle"))
                        .font(Theme.body(13, .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(L10n.str("chip.subtitle"))
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            .tint(Theme.forest)
        }
    }

    private var startupSection: some View {
        SectionCard(title: L10n.str("section.autostart"), systemImage: "power") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: loginItem.toggleBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.str("startup.title"))
                            .font(Theme.body(13, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(L10n.str("startup.subtitle"))
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.forest)
                if let err = loginItem.lastError {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.body(11))
                        .foregroundStyle(Color(hex: 0xC1442E))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var summaryValues: some View {
        // Recalcula en vivo sobre los valores pendientes (specs/settings-view
        // "Resumen en vivo") usando el mismo motor puro que la app.
        let state = calculator.evaluate(config: pendingConfig, now: Date())
        switch state {
        case .active(let v):
            summaryView(v)
        case .openEnded(let v):
            summaryView(v)
        case .futureStart(startsAt: let starts, firstPayment: let firstPay,
                          salary: let salary, currencyCode: let code):
            VStack(spacing: 0) {
                summaryRow(L10n.str("label.baseSalary"),
                           CurrencyFormatter.format(salary, code: code, locale: locale))
                summaryRow(L10n.str("summary.earnedThisMonth"),
                           CurrencyFormatter.format(Decimal(0), code: code, locale: locale))
                summaryRow(L10n.str("summary.totalEarned"),
                           CurrencyFormatter.format(Decimal(0), code: code, locale: locale))
                summaryRow(L10n.str("label.progress"),
                           CurrencyFormatter.formatProgress(0, locale: locale))
                summaryRow(firstPay == nil ? L10n.str("label.start") : L10n.str("popover.firstPayment"),
                           DateFmt.dateOnly(locale).string(from: firstPay ?? starts))
            }
        case .invalid(let reason):
            Label(reason.localizedMessage, systemImage: "exclamationmark.circle.fill")
                .font(Theme.body(13))
                .foregroundStyle(Color(hex: 0xC1442E))
        case .notConfigured:
            Text(L10n.str("summary.empty"))
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func summaryView(_ v: PeriodView) -> some View {
        VStack(spacing: 0) {
            summaryRow(L10n.str("label.baseSalary"),
                       CurrencyFormatter.format(v.salary, code: v.currencyCode, locale: locale))
            summaryRow(L10n.str("summary.earnedThisMonth"),
                       CurrencyFormatter.format(v.earned, code: v.currencyCode, locale: locale),
                       highlight: true)
            summaryRow(L10n.str("summary.totalEarned"),
                       CurrencyFormatter.format(v.totalEarned, code: v.currencyCode, locale: locale))
            summaryRow(L10n.str("popover.period"),
                       "\(DateFmt.short(locale).string(from: v.start)) → \(DateFmt.short(locale).string(from: v.end ?? v.start))")
            if let end = v.end {
                summaryRow(L10n.str("popover.nextPayment"),
                           DateFmt.dateOnly(locale).string(from: end))
                if let rem = v.remainingSeconds {
                    summaryRow(L10n.str("popover.timeRemaining"),
                               CurrencyFormatter.formatRemaining(rem,
                                                                 daysSuffix: L10n.str("time.daysSuffix")))
                }
            } else {
                summaryRow(L10n.str("popover.nextPayment"),
                           L10n.str("summary.noNextPayment"))
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    SectionLabel(text: L10n.str("label.progress"))
                    Spacer()
                    Text(CurrencyFormatter.formatProgress(v.progress, locale: locale))
                        .font(Theme.mono(11, .bold))
                        .foregroundStyle(Theme.forest)
                }
                BotanicalProgressBar(progress: v.progress)
            }
            .padding(.top, 10)
        }
    }

    private func summaryRow(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            Text(value)
                .font(Theme.mono(12, .bold))
                .foregroundStyle(highlight ? Theme.mint : Theme.ink)
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.borderSoft).frame(height: 1)
        }
    }

    private func hint(_ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
            Text(text).font(Theme.body(11))
        }
        .foregroundStyle(Theme.inkFaint)
    }

    // MARK: - Lógica pendiente / validación

    private var pendingConfig: SalaryConfig {
        SalaryConfig(
            salaryAmount: parseSalary(salaryText),
            currencyCode: currencyCode,
            contractStart: localDate(startDate),
            contractStartTime: localTime(startTime),
            paymentRule: pendingRule
        )
    }

    private var pendingRule: PaymentRule {
        switch ruleType {
        case .lastFriday:   return .lastWeekdayOfMonth(weekday: 5)
        case .monthDay:     return .monthDay(day: monthDay)
        case .specificDate: return .specificDate(localDate(specificDate))
        }
    }

    private var validation: ConfigValidator.Result {
        ConfigValidator.validate(pendingConfig)
    }

    private var nextPaymentPreview: Date? {
        guard validation.isValid else { return nil }
        let schedule = PaymentScheduleRegistry.schedule(for: pendingRule)
        return schedule.nextPayment(after: Date(),
                                    payClock: localTime(startTime),
                                    calendar: .gregorian(timeZone: .current))
    }

    // MARK: - Parsing / conversión local

    /// Interpreta el texto del campo de sueldo según el locale del idioma
    /// vigente (separadores de miles/decimal de ese locale; los espacios se
    /// tratan como separador de miles adicional).
    private func parseSalary(_ s: String) -> Decimal {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.locale = locale
        let normalized = s
            .replacingOccurrences(of: nf.groupingSeparator, with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: nf.decimalSeparator, with: ".")
        guard !normalized.isEmpty else { return 0 }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US")) ?? 0
    }

    private func formatSalaryField() {
        let d = parseSalary(salaryText)
        guard d > 0 else { return }
        salaryText = groupedString(d)
    }

    private func localDate(_ d: Date) -> LocalDate {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return LocalDate(year: c.year ?? 2026, month: c.month ?? 1, day: c.day ?? 1)
    }

    private func localTime(_ d: Date) -> LocalTime {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return LocalTime(hour: c.hour ?? 9, minute: c.minute ?? 0)
    }

    // MARK: - Acciones

    private func loadCurrent() {
        // Con config vigente se prellenan sus valores; sin config válida
        // (primera ejecución o archivo corrupto) se prellenan los campos con
        // la configuración por defecto de la app (sueldo 553.553 CLP, último
        // viernes, instante actual) — scenario "Acceso desde el estado no
        // configurado".
        let cfg = model.config ?? SalaryConfig.default()
        salaryText = groupedString(cfg.salaryAmount)
        currencyCode = cfg.currencyCode
        startDate = cfg.contractStartDate(calendar: .gregorian(timeZone: .current))
        startTime = startDate.addingTimeInterval(TimeInterval(cfg.contractStartTime.hour * 3600 + cfg.contractStartTime.minute * 60))
        switch cfg.paymentRule {
        case .lastWeekdayOfMonth: ruleType = .lastFriday
        case .monthDay(let day):  ruleType = .monthDay; monthDay = day
        case .specificDate(let d): ruleType = .specificDate
            specificDate = d.resolve(at: cfg.contractStartTime, calendar: .gregorian(timeZone: .current))
        }
    }

    /// Formatea el monto con los separadores del locale del idioma vigente.
    private func groupedString(_ d: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = locale
        f.maximumFractionDigits = CurrencyCatalog.minorUnitDecimals(forCode: currencyCode)
        return f.string(from: NSDecimalNumber(decimal: d)) ?? String(describing: d)
    }

    private func save() {
        formatSalaryField()
        guard validation.isValid else { return }
        model.save(pendingConfig)
        onClose()
    }

    private func discard() {
        onClose() // No persiste: la config vigente sigue intacta (R-LIVE).
    }
}

/// Tarjeta de sección con icono en cuadro (equivalente a las feature cards de la
/// landing): título + contenido sobre fondo blanco con borde.
struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Theme.surface)
                        .frame(width: 30, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Theme.border, lineWidth: 0.8)
                        )
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.forest)
                }
                SectionLabel(text: title)
                Spacer()
            }
            content
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }
}
