import SwiftUI
import Foundation
import SalaryTrackerCore

/// Vista de configuración dedicada (specs/settings-view), con la identidad
/// visual de la landing: base crema, tarjetas blancas con borde `sageBorder`,
/// etiqueta de sección en versalitas y botón primario verde bosque.
///
/// Secciones: Sueldo, Inicio del contrato, Día de pago. Validación +
/// guardado explícito: el botón se habilita solo con config válida; descartar
/// no persiste. El resumen recalcula en vivo sobre los valores pendientes.
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

    enum RuleType: String, CaseIterable, Identifiable {
        case lastFriday = "Último viernes de cada mes"
        case monthDay = "Día N de cada mes"
        case specificDate = "Fecha específica"
        var id: String { rawValue }
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
                    startupSection
                }
                .padding(16)
            }
        }
        .frame(minWidth: 420, minHeight: 560)
        .background(Theme.base)
        .onAppear(perform: loadCurrent)
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            // `padding` extra a la izquierda: deja sitio a los botones de la
            // ventana (titlebar transparente) y replica el mockup de la landing.
            VStack(alignment: .leading, spacing: 1) {
                Text("Configuración")
                    .font(Theme.display(16, .heavy))
                    .foregroundStyle(Theme.ink)
                Text("SalaryTracker · datos locales")
                    .font(Theme.mono(10, .medium))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer()
            Button("Descartar") { discard() }
                .buttonStyle(OutlineButtonStyle(compact: true))
            Button("Guardar") { save() }
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
        SectionCard(title: "Sueldo", systemImage: "banknote") {
            VStack(spacing: 10) {
                FieldBox(focused: salaryFocused) {
                    TextField("Monto del período", text: $salaryText)
                        .textFieldStyle(.plain)
                        .font(Theme.mono(14, .bold))
                        .foregroundStyle(Theme.ink)
                        .focused($salaryFocused)
                        .onSubmit { formatSalaryField() }
                }
                FieldBox {
                    Picker("Moneda", selection: $currencyCode) {
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
                    Text("El monto corresponde a un período de pago completo.")
                        .font(Theme.body(11))
                }
                .foregroundStyle(Theme.inkFaint)
            }
        }
    }

    private var startSection: some View {
        SectionCard(title: "Inicio del contrato", systemImage: "calendar") {
            HStack(spacing: 10) {
                FieldBox {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }
                FieldBox {
                    DatePicker("", selection: $startTime,
                               displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .frame(width: 140)
            }
        }
    }

    private var paymentRuleSection: some View {
        SectionCard(title: "Día de pago", systemImage: "clock") {
            VStack(alignment: .leading, spacing: 10) {
                FieldBox {
                    Picker("Regla", selection: $ruleType) {
                        ForEach(RuleType.allCases) { t in Text(t.rawValue).tag(t) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                switch ruleType {
                case .lastFriday:
                    hint("La hora de pago es la hora de inicio del contrato (R-PAYMENT-TIME).")
                case .monthDay:
                    HStack(spacing: 8) {
                        SectionLabel(text: "Día del mes")
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
                    }
                    hint("Tras esta fecha el período queda abierto (sin próximo pago).")
                }

                if let next = nextPaymentPreview {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 11))
                        Text("Próximo pago: \(DateFmt.dateOnly.string(from: next))")
                            .font(Theme.mono(11, .bold))
                    }
                    .foregroundStyle(Theme.mint)
                }
            }
        }
    }

    @ViewBuilder
    // MARK: - Inicio automático

    /// Opción "Abrir al iniciar sesión" (login item). El estado vive en
    /// `LoginItemService`; el toggle aplica el cambio de inmediato y muestra
    /// el error si macOS lo rechaza (p. ej. la app no está en /Applications).
    private var startupSection: some View {
        SectionCard(title: "Inicio automático", systemImage: "power") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: loginItem.toggleBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Abrir al iniciar sesión")
                            .font(Theme.body(13, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("SalaryTracker se agrega a los elementos de inicio de sesión de macOS y se abre solo al encender la Mac.")
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
                summaryRow("Sueldo base", CurrencyFormatter.format(salary, code: code))
                summaryRow("Ganado este mes", CurrencyFormatter.format(Decimal(0), code: code))
                summaryRow("Total ganado", CurrencyFormatter.format(Decimal(0), code: code))
                summaryRow("Progreso", CurrencyFormatter.formatProgress(0))
                summaryRow(firstPay == nil ? "Inicio" : "Primer pago",
                           DateFmt.dateOnly.string(from: firstPay ?? starts))
            }
        case .invalid(let reason):
            Label(reason, systemImage: "exclamationmark.circle.fill")
                .font(Theme.body(13))
                .foregroundStyle(Color(hex: 0xC1442E))
        case .notConfigured:
            Text("Sin valores para resumir.")
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func summaryView(_ v: PeriodView) -> some View {
        VStack(spacing: 0) {
            summaryRow("Sueldo base", CurrencyFormatter.format(v.salary, code: v.currencyCode))
            summaryRow("Ganado este mes", CurrencyFormatter.format(v.earned, code: v.currencyCode), highlight: true)
            summaryRow("Total ganado", CurrencyFormatter.format(v.totalEarned, code: v.currencyCode))
            summaryRow("Período",
                       "\(DateFmt.short.string(from: v.start)) → \(DateFmt.short.string(from: v.end ?? v.start))")
            if let end = v.end {
                summaryRow("Próximo pago", DateFmt.dateOnly.string(from: end))
                if let rem = v.remainingSeconds {
                    summaryRow("Tiempo restante", CurrencyFormatter.formatRemaining(rem))
                }
            } else {
                summaryRow("Próximo pago", "sin próximo pago")
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    SectionLabel(text: "Progreso")
                    Spacer()
                    Text(CurrencyFormatter.formatProgress(v.progress))
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

    private func parseSalary(_ s: String) -> Decimal {
        var t = s.replacingOccurrences(of: " ", with: "")
        t = t.replacingOccurrences(of: ".", with: "")   // separador de miles
        t = t.replacingOccurrences(of: ",", with: ".")  // decimal
        guard !t.isEmpty, let d = Decimal(string: t, locale: Locale(identifier: "en_US")) else {
            return 0
        }
        return d
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
        if let cfg = model.config {
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
        } else {
            // Defectos razonables (scenario "Acceso desde el estado no configurado").
            salaryText = ""
            currencyCode = "CLP"
            let now = Date()
            startDate = now
            startTime = now
            ruleType = .lastFriday
            monthDay = 25
            specificDate = now
        }
    }

    private func groupedString(_ d: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = CurrencyCatalog.minorUnitDecimals(forCode: currencyCode)
        f.groupingSeparator = "."
        f.decimalSeparator = ","
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