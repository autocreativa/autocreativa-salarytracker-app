import XCTest
@testable import SalaryTrackerCore

/// Tests del cálculo proporcional (specs/period-engine "Cálculo proporcional"
/// y "Determinación del período actual").
final class CalculatorTests: XCTestCase {

    // MARK: - Período base

    func testPeriodWithinFirstMonth() {
        // 2026-09-10 09:00 → período [2026-09-01 09:00, 2026-09-25 09:00)
        let state = T.calculator.evaluateTest(config: T.baseConfig(), now: T.d(2026, 9, 10, 9))
        let v = try? XCTUnwrap(state.activeView)
        XCTAssertNotNil(v)
        XCTAssertEqual(v?.start, T.d(2026, 9, 1, 9))
        XCTAssertEqual(v?.end, T.d(2026, 9, 25, 9))
        XCTAssertEqual(v?.salary, 1_500_000)
    }

    func testFirstPaymentStrictlyAfterStart() {
        // Inicio 2026-09-25 09:00 (momento de pago) → período hasta 2026-10-30 09:00
        let config = T.baseConfig(start: LocalDate(year: 2026, month: 9, day: 25))
        let state = T.calculator.evaluateTest(config: config, now: T.d(2026, 9, 26, 10))
        let v = try? XCTUnwrap(state.activeView)
        XCTAssertEqual(v?.start, T.d(2026, 9, 25, 9))
        XCTAssertEqual(v?.end, T.d(2026, 10, 30, 9))
    }

    func testPeriodCrossesMonthBoundary() {
        // Período [2026-09-25, 2026-10-30): duración exacta = 35 días reales
        let config = T.baseConfig(start: LocalDate(year: 2026, month: 9, day: 25))
        let state = T.calculator.evaluateTest(config: config, now: T.d(2026, 10, 15, 12))
        let v = try? XCTUnwrap(state.activeView)
        let duration = v?.end!.timeIntervalSince(v!.start)
        XCTAssertEqual(duration, 35 * 86_400)
    }

    func testPeriodCrossesYearBoundary() {
        // Período [2026-12-25 09:00, 2027-01-29 09:00)
        let config = T.baseConfig(start: LocalDate(year: 2026, month: 12, day: 25))
        let state = T.calculator.evaluateTest(config: config, now: T.d(2027, 1, 5, 10))
        let v = try? XCTUnwrap(state.activeView)
        XCTAssertEqual(v?.start, T.d(2026, 12, 25, 9))
        XCTAssertEqual(v?.end, T.d(2027, 1, 29, 9))
    }

    // MARK: - Cálculo proporcional

    func testExactMidpoint() throws {
        // Punto medio de [2026-09-01 09:00, 2026-09-25 09:00) = 2026-09-13 09:00
        let state = T.calculator.evaluateTest(config: T.baseConfig(), now: T.d(2026, 9, 13, 9))
        let v = try XCTUnwrap(state.activeView)
        XCTAssertEqual(dv(v.earned), 750_000.0, accuracy: 0.001)
        XCTAssertEqual(v.progress, 0.5, accuracy: 1e-9)
    }

    func testPeriodStartInstant() throws {
        let state = T.calculator.evaluateTest(config: T.baseConfig(), now: T.d(2026, 9, 1, 9))
        let v = try XCTUnwrap(state.activeView)
        XCTAssertEqual(dv(v.earned), 0, accuracy: 0.0001)
        XCTAssertEqual(v.progress, 0, accuracy: 1e-12)
    }

    func testOneSecondBeforePayment() {
        let start = T.d(2026, 9, 1, 9)
        let end = T.d(2026, 9, 25, 9)
        let t1 = T.calculator.evaluateTest(config: T.baseConfig(), now: end.addingTimeInterval(-1)).activeView!
        let t2 = T.calculator.evaluateTest(config: T.baseConfig(), now: end.addingTimeInterval(-2)).activeView!
        _ = start
        XCTAssertLessThan(t1.earned, 1_500_000)
        XCTAssertGreaterThan(t1.earned, t2.earned)
        // Δ ≈ 1 500 000 / (24 días) por segundo
        let expectedDelta = 1_500_000.0 / (24 * 86_400.0)
        XCTAssertEqual(dv(t1.earned - t2.earned), expectedDelta, accuracy: 0.001)
    }

    func testGrowthPerSecond() {
        // Período de exactamente 30 días: inicio 2026-09-01 09:00, regla "día 1"
        // → pago 2026-10-01 09:00 (30 días reales).
        // Δ/s = 1 500 000 / (30 × 86400) ≈ 0.5787037 (spec "Crecimiento segundo a segundo").
        let config = T.baseConfig(start: LocalDate(year: 2026, month: 9, day: 1),
                                  rule: .monthDay(day: 1))
        let v0 = T.calculator.evaluateTest(config: config, now: T.d(2026, 9, 1, 9)).activeView!
        XCTAssertEqual(v0.end, T.d(2026, 10, 1, 9))
        let t1 = T.d(2026, 9, 15, 12)
        let s1 = T.calculator.evaluateTest(config: config, now: t1).activeView!
        let s2 = T.calculator.evaluateTest(config: config, now: t1.addingTimeInterval(1)).activeView!
        let expectedDelta = 1_500_000.0 / (30 * 86_400.0)
        XCTAssertEqual(dv(s2.earned - s1.earned), expectedDelta, accuracy: 1e-6)
        XCTAssertEqual(expectedDelta, 0.5787037, accuracy: 1e-6)
    }

