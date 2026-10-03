import Foundation

/// Motor determinista de períodos de pago y dinero ganado
/// (specs/period-engine; design.md D4).
///
/// Es una **función pura**: no lee el reloj del sistema ni mantiene estado.
/// `evaluate(config:now:calendar:)` devuelve el estado derivado para el instante
/// `now`. El rollover no es un evento: es la consecuencia de evaluar con un `now`
/// posterior al fin del período (reglas R-RECOVERY y R-MULTI del proposal).
public struct SalaryCalculator: Sendable {

    public init() {}

    /// Evalúa el estado del tracker para el instante `now`.
    /// - Parameters:
    ///   - config: configuración (sueldo, moneda, inicio, regla).
    ///   - now: instante de evaluación (inyectado; nunca `Date()` interno).
    ///   - calendar: calendario gregoriano con la zona horaria vigente (R-TZ).
    ///     Por defecto: gregoriano con `TimeZone.current`.
    public func evaluate(
        config: SalaryConfig,
        now: Date,
        calendar: Calendar = .gregorian(timeZone: .current)
    ) -> TrackerState {
        // Invariante: sueldo positivo (specs/period-engine "Configuración inválida").
        guard config.salaryAmount > 0 else {
            return .invalid(reason: "El sueldo debe ser mayor que cero.")
        }

        let start0 = config.contractStartDate(calendar: calendar)

        // FUTURE_START (regla R-FUTURE): el inicio del contrato está por venir.
        if now < start0 {
            let schedule = PaymentScheduleRegistry.schedule(for: config.paymentRule)
            let firstPayment = schedule.nextPayment(after: start0,
                                                    payClock: config.contractStartTime,
                                                    calendar: calendar)
            return .futureStart(startsAt: start0,
                                firstPayment: firstPayment,
                                salary: config.salaryAmount,
                                currencyCode: config.currencyCode)
        }

        switch config.paymentRule {
        case .specificDate(let day):
            let pay = day.resolve(at: config.contractStartTime, calendar: calendar)
            // Defensivo (la validación lo rechaza en el guardado):
            guard pay > start0 else {
                return .invalid(reason: "La fecha de pago debe ser posterior al inicio del contrato.")
            }
            if now < pay {
                return makeActive(start: start0, end: pay, now: now, config: config)
            }
            // R-ONESHOT: la fecha única ya pasó → período abierto: el único
            // período se completó, por lo que el total es el sueldo completo.
            let open = PeriodView(start: start0, end: nil,
                                  salary: config.salaryAmount,
                                  currencyCode: config.currencyCode,
                                  earned: config.salaryAmount,
                                  progress: 1.0,
                                  remainingSeconds: nil,
                                  totalEarned: config.salaryAmount)
            return .openEnded(open)

        case .lastWeekdayOfMonth, .monthDay:
            // Regla recurrente: avanza la cadena de pagos (estricta) hasta el
            // primer pago estrictamente posterior a `now`. El período es
            // [pPrev ?? start0, p). Acotado: ≤ ~12 iteraciones por año
            // (specs/period-engine "Rollover automático", reglas
            // R-RECOVERY/R-MULTI). El pago igual a `now` marca el fin del
            // período anterior y el inicio del nuevo (rollover exacto).
            let schedule = PaymentScheduleRegistry.schedule(for: config.paymentRule)
            var pPrev: Date? = nil
            var p = schedule.nextPayment(after: start0,
                                         payClock: config.contractStartTime,
                                         calendar: calendar)!
            var completed = 0
            while p <= now {
                pPrev = p
                completed += 1
                guard let p2 = schedule.nextPayment(after: p,
                                                    payClock: config.contractStartTime,
                                                    calendar: calendar) else {
                    break
                }
                p = p2
            }
            let periodStart = pPrev ?? start0
            return makeActive(start: periodStart, end: p, now: now, config: config,
                              completedPeriods: completed)
        }
    }

    /// Construye el estado `active` con el cálculo proporcional
    /// `sueldo × (now − start) / (end − start)` (specs/period-engine
    /// "Cálculo proporcional del dinero ganado"), acotado a [0, sueldo].
    private func makeActive(start: Date, end: Date, now: Date,
                            config: SalaryConfig,
                            completedPeriods: Int = 0) -> TrackerState {
        let duration = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        // Invariante del período: start < end y now ≥ start (garantizado por el
        // flujo anterior); acotamos para robustez.
        let ratio = min(max(duration > 0 ? elapsed / duration : 0, 0), 1)
        let earned = (config.salaryAmount as NSDecimalNumber)
            .multiplying(by: NSDecimalNumber(value: ratio))
            .decimalValue
        // Total acumulado: sueldos de los períodos ya completados + ganado
        // del período en curso (specs/period-engine "Total ganado acumulado").
        let total = (config.salaryAmount as NSDecimalNumber)
            .multiplying(by: NSDecimalNumber(value: completedPeriods))
            .adding(NSDecimalNumber(decimal: earned))
            .decimalValue
        let view = PeriodView(
            start: start,
            end: end,
            salary: config.salaryAmount,
            currencyCode: config.currencyCode,
            earned: earned,
            progress: ratio,
            remainingSeconds: max(end.timeIntervalSince(now), 0),
            totalEarned: total
        )
        return .active(view)
    }
}
