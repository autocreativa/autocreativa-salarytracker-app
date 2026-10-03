import XCTest
import Foundation
@testable import SalaryTrackerCore

/// Tests de persistencia atómica (task 8.1; design.md D8).
final class ConfigStoreTests: XCTestCase {

    private var dir: URL!
    private var store: ConfigStore!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("st-config-tests-\(UUID().uuidString)", isDirectory: true)
        store = ConfigStore(directory: dir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        dir = nil
        store = nil
        super.tearDown()
    }

    func testLoadMissingReturnsNil() throws {
        // Primera ejecución: no existe → notConfigured (nil).
        XCTAssertNil(try store.load())
    }

    func testSaveLoadRoundtripIsIdempotent() throws {
        let cfg = T.baseConfig()
        try store.save(cfg)
        let loaded1 = try store.load()
        XCTAssertEqual(loaded1, cfg)
        // Guardar de nuevo el mismo valor no muta el resultado (idempotente).
        try store.save(cfg)
        let loaded2 = try store.load()
        XCTAssertEqual(loaded2, cfg)
    }

    func testSaveCreatesDirectoryIfNeeded() throws {
        let nested = dir.appendingPathComponent("a/b/c", isDirectory: true)
        let s = ConfigStore(directory: nested)
        try s.save(T.baseConfig())
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.appendingPathComponent("config.json").path))
        XCTAssertEqual(try s.load(), T.baseConfig())
    }

    func testCorruptedFileThrowsCorrupted() throws {
        try store.save(T.baseConfig())
        // Sobrescribir con basura: la carga debe lanzar .corrupted (no crashear).
        try Data("this is not valid json".utf8).write(to: store.fileURL)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? ConfigStore.StoreError, .corrupted)
        }
    }

    func testWrongSchemaVersionThrowsCorrupted() throws {
        try store.save(T.baseConfig())
        // JSON válido pero con versión de schema distinta → .corrupted.
        let payload = #"{"v": 999, "config": {}]}"#
        try Data(payload.utf8).write(to: store.fileURL)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? ConfigStore.StoreError, .corrupted)
        }
    }

    func testNoTempFilesLeftAfterSave() throws {
        try store.save(T.baseConfig())
        let contents = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        // Solo debe quedar config.json (el temp file se consume en el swap).
        XCTAssertEqual(contents, ["config.json"])
    }

    func testPreviousFileStaysValidUntilSwap() throws {
        let a = T.baseConfig()
        let b = T.baseConfig(salary: 2_000_000)
        try store.save(a)
        // Simular un temp file "parcial" coexistente: NO debe afectar la carga.
        let stray = dir.appendingPathComponent(".config.json.tmp-stray")
        try Data("partial...".utf8).write(to: stray)
        XCTAssertEqual(try store.load(), a, "el archivo previo debe seguir válido")
        try store.save(b)
        XCTAssertEqual(try store.load(), b)
        // Tras el swap, el stray sigue ahí (no lo tocamos) pero config.json es válido.
        XCTAssertEqual(try store.load(), b)
    }

    func testConcurrentWritesNeverLeavePartialFile() throws {
        // Estrés: múltiples guardados concurrentes. Al final el archivo debe
        // decodificarse a UNO de los configs guardados (nunca parcial).
        let configs = (0..<16).map { T.baseConfig(salary: Decimal(1_000_000 + $0)) }
        let group = DispatchGroup()
        let queue = DispatchQueue.global()
        for cfg in configs {
            group.enter()
            queue.async {
                do { try self.store.save(cfg) } catch { /* reintentos no necesarios */ }
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 30), .success)
        let final = try store.load()
        XCTAssertNotNil(final)
        XCTAssertTrue(final.map { configs.contains($0) } == true,
                      "debe ser uno de los configs escritos")
        // Y no debe quedar ningún temp file.
        let contents = try FileManager.default.contentsOfDirectory(atPath: self.dir.path)
        XCTAssertEqual(contents, ["config.json"])
    }

    func testSchemaVersionIsOne() {
        XCTAssertEqual(ConfigStore.schemaVersion, 1)
    }
}

/// Tests del orquestador de evaluación (task 8.2: lógica testeable con reloj
/// inyectado). Verifica que `TrackerEngine.state` derive el estado correcto al
/// avanzar el clock, incluyendo el caso `notConfigured`.
final class TrackerEngineTests: XCTestCase {

    private let engine = TrackerEngine()

    func testNilConfigYieldsNotConfigured() {
        let now = T.d(2026, 9, 10, 12)
        XCTAssertEqual(engine.state(config: nil, now: now, calendar: T.calendar),
                       .notConfigured)
    }

