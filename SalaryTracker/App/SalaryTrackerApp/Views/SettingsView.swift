import SwiftUI
import Foundation
import SalaryTrackerCore

/// Vista de configuración dedicada (specs/settings-view). Secciones: Sueldo,
/// Inicio del contrato, Día de pago y Resumen. Validación + guardado
/// explícito: el botón se habilita solo con config válida; descartar no
/// persiste. La vista previa recalcula en vivo sobre los valores pendientes.
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

    private let calculator = SalaryCalculator()

    enum RuleType: String, CaseIterable, Identifiable {
        case lastFriday = "Último viernes de cada mes"
        case monthDay = "Día N de cada mes"
        case specificDate = "Fecha específica"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Barra superior con título y acciones (márgenes generosos).
            HStack {
                Text("Configuración")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
                Button("Descartar") { discard() }
                    .buttonStyle(.bordered)
                Button("Guardar") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!validation.isValid)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(spacing: 22) {
                    salarySection
                    startSection
                    paymentRuleSection
                    previewSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 400, minHeight: 540)
        .onAppear(perform: loadCurrent)
    }

    // MARK: - Secciones

    private var salarySection: some View {
        SectionView(title: "Sueldo", systemImage: "banknote") {
            VStack(spacing: 10) {
                TextField("Monto del período", text: $salaryText)
                    .textFieldStyle(.roundedBorder)
                    .focused($salaryFocused)
                    .onSubmit { formatSalaryField() }
                Picker("Moneda", selection: $currencyCode) {
                    ForEach(CurrencyCatalog.all, id: \.code) { c in
                        Text("\(c.code)  \(c.symbol)").tag(c.code)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var startSection: some View {
        SectionView(title: "Inicio del contrato", systemImage: "calendar") {
            HStack(spacing: 10) {
                DatePicker("Fecha", selection: $startDate,
                           displayedComponents: .date)
                    .labelsHidden()
                DatePicker("Hora", selection: $startTime,
                           displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
        }
    }

    private var paymentRuleSection: some View {
        SectionView(title: "Día de pago", systemImage: "clock") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Regla", selection: $ruleType) {
                    ForEach(RuleType.allCases) { t in Text(t.rawValue).tag(t) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                switch ruleType {
                case .lastFriday:
                    Text("La hora de pago es la hora de inicio del contrato (R-PAYMENT-TIME).")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                case .monthDay:
                    HStack {
                        Text("Día del mes:")
                        TextField("1-31", value: $monthDay, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                    }
                case .specificDate:
                    DatePicker("Fecha de pago", selection: $specificDate,
                               displayedComponents: .date)
                    Text("Tras esta fecha el período queda abierto (sin próximo pago).")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if let next = nextPaymentPreview {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle")
                        Text("Próximo pago: \(DateFmt.full.string(from: next))")
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        SectionView(title: "Resumen", systemImage: "sum") {
            if validation.isValid {
                previewValues
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(validation.errors, id: \.self) { e in
                        Label(e, systemImage: "exclamationmark.circle")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var previewValues: some View {
        // Recalcula en vivo sobre los valores pendientes (specs/settings-view
        // "Vista previa en vivo") usando el mismo motor puro que la app.
        // (sección renombrada a "Resumen" en v1.3)
        let state = calculator.evaluate(config: pendingConfig, now: Date())
        switch state {
        case .active(let v):
            previewView(v)
        case .openEnded(let v):
            previewView(v)
        case .futureStart(startsAt: let starts, firstPayment: let firstPay,
                          salary: let salary, currencyCode: let code):
            VStack(alignment: .leading, spacing: 8) {
                previewRow("Sueldo base",
                            CurrencyFormatter.format(salary, code: code))
                previewRow("Ganado este mes",
                            CurrencyFormatter.format(Decimal(0), code: code))
                previewRow("Total ganado",
                            CurrencyFormatter.format(Decimal(0), code: code))
                previewRow("Progreso", CurrencyFormatter.formatProgress(0))
                if let firstPay {
                    previewRow("Primer pago", DateFmt.dateOnly.string(from: firstPay))
                } else {
                    previewRow("Inicio", DateFmt.dateOnly.string(from: starts))
                }
            }
        case .invalid(let reason):
            Label(reason, systemImage: "exclamationmark.circle")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.red)
        case .notConfigured:
            Text("Sin valores para previsualizar.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func previewView(_ v: PeriodView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            previewRow("Sueldo base",
                        CurrencyFormatter.format(v.salary, code: v.currencyCode))
            previewRow("Ganado este mes",
                        CurrencyFormatter.format(v.earned, code: v.currencyCode))
            previewRow("Total ganado",
                        CurrencyFormatter.format(v.totalEarned, code: v.currencyCode))
            previewRow("Progreso", CurrencyFormatter.formatProgress(v.progress))
            if let end = v.end {
                previewRow("Próximo pago", DateFmt.dateOnly.string(from: end))
                if let rem = v.remainingSeconds {
                    previewRow("Tiempo restante",
                                CurrencyFormatter.formatRemaining(rem))
                }
            } else {
                previewRow("Próximo pago", "sin próximo pago")
            }
        }
    }

    private func previewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).monospacedDigit()
        }
        .font(.system(size: 13, design: .rounded))
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
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = CurrencyCatalog.minorUnitDecimals(forCode: currencyCode)
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        if let s = f.string(from: NSDecimalNumber(decimal: d)) {
            salaryText = s
        }
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

/// Contenedor visual de sección (título + ícono + contenido).
struct SectionView<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}
