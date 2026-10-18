import XCTest
import Foundation
@testable import SalaryTrackerCore

/// Tests de persistencia del estado del widget (feature: widgets).
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

    func testLoadMissingReturnsDefaultEnabled() {
        // Primera ejecución: sin archivo → widgets activados.
        XCTAssertEqual(store.load(), .default)
        XCTAssertTrue(store.load().enabled)
    }

    func testSaveLoadRoundtrip() {
        let state = WidgetState(enabled: false, language: "en")
        store.save(state)
        XCTAssertEqual(store.load(), state)
    }

    func testCorruptedFileFallsBackToDefault() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("no soy JSON".utf8).write(to: store.fileURL)
        XCTAssertEqual(store.load(), .default)
    }

    func testWrongSchemaVersionFallsBackToDefault() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let json = Data(#"{"v": 99, "state": {"enabled": true}}"#.utf8)
        try json.write(to: store.fileURL)
        XCTAssertEqual(store.load(), .default)
    }

    func testSaveCreatesDirectoryIfNeeded() {
        let nested = dir.appendingPathComponent("a/b", isDirectory: true)
        let s = WidgetStateStore(directory: nested)
        s.save(WidgetState(enabled: false))
        XCTAssertEqual(s.load(), WidgetState(enabled: false))
    }

    func testV1MigrationEitherSurfaceOnMigratesToEnabled() throws {
        // Schema v1 (toggles por superficie): si CUALQUIERA estaba activa,
        // los widgets se consideran activos.
        let json = Data(#"{"v": 1, "state": {"menuBar": false, "notificationCenter": true}}"#.utf8)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try json.write(to: store.fileURL)
        XCTAssertEqual(store.load(), WidgetState(enabled: true, language: nil))
    }

    func testV1MigrationBothOffMigratesToDisabled() throws {
        let json = Data(#"{"v": 1, "state": {"menuBar": false, "notificationCenter": false}}"#.utf8)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try json.write(to: store.fileURL)
        XCTAssertEqual(store.load(), WidgetState(enabled: false, language: nil))
    }

    func testV1MigrationPreservesLanguage() throws {
        let json = Data(#"{"v": 1, "state": {"menuBar": true, "notificationCenter": true, "language": "pt-BR"}}"#.utf8)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try json.write(to: store.fileURL)
        XCTAssertEqual(store.load(), WidgetState(enabled: true, language: "pt-BR"))
    }

    func testRemoveDeletesFile() throws {
        store.save(WidgetState(enabled: false))
        store.remove()
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertEqual(store.load(), .default)
    }
}
