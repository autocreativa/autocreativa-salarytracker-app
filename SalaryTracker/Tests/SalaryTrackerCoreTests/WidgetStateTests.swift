import XCTest
import Foundation
@testable import SalaryTrackerCore

/// Tests de persistencia del estado del widget (feature: widgets).
///
/// Schema v3: un toggle **por superficie** (`menuBar` / `notificationCenter`)
/// + idioma. Las migraciones v2 (switch maestro `enabled`) y v1 (toggles por
/// superficie) se resuelven en `load()`.
final class WidgetStateStoreTests: XCTestCase {

    private var dir: URL!
    private var store: WidgetStateStore!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("st-widget-tests-\(UUID().uuidString)", isDirectory: true)
        store = WidgetStateStore(directory: dir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        dir = nil
        store = nil
        super.tearDown()
    }

    private func writeJSON(_ json: String) throws {
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: store.fileURL)
    }

    // MARK: - v3 (actual)

    func testLoadMissingReturnsDefaultEnabled() {
        // Primera ejecución: sin archivo → ambos widgets activados.
        XCTAssertEqual(store.load(), .default)
        XCTAssertTrue(store.load().menuBar)
        XCTAssertTrue(store.load().notificationCenter)
    }

    func testSaveLoadRoundtrip() {
        let state = WidgetState(menuBar: false, notificationCenter: true,
                                language: "en")
        store.save(state)
        XCTAssertEqual(store.load(), state)
    }

    func testSaveWritesSchemaV3() throws {
        store.save(WidgetState(menuBar: false, notificationCenter: false))
        let data = try Data(contentsOf: store.fileURL)
        let obj = try JSONSerialization.jsonObject(
            with: data) as! [String: Any]
        XCTAssertEqual(obj["v"] as? Int, 3)
        let st = obj["state"] as! [String: Any]
        XCTAssertEqual(st["menuBar"] as? Bool, false)
        XCTAssertEqual(st["notificationCenter"] as? Bool, false)
    }

    func testCorruptedFileFallsBackToDefault() throws {
        try writeJSON("no soy JSON")
        XCTAssertEqual(store.load(), .default)
    }

    func testWrongSchemaVersionFallsBackToDefault() throws {
        try writeJSON(#"{"v": 99, "state": {"menuBar": false, "notificationCenter": true}}"#)
        XCTAssertEqual(store.load(), .default)
    }

    func testSaveCreatesDirectoryIfNeeded() {
        let nested = dir.appendingPathComponent("a/b", isDirectory: true)
        let s = WidgetStateStore(directory: nested)
        s.save(WidgetState(menuBar: false, notificationCenter: false))
        XCTAssertEqual(s.load(),
                       WidgetState(menuBar: false, notificationCenter: false))
    }

    // MARK: - Migración v2 (switch maestro)

    func testV2MigrationEnabledMigratesToBothOn() throws {
        try writeJSON(#"{"v": 2, "state": {"enabled": true}}"#)
        XCTAssertEqual(store.load(),
                       WidgetState(menuBar: true, notificationCenter: true,
                                   language: nil))
    }

    func testV2MigrationDisabledMigratesToBothOff() throws {
        // El switch maestro estaba OFF → ambos toggles OFF.
        try writeJSON(#"{"v": 2, "state": {"enabled": false}}"#)
        XCTAssertEqual(store.load(),
                       WidgetState(menuBar: false, notificationCenter: false,
                                   language: nil))
    }

    func testV2MigrationPreservesLanguage() throws {
        try writeJSON(#"{"v": 2, "state": {"enabled": true, "language": "pt-BR"}}"#)
        XCTAssertEqual(store.load(),
                       WidgetState(menuBar: true, notificationCenter: true,
                                   language: "pt-BR"))
    }

    // MARK: - Migración v1 (toggles por superficie)

    func testV1MigrationMapsSurfacesDirectly() throws {
        try writeJSON(#"{"v": 1, "state": {"menuBar": true, "notificationCenter": false}}"#)
        XCTAssertEqual(store.load(),
                       WidgetState(menuBar: true, notificationCenter: false,
                                   language: nil))
    }

    func testV1MigrationBothOff() throws {
        try writeJSON(#"{"v": 1, "state": {"menuBar": false, "notificationCenter": false}}"#)
        XCTAssertEqual(store.load(),
                       WidgetState(menuBar: false, notificationCenter: false,
                                   language: nil))
    }

    func testV1MigrationPreservesLanguage() throws {
        try writeJSON(#"{"v": 1, "state": {"menuBar": true, "notificationCenter": true, "language": "pt-BR"}}"#)
        XCTAssertEqual(store.load(),
                       WidgetState(menuBar: true, notificationCenter: true,
                                   language: "pt-BR"))
    }

    // MARK: - Limpieza

    func testRemoveDeletesFile() throws {
        store.save(WidgetState(menuBar: false, notificationCenter: false))
        store.remove()
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertEqual(store.load(), .default)
    }
}
