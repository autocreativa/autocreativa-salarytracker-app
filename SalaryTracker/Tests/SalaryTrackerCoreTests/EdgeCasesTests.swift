import XCTest
@testable import SalaryTrackerCore

/// Tests de estados (specs/period-engine "Estados del motor",
/// specs/configuration "Reconstrucción del estado al iniciar") y de
/// invariancia (specs/period-engine "Independencia del reloj de la aplicación").
final class EdgeCasesTests: XCTestCase {

    // MARK: - FUTURE_START

    func testFutureStart() {
        // Inicio 2026-10-01 09:00, evaluación 2026-09-05 12:00.
        let config = T.baseConfig(start: LocalDate(year: 2026, month: 10, day: 1))
        let state = T.calculator.evaluateTest(config: config, now: T.d(2026, 9, 5, 12))
        let info = try? XCTUnwrap(state.futureStartInfo)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.startsAt, T.d(2026, 10, 1, 9))
        // próximo pago: primer momento de pago (último viernes) estricto posterior
        // al inicio (jue 2026-10-01) → 2026-10-30 09:00
        XCTAssertEqual(info?.firstPayment, T.d(2026, 10, 30, 9))
        XCTAssertEqual(state.earned, 0)
        XCTAssertEqual(state.progress, 0)
    }

    func testFutureStartBecomesActiveAfterStart() throws {
        let config = T.baseConfig(start: LocalDate(year: 2026, month: 10, day: 1))
        let justBefore = T.calculator.evaluateTest(config: config, now: T.d(2026, 10, 1, 8, 59, 59))
        XCTAssertNil(justBefore.activeView)
        let justAfter = T.calculator.evaluateTest(config: config, now: T.d(2026, 10, 1, 9, 0, 1))
        let v = try XCTUnwrap(justAfter.activeView)
        // 1 segundo transcurrido en un período de 29 días (01→30 oct):
        XCTAssertEqual(dv(v.earned), 1_500_000.0 / (29 * 86_400.0), accuracy: 0.001)
        // primer momento de pago estrictamente posterior al inicio (jue 2026-10-01):
        // último viernes de octubre = 2026-10-30
        XCTAssertEqual(v.end, T.d(2026, 10, 30, 9))
    }

    // MARK: - OPEN_ENDED

    func testOpenEndedAfterSpecificDate() {
        // Fecha específica 2026-09-25 09:00; evaluación 2026-10-01 09:00.
        let config = T.baseConfig(rule: .specificDate(LocalDate(year: 2026, month: 9, day: 25)))
        let state = T.calculator.evaluateTest(config: config, now: T.d(2026, 10, 1, 9))
        let v = try? XCTUnwrap(state.openEndedView)
        XCTAssertNotNil(v)
        XCTAssertEqual(v?.earned, 1_500_000)
        XCTAssertEqual(v?.progress, 1.0)
        XCTAssertNil(v?.end)
        XCTAssertNil(v?.remainingSeconds)
    }

    func testSpecificDateActiveBeforePayment() throws {
        let config = T.baseConfig(rule: .specificDate(LocalDate(year: 2026, month: 10, day: 15)))
        let state = T.calculator.evaluateTest(config: config, now: T.d(2026, 10, 1, 9))
        let v = try XCTUnwrap(state.activeView)
        XCTAssertEqual(v.start, T.d(2026, 9, 1, 9))
        XCTAssertEqual(v.end, T.d(2026, 10, 15, 9))
        // 30 días transcurridos de 44 (01 sep 09:00 → 15 oct 09:00)
        XCTAssertEqual(v.progress, 30.0 / 44.0, accuracy: 1e-9)
    }

    // MARK: - INVALID_CONFIGURATION

    func testInvalidZeroSalary() {
        let config = T.baseConfig(salary: 0)
        let state = T.calculator.evaluateTest(config: config, now: T.d(2026, 9, 15))
        XCTAssertNotNil(state.invalidReason)
    }

    func testInvalidNegativeSalary() {
        let config = T.baseConfig(salary: -100)
        let state = T.calculator.evaluateTest(config: config, now: T.d(2026, 9, 15))
        XCTAssertNotNil(state.invalidReason)
    }

    func testSpecificDateBeforeStartIsInvalid() {
        let config = T.baseConfig(start: LocalDate(year: 2026, month: 9, day: 25),
                                  rule: .specificDate(LocalDate(year: 2026, month: 9, day: 10)))
        let state = T.calculator.evaluateTest(config: config, now: T.d(2026, 9, 30))
        XCTAssertNotNil(state.invalidReason)
    }

    // MARK: - Invariancia / pureza

    func testSameInputSameOutput() {
        let now = T.d(2026, 9, 15, 12, 34, 56)
        let s1 = T.calculator.evaluateTest(config: T.baseConfig(), now: now)
        let s2 = T.calculator.evaluateTest(config: T.baseConfig(), now: now)
        XCTAssertEqual(s1, s2)
    }

    func testEarnedBoundedOverRandomInstants() {
        // Batería determinista (semilla fija) de instantes a lo largo de 3 años.
        var rng = SeededRandom(seed: 42)
        for _ in 0..<200 {
            let offset = Double(rng.next() % (3 * 365 * 86_400))
            let now = T.d(2026, 9, 1).addingTimeInterval(offset)
            let state = T.calculator.evaluateTest(config: T.baseConfig(), now: now)
            switch state {
            case .active(let v), .openEnded(let v):
                XCTAssertGreaterThanOrEqual(v.earned, 0)
                XCTAssertLessThanOrEqual(v.earned, 1_500_000)
                XCTAssertGreaterThanOrEqual(v.progress, 0)
                XCTAssertLessThanOrEqual(v.progress, 1)
            case .futureStart, .notConfigured:
                break
            case .invalid:
                XCTFail("no debería ser inválido")
            }
        }
    }

    // MARK: - Zona horaria (regla R-TZ)

    func testSameLocalComponentsDifferentTimeZones() {
        // 2026-09-01 09:00 en UTC-4 (= 13:00Z) vs en UTC+2 (= 07:00Z): mismos
        // componentes locales, instantes absolutos distintos (Δ de offsets = 6 h).
        let inTz1 = T.d(2026, 9, 1, 9)
        let cal2 = T.calendar2
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = 1; c.hour = 9; c.minute = 0; c.second = 0
        let inTz2 = cal2.date(from: c)!
        XCTAssertEqual(inTz1.timeIntervalSince(inTz2), 6 * 3600)
        // y al resolver localmente, cada uno da "09:00" en su zona:
        let local1 = T.calendar.dateComponents([.hour, .minute], from: inTz1)
        let local2 = cal2.dateComponents([.hour, .minute], from: inTz2)
        XCTAssertEqual(local1.hour, 9)
        XCTAssertEqual(local2.hour, 9)
    }

    func testPeriodDerivedWithRespectiveTimeZones() {
        // La misma configuración se re-deriva en la zona del calendario:
        // el período mantiene la misma fecha/hora local.
        let config = T.baseConfig()
        let now1 = T.d(2026, 9, 10, 9) // 13:00Z (UTC-4)
        let v1 = T.calculator.evaluateTest(config: config, now: now1, calendar: T.calendar).activeView!
        XCTAssertEqual(v1.start, T.d(2026, 9, 1, 9))

        // En UTC+2: el mismo instante local (2026-09-10 09:00 = 07:00Z).
        let cal2 = T.calendar2
        var c2 = DateComponents()
        c2.year = 2026; c2.month = 9; c2.day = 10; c2.hour = 9; c2.minute = 0; c2.second = 0
        let now2 = cal2.date(from: c2)!
        let v2 = T.calculator.evaluateTest(config: config, now: now2, calendar: cal2).activeView!
        var s2 = DateComponents()
        s2.year = 2026; s2.month = 9; s2.day = 1; s2.hour = 9; s2.minute = 0; s2.second = 0
        XCTAssertEqual(v2.start, cal2.date(from: s2)!)
        // misma duración de período (fechas locales iguales):
        XCTAssertEqual(v2.end!.timeIntervalSince(v2.start), v1.end!.timeIntervalSince(v1.start))
    }

    // MARK: - Medianoche y febrero

    func testCrossMidnightContinuesGrowth() {
        let t1 = T.d(2026, 9, 13, 23, 59, 59)
        let t2 = T.d(2026, 9, 14, 0, 0, 1)
        let s1 = T.calculator.evaluateTest(config: T.baseConfig(), now: t1).activeView!
        let s2 = T.calculator.evaluateTest(config: T.baseConfig(), now: t2).activeView!
        XCTAssertEqual(dv(s2.earned - s1.earned), 2.0 / (24 * 86_400.0) * 1_500_000, accuracy: 0.01)
    }

    func testFebruaryDurationDiffersExactlyOneDay() {
        // Período que abarca feb-2027 (28 días) vs feb-2028 (29 días) con día fijo 1.
        let rule: PaymentRule = .monthDay(day: 1)
        let c27 = T.baseConfig(start: LocalDate(year: 2027, month: 1, day: 1), rule: rule)
        let c28 = T.baseConfig(start: LocalDate(year: 2028, month: 1, day: 1), rule: rule)
        let v27 = T.calculator.evaluateTest(config: c27, now: T.d(2027, 1, 15)).activeView!
        let v28 = T.calculator.evaluateTest(config: c28, now: T.d(2028, 1, 15)).activeView!
        let d27 = v27.end!.timeIntervalSince(v27.start) // hasta feb-2027-01: 31 días
        let d28 = v28.end!.timeIntervalSince(v28.start) // hasta feb-2028-01: 31 días
        XCTAssertEqual(d27, 31 * 86_400)
        XCTAssertEqual(d28, 31 * 86_400)
        // y el período de feb-2028 dura un día más que el de feb-2027:
        let v27b = T.calculator.evaluateTest(config: c27, now: T.d(2027, 2, 15)).activeView!
        let v28b = T.calculator.evaluateTest(config: c28, now: T.d(2028, 2, 15)).activeView!
        XCTAssertEqual(v28b.end!.timeIntervalSince(v28b.start),
                       v27b.end!.timeIntervalSince(v27b.start) + 86_400)
    }
}

/// RNG determinista (LCG) para la batería de instantes.
struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 &+ 1 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