    func testEarnedNeverExceedsSalary() {
        let start = T.d(2026, 9, 1, 9)
        let end = T.d(2026, 9, 25, 9)
        for offset in [0.0, 1.0, 3_600, 86_399, 86_400.5] {
            let now = end.addingTimeInterval(-offset)
            _ = start
            let v = T.calculator.evaluateTest(config: T.baseConfig(), now: now).activeView!
            XCTAssertGreaterThanOrEqual(v.earned, 0)
            XCTAssertLessThanOrEqual(v.earned, 1_500_000)
        }
    }

    // MARK: - Total ganado acumulado (specs/period-engine "Total ganado acumulado")

    func testTotalEarnedFirstPeriodEqualsEarned() {
        // Período 1 en curso (aún sin pagos completados): total == ganado.
        let v = T.calculator.evaluateTest(config: T.baseConfig(), now: T.d(2026, 9, 13, 9)).activeView!
        XCTAssertEqual(dv(v.totalEarned), dv(v.earned), accuracy: 1e-9)
        XCTAssertEqual(dv(v.totalEarned), 750_000.0, accuracy: 0.001)
    }

    func testTotalEarnedAtExactRolloverIsOneSalary() {
        // now == momento de pago 2026-09-25 09:00: el período 1 se completó
        // justo en ese instante; el nuevo período arranca con 0 ganado.
        let v = T.calculator.evaluateTest(config: T.baseConfig(), now: T.d(2026, 9, 25, 9)).activeView!
        XCTAssertEqual(v.start, T.d(2026, 9, 25, 9))
        XCTAssertEqual(dv(v.earned), 0, accuracy: 0.0001)
        XCTAssertEqual(dv(v.totalEarned), 1_500_000.0, accuracy: 0.001)
    }

    func testTotalEarnedSecondPeriod() {
        // now = 2026-10-01 09:00: 1 período completo (pago 25 sep) + 6/35 del
        // período [25 sep, 30 oct).
        let v = T.calculator.evaluateTest(config: T.baseConfig(), now: T.d(2026, 10, 1, 9)).activeView!
        let partial = 1_500_000.0 * (6.0 / 35.0)   // 257 142,857…
        XCTAssertEqual(dv(v.totalEarned), 1_500_000.0 + partial, accuracy: 0.01)
    }

    func testTotalEarnedMultipleCompletedPeriods() {
        // now = 2026-11-10 12:00: pagos completados 25 sep y 30 oct (2 × sueldo)
        // + 11 días del período [30 oct, 27 nov).
        let v = T.calculator.evaluateTest(config: T.baseConfig(), now: T.d(2026, 11, 10, 12)).activeView!
        XCTAssertEqual(v.start, T.d(2026, 10, 30, 9))
        XCTAssertEqual(v.end, T.d(2026, 11, 27, 9))
        let partial = 1_500_000.0 * ((11 * 86_400.0 + 3 * 3_600.0) / (28 * 86_400.0))
        XCTAssertEqual(dv(v.totalEarned), 3_000_000.0 + partial, accuracy: 0.01)
        // Invariantes: total ≥ ganado actual y total < próximo límite de pago
        // (3 sueldos completos + sueldo del período en curso).
        XCTAssertLessThanOrEqual(dv(v.earned), dv(v.totalEarned))
        XCTAssertLessThan(dv(v.totalEarned), 4_500_000.0)
    }

    func testTotalEarnedShortFirstPeriodCountsFullSalary() {
        // Primer período corto (inicio 25 sep, pago 30 oct = 35 d… uso inicio
        // 2026-09-20: primer pago 25 sep, solo 5 días): al completarse cuenta
        // el sueldo completo aunque el mes no se completó.
        let config = T.baseConfig(start: LocalDate(year: 2026, month: 9, day: 20))
        let v = T.calculator.evaluateTest(config: config, now: T.d(2026, 10, 1, 0)).activeView!
        XCTAssertEqual(v.start, T.d(2026, 9, 25, 9))
        XCTAssertEqual(dv(v.totalEarned), 1_500_000.0 + dv(v.earned), accuracy: 0.01)
    }

    func testTotalEarnedOpenEndedIsFullSalary() throws {
        // Fecha única 15 sep: tras pasarla, el único período se completó.
        let config = T.baseConfig(rule: .specificDate(LocalDate(year: 2026, month: 9, day: 15)))
        let state = T.calculator.evaluateTest(config: config, now: T.d(2026, 10, 1, 12))
        let v = try XCTUnwrap(state.openEndedView)
        XCTAssertEqual(dv(v.totalEarned), 1_500_000.0, accuracy: 0.001)
        XCTAssertEqual(dv(v.earned), 1_500_000.0, accuracy: 0.001)
    }

    func testTotalEarnedBeforeStartIsZero() {
        // FUTURE_START: nada ganado aún.
        let state = T.calculator.evaluateTest(config: T.baseConfig(), now: T.d(2026, 8, 15, 9))
        XCTAssertEqual(state.totalEarned, 0)
        XCTAssertEqual(state.earned, 0)
    }
}
