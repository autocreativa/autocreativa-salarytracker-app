import Foundation

/// Regla de pago declarada por el usuario (design.md D2).
/// Codificable para persistencia; cada case mapea a una `PaymentSchedule`.
public enum PaymentRule: Codable, Equatable, Hashable, Sendable {
    /// Último día-semana de cada mes. `weekday` usa ISO-8601: 1 = lunes … 7 = domingo.
    /// v1: viernes (5).
    case lastWeekdayOfMonth(weekday: Int)
    /// Día fijo N de cada mes (1...31), con salto de mes cuando N no existe
    /// (regla R-SKIP).
    case monthDay(day: Int)
    /// Fecha única de pago (regla R-ONESHOT): tras ese momento el período queda
    /// abierto (`OPEN_ENDED`).
    case specificDate(LocalDate)

    public var isRecurring: Bool {
        switch self {
        case .lastWeekdayOfMonth, .monthDay: return true
        case .specificDate: return false
        }
    }

    public static func lastFriday() -> PaymentRule {
        .lastWeekdayOfMonth(weekday: 5)
    }
}

/// Configuración completa del tracker (specs/configuration "Modelo de configuración").
public struct SalaryConfig: Codable, Equatable, Hashable, Sendable {
    /// Monto total del período de pago (no un valor "mensual" fijo de 30 días).
    public var salaryAmount: Decimal
    /// Código ISO 4217 de la moneda (solo afecta presentación).
    public var currencyCode: String
    /// Fecha de inicio del contrato (componentes locales).
    public var contractStart: LocalDate
    /// Hora de inicio del contrato (componentes locales). También es la hora de
    /// referencia de todos los momentos de pago (regla R-PAYMENT-TIME).
    public var contractStartTime: LocalTime
    /// Regla de pago.
    public var paymentRule: PaymentRule

    public init(
        salaryAmount: Decimal,
        currencyCode: String,
        contractStart: LocalDate,
        contractStartTime: LocalTime,
        paymentRule: PaymentRule
    ) {
        self.salaryAmount = salaryAmount
        self.currencyCode = currencyCode
        self.contractStart = contractStart
        self.contractStartTime = contractStartTime
        self.paymentRule = paymentRule
    }

    /// Resuelve el inicio del contrato como instante absoluto en la zona horaria
    /// del calendario (R-TZ: componentes locales, zona actual al evaluar).
    public func contractStartDate(calendar: Calendar) -> Date {
        contractStart.resolve(at: contractStartTime, calendar: calendar)
    }
}