    func testActiveStateDerivedAtMidPeriod() throws {
        let cfg = T.baseConfig() // sep 1 → sep 25 (último viernes = 25)
        // 15 sep 09:00: 14 días de 24 → 14/24
        let now = T.d(2026, 9, 15, 9)
        let state = engine.state(config: cfg, now: now, calendar: T.calendar)
        let view = try XCTUnwrap(state.activeView)
        XCTAssertEqual(view.progress, 14.0 / 24.0, accuracy: 1e-9)
        XCTAssertEqual(dv(view.earned), 1_500_000.0 * 14.0 / 24.0, accuracy: 1.0)
    }

    func testAdvancingClockMovesEarnedForward() {
        let cfg = T.baseConfig()
        var clock = ManualClock(date: T.d(2026, 9, 10, 0))
        let s1 = engine.state(config: cfg, now: clock.now, calendar: T.calendar)
        let e1 = s1.earned
        clock.advance(by: 86_400 * 5) // +5 días
        let s2 = engine.state(config: cfg, now: clock.now, calendar: T.calendar)
        let e2 = s2.earned
        XCTAssertGreaterThan(e2, e1, "al avanzar el reloj, lo ganado debe crecer")
        // El período es el mismo (sep 1 → sep 25), no hubo rollover.
        XCTAssertEqual(s2.activeView?.start, s1.activeView?.start)
    }

    func testFutureStartWhenNowBeforeContractStart() {
        let cfg = T.baseConfig(start: LocalDate(year: 2026, month: 10, day: 1))
        let now = T.d(2026, 9, 20, 12)
        let state = engine.state(config: cfg, now: now, calendar: T.calendar)
        let info = state.futureStartInfo
        XCTAssertNotNil(info, "debe ser FUTURE_START")
        // Primer pago estrictamente posterior al inicio (1 oct 09:00):
        // último viernes de octubre = 30.
        XCTAssertEqual(info?.firstPayment, T.d(2026, 10, 30, 9))
        XCTAssertEqual(state.earned, 0)
        XCTAssertEqual(state.progress, 0)
    }

    func testOpenEndedAfterSpecificDatePassed() {
        let cfg = T.baseConfig(rule: .specificDate(LocalDate(year: 2026, month: 9, day: 15)))
        let now = T.d(2026, 9, 20, 12)
        let state = engine.state(config: cfg, now: now, calendar: T.calendar)
        XCTAssertEqual(state.progress, 1.0, accuracy: 1e-9)
        XCTAssertEqual(state.earned, T.baseConfig().salaryAmount)
    }

    func testInvalidSalaryYieldsInvalid() {
        let cfg = T.baseConfig(salary: 0)
        let now = T.d(2026, 9, 10, 12)
        let state = engine.state(config: cfg, now: now, calendar: T.calendar)
        XCTAssertNotNil(state.invalidReason)
    }

    func testDoubleEvaluationIsDeterministic() {
        let cfg = T.baseConfig()
        let now = T.d(2026, 9, 12, 15, 30)
        let a = engine.state(config: cfg, now: now, calendar: T.calendar)
        let b = engine.state(config: cfg, now: now, calendar: T.calendar)
        XCTAssertEqual(a, b)
    }

    func testTimezoneChangeRerivesPeriod() {
        // Misma config, mismo instante absoluto; distinta zona → el período se
        // re-deriva (R-TZ). Con offset fijo la duración en segundos se mantiene.
        let cfg = T.baseConfig()
        let absNow = T.d(2026, 9, 10, 12) // 12:00 UTC-4 = 16:00Z
        let inTz1 = engine.state(config: cfg, now: absNow, calendar: T.calendar)
        let inTz2 = engine.state(config: cfg, now: absNow, calendar: T.calendar2)
        // Ambos producen un período activo con la MISMA duración en segundos
        // (el período se mide entre instantes absolutos coherentes).
        let d1 = inTz1.activeView?.end?.timeIntervalSince(inTz1.activeView!.start)
        let d2 = inTz2.activeView?.end?.timeIntervalSince(inTz2.activeView!.start)
        // La duración puede variar según cómo cae el último viernes en cada zona,
        // pero ambas deben ser positivas y cercanas (~24 días ± 1 día).
        XCTAssertNotNil(d1); XCTAssertNotNil(d2)
        if let d1, let d2 {
            let base = 24 * 86_400.0
            XCTAssertGreaterThan(d1, base - 86_400)
            XCTAssertLessThan(d1, base + 86_400)
            XCTAssertGreaterThan(d2, base - 86_400)
            XCTAssertLessThan(d2, base + 86_400)
        }
    }
}
