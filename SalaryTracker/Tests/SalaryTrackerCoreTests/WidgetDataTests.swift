import Foundation
import XCTest
@testable import SalaryTrackerCore

/// Tests del gate de superficie del widget (toggle «ocultar/mostrar» de
/// Configuración): cuando el toggle de la superficie está OFF, TODAS las
/// entradas del timeline deben ser `.message(.disabled)` (la vista pinta la
/// tile transparente, es decir, el widget se oculta de su lugar); al
/// reactivarlo, las entradas vuelven a tener datos.
final class WidgetDataTests: XCTestCase {

    private let engine = TrackerEngine()
    private let locale = Locale(identifier: "es_CL")
    private let daysTemplate = "%1$d d, %2$d h"
    private let hoursTemplate = "%1$d h, %2$d min"

    /// 2026-09-10 (dentro del primer período: inicio 2026-09-01).
    private let now = T.d(2026, 9, 10, 12, 0, 0)

    private func make(_ state: WidgetState, isEnabled: Bool) -> SalaryWidgetData {
        WidgetDataMaker.makeData(
            now: now,
            config: T.baseConfig(),
            engine: engine,
            state: state,
            isEnabled: isEnabled,
            locale: locale,
            remainingDaysHoursTemplate: daysTemplate,
            remainingHoursMinutesTemplate: hoursTemplate,
            calendar: T.calendar
        )
    }

    // MARK: - Gate de superficie (el fix del «widget que no se ocultaba»)

    func testMenuSurfaceOffYieldsDisabledRegardlessOfConfig() {
        let state = WidgetState(menuBar: false, notificationCenter: true)
        var data = make(state, isEnabled: WidgetStyle.menuBar.isEnabled(in: state))
        XCTAssertEqual(data.status, .message(.disabled))

        // El toggle de la OTRA superficie no debe afectar a esta.
        data = make(state, isEnabled: WidgetStyle.notificationCenter.isEnabled(in: state))
        guard case .active(let _, let _, let progressValue, _, _) = data.status else {
            return XCTFail("con menuBar=true la vista debe tener datos, no \(data.status)")
        }
        XCTAssertGreaterThan(progressValue, 0)
        XCTAssertLessThanOrEqual(progressValue, 1)
    }

    func testNotificationCenterOffYieldsDisabled() {
        let state = WidgetState(menuBar: true, notificationCenter: false)
        let data = make(state, isEnabled: WidgetStyle.notificationCenter.isEnabled(in: state))
        XCTAssertEqual(data.status, .message(.disabled))

        // El widget de la barra sigue con datos.
        let menu = make(state, isEnabled: WidgetStyle.menuBar.isEnabled(in: state))
        if case .message = menu.status {
            XCTFail("menuBar=true debe tener datos, no .message")
        }
    }

    func testBothOffYieldsDisabledForBothSurfaces() {
        let state = WidgetState(menuBar: false, notificationCenter: false)
        for style in [WidgetStyle.menuBar, .notificationCenter] {
            let data = make(state, isEnabled: style.isEnabled(in: state))
            XCTAssertEqual(data.status, .message(.disabled),
                           "la superficie \(style) con toggle OFF debe estar desactivada")
        }
    }

    func testToggleOnRestoresData() {
        let off = WidgetState(menuBar: false, notificationCenter: true)
        XCTAssertEqual(make(off, isEnabled: WidgetStyle.menuBar.isEnabled(in: off)).status,
                       .message(.disabled))

        // El usuario re-activa el switch: el siguiente getTimeline ya trae
        // datos (mismo estado persistido, solo cambió `menuBar`).
        let on = WidgetState(menuBar: true, notificationCenter: true)
        let data = make(on, isEnabled: WidgetStyle.menuBar.isEnabled(in: on))
        guard case .active = data.status else {
            return XCTFail("toggle ON debe devolver .active, no \(data.status)")
        }
    }

    // MARK: - Comportamiento existente (regresión de la derivación)

    func testActivePeriodYieldsEarnedProgressAndNextPayment() {
        let data = make(WidgetState(menuBar: true, notificationCenter: true), isEnabled: true)
        guard case .active(let earned, let progress, let progressValue, let nextPayment, let remaining) = data.status
        else { return XCTFail("se esperaba .active, no \(data.status)") }
        XCTAssertFalse(earned.isEmpty)
        XCTAssertFalse(progress.isEmpty)
        XCTAssertGreaterThan(progressValue, 0)
        XCTAssertLessThan(progressValue, 1)
        XCTAssertNotNil(nextPayment)
        XCTAssertNotNil(remaining)
    }

    func testNoConfigYieldsNotConfiguredWhenEnabled() {
        let data = WidgetDataMaker.makeData(
            now: now, config: nil, engine: engine,
            state: WidgetState(menuBar: true, notificationCenter: true),
            isEnabled: true, locale: locale,
            remainingDaysHoursTemplate: daysTemplate,
            remainingHoursMinutesTemplate: hoursTemplate,
            calendar: T.calendar
        )
        XCTAssertEqual(data.status, .message(.notConfigured))
    }

    func testFutureStartYieldsFutureStartMessage() {
        let config = T.baseConfig(start: LocalDate(year: 2027, month: 1, day: 1))
        let nowBefore = T.d(2026, 12, 15, 12, 0, 0)
        let data = WidgetDataMaker.makeData(
            now: nowBefore, config: config, engine: engine,
            state: WidgetState(menuBar: true, notificationCenter: true),
            isEnabled: true, locale: locale,
            remainingDaysHoursTemplate: daysTemplate,
            remainingHoursMinutesTemplate: hoursTemplate,
            calendar: T.calendar
        )
        guard case .message(.futureStart(let startsAt)) = data.status else {
            return XCTFail("se esperaba .futureStart, no \(data.status)")
        }
        XCTAssertFalse(startsAt.isEmpty)
    }

    // MARK: - Wire-up del toggle (WidgetStyle ↔ WidgetState)

    func testStyleIsEnabledReadsItsOwnToggle() {
        XCTAssertEqual(WidgetStyle.menuBar.isEnabled(in: WidgetState(menuBar: true, notificationCenter: false)), true)
        XCTAssertEqual(WidgetStyle.menuBar.isEnabled(in: WidgetState(menuBar: false, notificationCenter: true)), false)
        XCTAssertEqual(WidgetStyle.notificationCenter.isEnabled(in: WidgetState(menuBar: true, notificationCenter: false)), false)
        XCTAssertEqual(WidgetStyle.notificationCenter.isEnabled(in: WidgetState(menuBar: false, notificationCenter: true)), true)
    }
}
