import Foundation

/// Regla "último día-semana de cada mes" (specs/payment-schedules
/// "Último día de la semana del mes"). v1: viernes.
///
/// Algoritmo: en el mes que contiene `after`, el último día con el weekday pedido
/// (siempre está dentro de los últimos 6 días del mes); si el candidato no es
/// estrictamente posterior a `after`, se avanza al mes siguiente. Sin
/// aproximaciones.
public struct LastWeekdayOfMonthSchedule: PaymentSchedule {
    /// ISO-8601: 1 = lunes … 7 = domingo.
    public let weekday: Int

    public init(weekday: Int) {
        precondition((1...7).contains(weekday), "weekday ISO-8601 fuera de rango: \(weekday)")
        self.weekday = weekday
    }

    public var label: String {
        "Último \(Self.weekdayName(weekday)) de cada mes"
    }

    public static func weekdayName(_ isoWeekday: Int) -> String {
        switch isoWeekday {
        case 1: return "lunes"
        case 2: return "martes"
        case 3: return "miércoles"
        case 4: return "jueves"
        case 5: return "viernes"
        case 6: return "sábado"
        default: return "domingo"
        }
    }

    public func nextPayment(after: Date, payClock: LocalTime, calendar: Calendar) -> Date? {
        let target = weekday.foundationWeekday
        let initial = calendar.dateComponents([.year, .month], from: after)
        guard let iYear = initial.year, let iMonth = initial.month else { return nil }
        var year = iYear
        var month = iMonth
        while true {
            let candidate = lastWeekdayOfMonth(year: year, month: month,
                                               weekday: target,
                                               payClock: payClock,
                                               calendar: calendar)
            if let candidate, candidate > after { return candidate }
            // Estrictidad (specs: "Estrictidad cuando la consulta coincide"): si el
            // candidato coincide con `after`, se avanza al mes siguiente.
            month += 1
            if month > 12 { month = 1; year += 1 }
        }
    }

    private func lastWeekdayOfMonth(year: Int, month: Int, weekday: Int,
                                    payClock: LocalTime, calendar: Calendar) -> Date? {
        var firstComps = DateComponents()
        firstComps.year = year; firstComps.month = month; firstComps.day = 1
        guard let firstOfMonth = calendar.date(from: firstComps),
              let dayRange = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return nil
        }
        var lastComps = DateComponents()
        lastComps.year = year; lastComps.month = month; lastComps.day = dayRange.count
        guard let lastDay = calendar.date(from: lastComps) else { return nil }
        // El último día-semana del mes está a ≤ 6 días del final.
        for offset in 0...6 {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: lastDay) else { continue }
            if calendar.component(.weekday, from: d) == weekday {
                var comps = calendar.dateComponents([.year, .month, .day], from: d)
                comps.hour = payClock.hour
                comps.minute = payClock.minute
                comps.second = 0
                return calendar.date(from: comps)
            }
        }
        return nil
    }
}
