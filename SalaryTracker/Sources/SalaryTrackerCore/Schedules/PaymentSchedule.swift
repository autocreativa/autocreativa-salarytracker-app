import Foundation

/// Abstracción de regla de pago (specs/payment-schedules "Abstracción de reglas").
/// Responsabilidades: generar el momento de pago estrictamente posterior a un
/// instante, y declarar su etiqueta legible para la UI.
///
/// Toda la resolución usa el calendario gregoriano (con su zona horaria); no hay
/// aritmética 7/30 ni supuestos de horas por día.
public protocol PaymentSchedule: Sendable {
    /// Primer momento de pago **estrictamente posterior** a `after`, a la hora de
    /// referencia `payClock`. Devuelve `nil` si la regla no tiene sucesores
    /// (regla de fecha única agotada).
    func nextPayment(after: Date, payClock: LocalTime, calendar: Calendar) -> Date?
    /// Etiqueta legible para la UI (p. ej. "Último viernes de cada mes").
    var label: String { get }
}

extension Int {
    /// ISO-8601 weekday (1 = lunes … 7 = domingo) → Foundation weekday
    /// (1 = domingo … 7 = sábado).
    var foundationWeekday: Int { self == 7 ? 1 : self + 1 }
}
