import Foundation

/// Regla "fecha específica" (specs/payment-schedules "Fecha específica de pago"):
/// un único momento de pago. Tras ese momento no hay sucesores (devuelve `nil`)
/// y el período queda abierto (`OPEN_ENDED` en el motor, regla R-ONESHOT).
public struct SpecificDateSchedule: PaymentSchedule {
    public let date: LocalDate

    public init(date: LocalDate) {
        self.date = date
    }

    public var label: String {
        "Pago el \(date.formattedLong())"
    }

    public func nextPayment(after: Date, payClock: LocalTime, calendar: Calendar) -> Date? {
        let candidate = date.resolve(at: payClock, calendar: calendar)
        return candidate > after ? candidate : nil
    }
}

extension LocalDate {
    /// Formateo largo legible (p. ej. "25 de septiembre de 2026") con el locale
    /// del sistema, para etiquetas de la UI.
    public func formattedLong(calendar: Calendar = .gregorian(timeZone: .current),
                              locale: Locale = .current) -> String {
        let d = resolve(at: LocalTime(hour: 0, minute: 0), calendar: calendar)
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "d 'de' MMMM 'de' yyyy"
        return f.string(from: d)
    }
}
