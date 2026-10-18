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

    func testLoadMissingReturnsDefaultBothEnabled() {
        // Primera ejecución: sin archivo → ambas ubicaciones activas.
        XCTAssertEqual(store.load(), .default)
        XCTAssertTrue(store.load().menuBar)
        XCTAssertTrue(store.load().notificationCenter)
    }

    func testSaveLoadRoundtrip() {
        let state = WidgetState(menuBar: false, notificationCenter: true)
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
        let json = Data(#"{"v": 99, "state": {"menuBar": true, "notificationCenter": true}}"#.utf8)
        try json.write(to: store.fileURL)
        XCTAssertEqual(store.load(), .default)
    }

    func testSaveCreatesDirectoryIfNeeded() {
        let nested = dir.appendingPathComponent("a/b", isDirectory: true)
        let s = WidgetStateStore(directory: nested)
        s.save(WidgetState(menuBar: true, notificationCenter: false))
        XCTAssertEqual(s.load(), WidgetState(menuBar: true, notificationCenter: false))
    }

    func testLegacyFileWithoutLanguageDecodesWithDefaults() throws {
        // Schema v1 anterior (sin la clave `language`): debe decodificar y
        // conservar los flags, con language == nil.
        let json = Data(#"{"v": 1, "state": {"menuBar": false, "notificationCenter": true}}"#.utf8)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try json.write(to: store.fileURL)
        let loaded = store.load()
        XCTAssertEqual(loaded, WidgetState(menuBar: false, notificationCenter: true, language: nil))
    }

    func testRemoveDeletesFile() throws {
        store.save(WidgetState(menuBar: false, notificationCenter: false))
        store.remove()
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertEqual(store.load(), .default)
    }
}
