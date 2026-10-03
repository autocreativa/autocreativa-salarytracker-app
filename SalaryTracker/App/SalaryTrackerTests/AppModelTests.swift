import Foundation
import XCTest
import SalaryTrackerCore

/// Test de integración de `AppModel` con reloj inyectable (task 8.2).
///
/// Verifica el pipeline completo de la app SIN UI ni reloj real:
/// `ConfigStore (temp) + TrackerEngine + reloj manual → TrackerState`.
/// `AppModel` se compila directamente en este target (no app-hosted), de modo
/// que el test corre en un runner standalone, determinista y sin GUI.
@MainActor
final class AppModelTests: XCTestCase {

    /// Reloj de referencia: `ManualClock` es un struct (semántica de valor) y
    /// `AppModel` retiene una copia, por lo que se necesita un contenedor
    /// mutable por referencia para avanzar el instante tras la construcción.
    private final class TestClock: Clock, @unchecked Sendable {
        var date: Date
        init(date: Date) { self.date = date }
        var now: Date { date }
        func advance(by seconds: TimeInterval) { date.addTimeInterval(seconds) }
    }

    /// Fechas locales en la zona horaria actual del sistema: la misma que
    /// usa `AppModel.evaluateNow()` por defecto (`.gregorian(timeZone: .current)`),
    /// por lo que config y clock se resuelven en la misma zona (determinista).
    private func localDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d
        c.hour = h; c.minute = min; c.second = 0
        return Calendar.gregorian(timeZone: .current).date(from: c)!
    }

    private func makeStore() -> ConfigStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppModelTests-\(UUID().uuidString)", isDirectory: true)
        return ConfigStore(directory: dir)
    }

    private func makeModel(store: ConfigStore, clock: Clock) -> AppModel {
        AppModel(store: store, engine: TrackerEngine(), clock: clock)
    }

    private static func baseConfig(startYear: Int = 2026) -> SalaryConfig {
        SalaryConfig(salaryAmount: 1_500_000,
                     currencyCode: "CLP",
                     contractStart: LocalDate(year: startYear, month: 9, day: 1),
                     contractStartTime: LocalTime(hour: 9, minute: 0),
                     paymentRule: .lastFriday())
    }

    // MARK: - Casos

    func testFirstLaunchWithoutFileIsNotConfigured() {
        let store = makeStore()
        let clock = TestClock(date: localDate(2026, 9, 15, 12, 0))
        let model = makeModel(store: store, clock: clock)
        defer { model.stop() }

        XCTAssertEqual(model.state, .notConfigured)
        XCTAssertNil(model.config)
        XCTAssertNil(model.loadIssue)
    }

    func testSaveConfigYieldsActiveStateDerivedFromInjectedClock() {
        let store = makeStore()
        let clock = TestClock(date: localDate(2026, 9, 15, 9, 0))
        let model = makeModel(store: store, clock: clock)
        defer { model.stop() }

        model.save(Self.baseConfig())

        guard case .active(let view) = model.state else {
            return XCTFail("Estado esperado .active, fue \(model.state)")
        }
        // Período [01 Sep 09:00, 25 Sep 09:00): 15 Sep 09:00 está a la mitad.
        XCTAssertEqual(view.salary, 1_500_000)
        XCTAssertEqual(view.currencyCode, "CLP")
        XCTAssertGreaterThan(dv(view.earned), 0)
        XCTAssertLessThan(dv(view.earned), dv(view.salary))
        XCTAssertGreaterThan(view.progress, 0)
        XCTAssertLessThan(view.progress, 1)
        XCTAssertNotNil(view.end)
        XCTAssertGreaterThanOrEqual(view.remainingSeconds ?? -1, 0)

        // Determinismo: misma entrada (clock inyectado) → misma salida.
        model.evaluateNow()
        XCTAssertEqual(model.state, .active(view))

        // Avanzar el clock 1 día: el ganado crece monótonamente y el
        // tiempo restante decrece exactamente 1 día (aritmética absoluta).
        let earnedBefore = dv(view.earned)
        let remainingBefore = view.remainingSeconds ?? 0
        clock.advance(by: 86_400)
        model.evaluateNow()
        guard case .active(let after) = model.state else {
            return XCTFail("Estado esperado .active tras avanzar el clock, fue \(model.state)")
        }
        XCTAssertGreaterThan(dv(after.earned), earnedBefore,
                             "El ganado debe crecer al avanzar el reloj: \(earnedBefore) → \(dv(after.earned))")
        let remainingDelta = remainingBefore - (after.remainingSeconds ?? 0)
        XCTAssertEqual(remainingDelta, 86_400, accuracy: 1,
                       "El tiempo restante debe decrecer exactamente 1 día")
        XCTAssertLessThanOrEqual(dv(after.earned), dv(after.salary))
    }

    func testRolloverAfterPaymentYieldsNewPeriod() {
        let store = makeStore()
        // 14 Sep 09:00: período [01 Sep, 25 Sep).
        let clock = TestClock(date: localDate(2026, 9, 14, 9, 0))
        let model = makeModel(store: store, clock: clock)
        defer { model.stop() }

        model.save(Self.baseConfig())

        // Avanzar hasta 1 día DESPUÉS del pago (26 Sep 09:00): el período
        // debe haber rollover-eado a [25 Sep 09:00, 30 Oct 09:00) con el
        // ganado apenas iniciado (R-RECOVERY/R-MULTI).
        // 14 Sep 09:00 → 26 Sep 09:00 = 12 días.
        clock.advance(by: 12 * 86_400)
        model.evaluateNow()

        guard case .active(let view) = model.state else {
            return XCTFail("Estado esperado .active tras rollover, fue \(model.state)")
        }
        // El nuevo período ya no empieza el 01 Sep.
        let cal = Calendar.gregorian(timeZone: .current)
        let startDay = cal.component(.day, from: view.start)
        XCTAssertEqual(startDay, 25)
        // Apenas 1 día transcurrido de ~35: progreso muy bajo y positivo.
        XCTAssertGreaterThan(view.progress, 0)
        XCTAssertLessThan(view.progress, 0.1)
    }

    func testSaveInvalidConfigYieldsInvalidState() {
        let store = makeStore()
        let clock = TestClock(date: localDate(2026, 9, 15, 12, 0))
        let model = makeModel(store: store, clock: clock)
        defer { model.stop() }

        var bad = Self.baseConfig()
        bad.salaryAmount = 0
        model.save(bad)

        guard case .invalid = model.state else {
            return XCTFail("Estado esperado .invalid, fue \(model.state)")
        }
        XCTAssertEqual(model.state.earned, 0)
    }

    func testContractStartInFutureYieldsFutureStart() {
        let store = makeStore()
        let clock = TestClock(date: localDate(2026, 10, 1, 9, 0))
        let model = makeModel(store: store, clock: clock)
        defer { model.stop() }

        let future = Self.baseConfig(startYear: 2027)
        model.save(future)

        guard case .futureStart(let startsAt, let firstPayment, let salary, _) = model.state else {
            return XCTFail("Estado esperado .futureStart, fue \(model.state)")
        }
        XCTAssertEqual(startsAt, localDate(2027, 9, 1, 9, 0))
        XCTAssertGreaterThan(firstPayment ?? .distantPast, startsAt)
        XCTAssertEqual(salary, 1_500_000)
        XCTAssertEqual(model.state.earned, 0)
        XCTAssertEqual(model.state.progress, 0)
    }

    func testCorruptedFileYieldsInvalidStateWithoutCrash() {
        let store = makeStore()
        try? FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data("esto no es JSON válido".utf8).write(to: store.fileURL)
        let clock = TestClock(date: localDate(2026, 9, 15, 12, 0))
        let model = makeModel(store: store, clock: clock)
        defer { model.stop() }

        guard case .invalid = model.state else {
            return XCTFail("Estado esperado .invalid con archivo corrupto, fue \(model.state)")
        }
        XCTAssertNotNil(model.loadIssue)
    }

    func testReloadRestoresPersistedConfiguration() {
        let store = makeStore()
        let clock = TestClock(date: localDate(2026, 9, 15, 12, 0))

        let first = makeModel(store: store, clock: clock)
        first.save(Self.baseConfig())
        let savedState = first.state
        first.stop()

        // Nueva instancia (simula relanzar la app): reconstruye el estado
        // desde el archivo persistido (specs/configuration "Reconstrucción").
        let second = makeModel(store: store, clock: clock)
        defer { second.stop() }

        XCTAssertEqual(second.config, Self.baseConfig())
        XCTAssertEqual(second.state, savedState)
    }
}

/// Decimal → Double para asserts con valores (XCTest no acepta Decimal con accuracy).
private func dv(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
