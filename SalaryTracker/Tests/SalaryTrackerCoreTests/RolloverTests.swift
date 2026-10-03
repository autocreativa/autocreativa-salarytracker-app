import XCTest
@testable import SalaryTrackerCore

/// Tests de rollover (specs/period-engine "Rollover automático de período",
/// reglas R-RECOVERY y R-MULTI del proposal).
final class RolloverTests: XCTestCase {

    func testRolloverAtExactPaymentInstant() throws {
        // En 2026-09-25 09:00 exacto: período nuevo, 0 ganado.
        let state = T.calculator.evaluateTest(config: T.baseConfig(), now: T.d(2026, 9, 25, 9))
        let v = try XCTUnwrap(state.activeView)
        XCTAssertEqual(v.start, T.d(2026, 9, 25, 9))
        XCTAssertEqual(v.end, T.d(2026, 10, 30, 9))
        XCTAssertEqual(dv(v.earned), 0, accuracy: 0.0001)
        XCTAssertEqual(v.progress, 0, accuracy: 1e-12)
    }

    func testRolloverAfterPaymentAppReopenedOneDayLater() throws {
        // Reapertura 2026-09-26 09:00 → 1/35 del sueldo (período de 35 días).
        let state = T.calculator.evaluateTest(config: T.baseConfig(), now: T.d(2026, 9, 26, 9))
        let v = try XCTUnwrap(state.activeView)
        XCTAssertEqual(v.start, T.d(2026, 9, 25, 9))
        XCTAssertEqual(v.end, T.d(2026, 10, 30, 9))
        XCTAssertEqual(dv(v.earned), 1_500_000.0 / 35.0, accuracy: 0.01)
        XCTAssertEqual(v.progress, 1.0 / 35.0, accuracy: 1e-9)
    }

    func testMultiplePaymentsElapsedWhileClosed() throws {
        // Cerrada desde 2026-09-10 hasta 2026-11-10:
        // pagos transcurridos: 2026-09-25 y 2026-10-30.
        // Período actual: [2026-10-30 09:00, 2026-11-27 09:00).
        let state = T.calculator.evaluateTest(config: T.baseConfig(), now: T.d(2026, 11, 10, 9))
        let v = try XCTUnwrap(state.activeView)
        XCTAssertEqual(v.start, T.d(2026, 10, 30, 9))
        XCTAssertEqual(v.end, T.d(2026, 11, 27, 9))
        // 11 días transcurridos de 28 (30 oct → 27 nov)
        XCTAssertEqual(v.progress, 11.0 / 28.0, accuracy: 1e-9)
    }

    func testNoUnboundedAccumulationAfterPayment() throws {
        // 7 días posteriores al pago del período vigente → período nuevo.
        let state = T.calculator.evaluateTest(config: T.baseConfig(), now: T.d(2026, 10, 2, 9))
        let v = try XCTUnwrap(state.activeView)
        XCTAssertEqual(v.start, T.d(2026, 9, 25, 9))
        XCTAssertEqual(v.end, T.d(2026, 10, 30, 9))
        XCTAssertEqual(dv(v.earned), 7.0 / 35.0 * 1_500_000, accuracy: 0.01)
        XCTAssertLessThanOrEqual(v.earned, 1_500_000)
    }

    func testRolloverIsPureDerivation() throws {
        // Evaluar en 2027-06-15 (varios meses después del inicio).
        // Los momentos de pago son SOLO el último viernes de cada mes:
        // el último momento de pago ≤ ahora es 2027-05-28 09:00; el próximo
        // es 2027-06-25 09:00. Período actual: [2027-05-28, 2027-06-25).
        let state = T.calculator.evaluateTest(config: T.baseConfig(), now: T.d(2027, 6, 15, 12))
        let v = try XCTUnwrap(state.activeView)
        XCTAssertEqual(v.start, T.d(2027, 5, 28, 9))
        XCTAssertEqual(v.end, T.d(2027, 6, 25, 9))
        // 18 días y 3 h transcurridos (now 12:00) de 28 días (28 may 09:00 → 25 jun 09:00)
        XCTAssertEqual(v.progress, 18.125 / 28.0, accuracy: 1e-9)
    }

    func testEvaluationFarInFutureStaysBounded() {
        // 10 años después del inicio: la búsqueda debe acotarse (performance).
        let config = T.baseConfig(start: LocalDate(year: 2026, month: 9, day: 1))
        let now = T.d(2036, 9, 1, 9)
        let start = Date()
        let state = T.calculator.evaluateTest(config: config, now: now)
        let elapsed = Date().timeIntervalSince(start)
        let v = try? XCTUnwrap(state.activeView)
        XCTAssertEqual(v?.start, T.d(2036, 8, 29, 9)) // último viernes de ago-2036
        XCTAssertEqual(v?.end, T.d(2036, 9, 26, 9))   // último viernes de sep-2036
        XCTAssertLessThan(elapsed, 0.05, "la búsqueda de período debe ser < 50 ms")
    }
}
