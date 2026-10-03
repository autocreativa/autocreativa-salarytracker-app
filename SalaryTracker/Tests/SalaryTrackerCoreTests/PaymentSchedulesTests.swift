import XCTest
@testable import SalaryTrackerCore

/// Tests de las reglas de pago (specs/payment-schedules).
final class PaymentSchedulesTests: XCTestCase {

    // MARK: - Último día-semana del mes

    func testLastFridaySeptember2026() {
        let s = LastWeekdayOfMonthSchedule(weekday: 5)
        // "El próximo pago después de 2026-09-10 10:00" → 2026-09-25 09:00
        let result = s.nextPayment(after: T.d(2026, 9, 10, 10),
                                   payClock: LocalTime(hour: 9, minute: 0),
                                   calendar: T.calendar)
        XCTAssertEqual(result, T.d(2026, 9, 25, 9))
    }

    func testLastFridayMonthWithFourFridays() {
        // septiembre 2026: 4 viernes (4, 11, 18, 25) → último es 25
        let s = LastWeekdayOfMonthSchedule(weekday: 5)
        let result = s.nextPayment(after: T.d(2026, 8, 31),
                                   payClock: LocalTime(hour: 9, minute: 0),
                                   calendar: T.calendar)
        XCTAssertEqual(result, T.d(2026, 9, 25, 9))
    }

    func testLastFridayMonthWithFiveFridays() {
        // octubre 2026: 5 viernes (2, 9, 16, 23, 30) → último es 30
        let s = LastWeekdayOfMonthSchedule(weekday: 5)
        let result = s.nextPayment(after: T.d(2026, 9, 30),
                                   payClock: LocalTime(hour: 9, minute: 0),
                                   calendar: T.calendar)
        XCTAssertEqual(result, T.d(2026, 10, 30, 9))
    }

    func testLastFebruaryShortYear() {
        // febrero 2027 (28 días): viernes 5, 12, 19, 26 → último es 26
        let s = LastWeekdayOfMonthSchedule(weekday: 5)
        let result = s.nextPayment(after: T.d(2027, 1, 31),
                                   payClock: LocalTime(hour: 9, minute: 0),
                                   calendar: T.calendar)
        XCTAssertEqual(result, T.d(2027, 2, 26, 9))
    }

    func testLastFebruaryLeapYear() {
        // febrero 2028 (29 días, bisiesto): viernes 4, 11, 18, 25 → último es 25
        let s = LastWeekdayOfMonthSchedule(weekday: 5)
        let result = s.nextPayment(after: T.d(2028, 1, 31),
                                   payClock: LocalTime(hour: 9, minute: 0),
                                   calendar: T.calendar)
        XCTAssertEqual(result, T.d(2028, 2, 25, 9))
    }

    func testSuccessionCrossesYearBoundary() {
        // diciembre 2026 → enero 2027 sin discontinuidad
        let s = LastWeekdayOfMonthSchedule(weekday: 5)
        let p1 = s.nextPayment(after: T.d(2026, 12, 10),
                               payClock: LocalTime(hour: 9, minute: 0),
                               calendar: T.calendar)
        let p2 = s.nextPayment(after: p1!,
                               payClock: LocalTime(hour: 9, minute: 0),
                               calendar: T.calendar)
        XCTAssertEqual(p1, T.d(2026, 12, 25, 9))
        XCTAssertEqual(p2, T.d(2027, 1, 29, 9))
    }

    func testStrictnessWhenQueryMatchesPaymentMoment() {
        // Consulta que coincide con un momento de pago → devuelve el siguiente.
        let s = LastWeekdayOfMonthSchedule(weekday: 5)
        let result = s.nextPayment(after: T.d(2026, 9, 25, 9),
                                   payClock: LocalTime(hour: 9, minute: 0),
                                   calendar: T.calendar)
        XCTAssertEqual(result, T.d(2026, 10, 30, 9))
    }

    func testStrictnessOneSecondBeforePayment() {
        let s = LastWeekdayOfMonthSchedule(weekday: 5)
        let result = s.nextPayment(after: T.d(2026, 9, 25, 8, 59, 59),
                                   payClock: LocalTime(hour: 9, minute: 0),
                                   calendar: T.calendar)
        XCTAssertEqual(result, T.d(2026, 9, 25, 9))
    }

    // MARK: - Día fijo del mes

    func testMonthDayNormal() {
        // "día 25 de cada mes", consulta 2026-09-01 00:00 → 2026-09-25 09:00
        let s = MonthDaySchedule(day: 25)
        let result = s.nextPayment(after: T.d(2026, 9, 1),
                                   payClock: LocalTime(hour: 9, minute: 0),
                                   calendar: T.calendar)
        XCTAssertEqual(result, T.d(2026, 9, 25, 9))
    }

