import Foundation
import XCTest
@testable import SalaryTrackerCore

/// Fechas de prueba deterministas (requisito: "no depender del reloj real").
/// Zona horaria de offset fijo (sin DST) para cálculos exactos de segundos.
enum T {
    /// Zona de prueba: UTC-4 fijo (simula, p. ej., hora chilena de invierno).
    static let tz = TimeZone(secondsFromGMT: -4 * 3600)!
    static var calendar: Calendar { .gregorian(timeZone: tz) }

    /// Segunda zona para tests de cambio de zona: UTC+2 fijo.
    static let tz2 = TimeZone(secondsFromGMT: 2 * 3600)!
    static var calendar2: Calendar { .gregorian(timeZone: tz2) }

    /// Construye una fecha local en la zona de prueba.
    static func d(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, _ s: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d
        c.hour = h; c.minute = mi; c.second = s
        return calendar.date(from: c)!
    }

    /// Configuración canónica de los ejemplos del requerimiento:
    /// $1.500.000 CLP, inicio 2026-09-01 09:00, último viernes de cada mes.
    static func baseConfig(
        salary: Decimal = 1_500_000,
        start: LocalDate = LocalDate(year: 2026, month: 9, day: 1),
        time: LocalTime = LocalTime(hour: 9, minute: 0),
        rule: PaymentRule = .lastFriday()
    ) -> SalaryConfig {
        SalaryConfig(salaryAmount: salary,
                     currencyCode: "CLP",
                     contractStart: start,
                     contractStartTime: time,
                     paymentRule: rule)
    }

    static let calculator = SalaryCalculator()
}

/// Decimal → Double para asserts con tolerancia (XCTest no acepta Decimal con accuracy).
@inline(__always) func dv(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }

extension SalaryCalculator {
    /// Evaluación con el calendario/zona de prueba por defecto (determinista;
    /// evita que `TimeZone.current` de la máquina contamine los tests).
    func evaluateTest(config: SalaryConfig, now: Date,
                      calendar: Calendar = T.calendar) -> TrackerState {
        evaluate(config: config, now: now, calendar: calendar)
    }
}

extension TrackerState {
    var activeView: PeriodView? {
        if case .active(let v) = self { return v }
        return nil
    }
    var openEndedView: PeriodView? {
        if case .openEnded(let v) = self { return v }
        return nil
    }
    var futureStartInfo: (startsAt: Date, firstPayment: Date?)? {
        if case .futureStart(let s, let p, _, _) = self { return (s, p) }
        return nil
    }
    var invalidReason: String? {
        if case .invalid(let r) = self { return r }
        return nil
    }
}
