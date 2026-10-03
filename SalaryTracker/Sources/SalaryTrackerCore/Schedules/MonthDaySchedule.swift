import Foundation

/// Regla "día N de cada mes" (specs/payment-schedules "Día fijo del mes").
/// Cuando N no existe en el mes (p. ej. 31 en un mes de 30 días), el pago se
/// resuelve al siguiente mes en que exista N (regla R-SKIP).
public struct MonthDaySchedule: PaymentSchedule {
    public let day: Int

    public init(day: Int) {
        precondition((1...31).contains(day), "día fuera de rango 1-31: \(day)")
        self.day = day
    }

    public var label: String {
        "Día \(day) de cada mes"
    }

    public func nextPayment(after: Date, payClock: LocalTime, calendar: Calendar) -> Date? {
        let initial = calendar.dateComponents([.year, .month], from: after)
        guard let iYear = initial.year, let iMonth = initial.month else { return nil }
        var year = iYear
        var month = iMonth
        while true {
            let candidate = monthDay(year: year, month: month,
                                     payClock: payClock,
                                     calendar: calendar)
            if let candidate, candidate > after { return candidate }
            // Estrictidad o mes sin día N (R-SKIP): avanzar al mes siguiente.
            month += 1
            if month > 12 { month = 1; year += 1 }
        }
    }

    private func monthDay(year: Int, month: Int,
                          payClock: LocalTime, calendar: Calendar) -> Date? {
        var firstComps = DateComponents()
        firstComps.year = year; firstComps.month = month; firstComps.day = 1
        guard let firstOfMonth = calendar.date(from: firstComps),
              let dayRange = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return nil
        }
        guard day <= dayRange.count else { return nil } // R-SKIP: mes sin este día
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = payClock.hour
        comps.minute = payClock.minute
        comps.second = 0
        return calendar.date(from: comps)
    }
}