    func testMonthDay31SkipsShortMonths() {
        // R-SKIP: septiembre 2026 (30 días) se salta.
        let s = MonthDaySchedule(day: 31)
        let cursor = T.d(2026, 9, 1)
        let p1 = s.nextPayment(after: cursor, payClock: LocalTime(hour: 9, minute: 0), calendar: T.calendar)!
        let p2 = s.nextPayment(after: p1, payClock: LocalTime(hour: 9, minute: 0), calendar: T.calendar)!
        let p3 = s.nextPayment(after: p2, payClock: LocalTime(hour: 9, minute: 0), calendar: T.calendar)!
        let p4 = s.nextPayment(after: p3, payClock: LocalTime(hour: 9, minute: 0), calendar: T.calendar)!
        XCTAssertEqual(p1, T.d(2026, 10, 31, 9))
        XCTAssertEqual(p2, T.d(2026, 12, 31, 9)) // noviembre (30) se salta
        XCTAssertEqual(p3, T.d(2027, 1, 31, 9))
        XCTAssertEqual(p4, T.d(2027, 3, 31, 9))  // febrero (28) se salta
    }

    func testMonthDay30SkipsFebruary() {
        let s = MonthDaySchedule(day: 30)
        let p1 = s.nextPayment(after: T.d(2027, 1, 15),
                               payClock: LocalTime(hour: 9, minute: 0),
                               calendar: T.calendar)
        let p2 = s.nextPayment(after: p1!,
                               payClock: LocalTime(hour: 9, minute: 0),
                               calendar: T.calendar)
        XCTAssertEqual(p1, T.d(2027, 1, 30, 9))
        XCTAssertEqual(p2, T.d(2027, 3, 30, 9)) // febrero 2027 (28 días) se omite
    }

    func testMonthDay29IncludesLeapFebruary() {
        let s = MonthDaySchedule(day: 29)
        // desde enero 2027: ene-29, feb-2027 no existe → mar-29... feb-2028 sí existe
        var cursor = T.d(2027, 1, 15)
        var payments: [Date] = []
        for _ in 0..<14 {
            let p = s.nextPayment(after: cursor,
                                  payClock: LocalTime(hour: 9, minute: 0),
                                  calendar: T.calendar)!
            payments.append(p)
            cursor = p
        }
        // debe contener 2028-02-29 y NO 2027-02-XX
        let comps: [(Int, Int)] = payments.map {
            let c = T.calendar.dateComponents([.year, .month, .day], from: $0)
            return (c.month!, c.day!)
        }
        XCTAssertTrue(comps.contains { $0 == (2, 29) })
        XCTAssertFalse(comps.contains { $0 == (2, 28) })
        let first = T.calendar.dateComponents([.year, .month, .day], from: payments.first!)
        XCTAssertEqual(first.year, 2027)
        XCTAssertEqual(first.month, 1)
        XCTAssertEqual(first.day, 29)
    }

    func testMonthDayQueryExactlyOnPayment() {
        // estrictidad: consulta el día 25 09:00 exacto → próximo es el siguiente mes
        let s = MonthDaySchedule(day: 25)
        let result = s.nextPayment(after: T.d(2026, 9, 25, 9),
                                   payClock: LocalTime(hour: 9, minute: 0),
                                   calendar: T.calendar)
        XCTAssertEqual(result, T.d(2026, 10, 25, 9))
    }

    // MARK: - Fecha específica

    func testSpecificDateReturnsItselfWhenFuture() {
        let s = SpecificDateSchedule(date: LocalDate(year: 2026, month: 10, day: 15))
        let result = s.nextPayment(after: T.d(2026, 9, 25, 9),
                                   payClock: LocalTime(hour: 9, minute: 0),
                                   calendar: T.calendar)
        XCTAssertEqual(result, T.d(2026, 10, 15, 9))
    }

    func testSpecificDateHasNoSuccessors() {
        let s = SpecificDateSchedule(date: LocalDate(year: 2026, month: 10, day: 15))
        // posterior a la fecha → nil (sin sucesores)
        let after = s.nextPayment(after: T.d(2026, 9, 25, 9),
                                  payClock: LocalTime(hour: 9, minute: 0),
                                  calendar: T.calendar)!
        let next = s.nextPayment(after: after,
                                 payClock: LocalTime(hour: 9, minute: 0),
                                 calendar: T.calendar)
        XCTAssertNil(next)
        // consulta igual a la fecha → nil (estricta)
        let same = s.nextPayment(after: T.d(2026, 10, 15, 9),
                                 payClock: LocalTime(hour: 9, minute: 0),
                                 calendar: T.calendar)
        XCTAssertNil(same)
    }

    // MARK: - Registry y etiquetas

    func testRegistryResolvesAllRules() {
        let r1 = PaymentScheduleRegistry.schedule(for: .lastFriday())
        XCTAssertTrue(r1 is LastWeekdayOfMonthSchedule)
        let r2 = PaymentScheduleRegistry.schedule(for: .monthDay(day: 25))
        XCTAssertTrue(r2 is MonthDaySchedule)
        let r3 = PaymentScheduleRegistry.schedule(for: .specificDate(LocalDate(year: 2026, month: 10, day: 15)))
        XCTAssertTrue(r3 is SpecificDateSchedule)
    }

    func testReadableLabels() {
        XCTAssertEqual(PaymentScheduleRegistry.schedule(for: .lastFriday()).label,
                       "Último viernes de cada mes")
        XCTAssertEqual(PaymentScheduleRegistry.schedule(for: .monthDay(day: 25)).label,
                       "Día 25 de cada mes")
        let label = PaymentScheduleRegistry.schedule(
            for: .specificDate(LocalDate(year: 2026, month: 10, day: 15))).label
        XCTAssertTrue(label.contains("15"))
    }
}
