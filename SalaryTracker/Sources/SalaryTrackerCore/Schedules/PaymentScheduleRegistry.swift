import Foundation

/// Mapea la regla declarada por el usuario a su implementación (design.md D5).
/// Agregar una nueva regla = nueva struct + nuevo case en `PaymentRule` +
/// entrada aquí, sin tocar el motor.
public enum PaymentScheduleRegistry {
    public static func schedule(for rule: PaymentRule) -> PaymentSchedule {
        switch rule {
        case .lastWeekdayOfMonth(let weekday):
            return LastWeekdayOfMonthSchedule(weekday: weekday)
        case .monthDay(let day):
            return MonthDaySchedule(day: day)
        case .specificDate(let date):
            return SpecificDateSchedule(date: date)
        }
    }
}
