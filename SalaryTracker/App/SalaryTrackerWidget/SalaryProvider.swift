import WidgetKit
import SwiftUI
import Foundation
import SalaryTrackerCore

/// Localización de la extensión del widget.
///
/// La extensión tiene su **propio** dominio de UserDefaults, por lo que no
/// hereda el override de `AppleLanguages` que la app escribe en su dominio.
/// El idioma lo aporta `WidgetState.language` (escrito por la app al
/// cambiarlo) y se resuelve contra el bundle de localización de la propia
/// extensión. Sin `language` → idioma del sistema (comportamiento
/// estándar de `Bundle.main` en la extensión).
/// Ubicación del estado compartido con la app (sandbox).
///
/// La extensión corre **sandboxeada** (`SalaryTrackerWidget.entitlements`)
/// y no podría leer `~/Library/Application Support/` sin más; su excepción
/// `temporary-exception.files.home-relative-path.read-write` le concede
/// acceso a `~/Library/Application Support/SalaryTracker/`, donde la app
/// escribe `config.json` y `widget-state.json` (ver `SharedPaths`).
enum WidgetPaths {

    /// Directorio de estado compartido dentro del contenedor de grupo.
    static var directory: URL { SharedPaths.stateDirectory }

    static var configStore: ConfigStore { ConfigStore(directory: directory) }
    static var stateStore: WidgetStateStore { WidgetStateStore(directory: directory) }
}

enum L10nWidget {

    /// Bundle de localización según `WidgetState.language`.
    static var bundle: Bundle {
        let code = WidgetPaths.stateStore.load().language
        guard let code,
              let url = Bundle.main.url(forResource: code, withExtension: "lproj"),
              let bundle = Bundle(url: url)
        else {
            return .main
        }
        return bundle
    }

    /// String localizado (fallback: la clave misma).
    static func str(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Locale de presentación (fechas, monedas, porcentajes) coherente con
    /// `WidgetState.language` (`nil` → locale del sistema).
    static var locale: Locale {
        WidgetPaths.stateStore.load().language.map(Locale.init(identifier:)) ?? .current
    }
}

/// Entrada de timeline.
///
/// Nota: `WidgetStyle`, `WidgetMessage`, `SalaryWidgetData` y la derivación
/// pura (`WidgetDataMaker`) viven en `SalaryTrackerCore` (ver
/// `WidgetData.swift`), para que el gate de superficie (toggle OFF ⇒ tile
/// ocultada) sea unit-testable sin WidgetKit/SwiftUI.
struct SalaryEntry: TimelineEntry {
    let date: Date
    let data: SalaryWidgetData
}

/// Provider compartido de los dos kinds.
///
/// Estrategia de timeline: una entrada por minuto durante 60 minutos y
/// política `.after(última)`, de modo que WidgetKit vuelve a pedir timeline
/// al agotarse las entradas (~24 recargas/día por widget, dentro del
/// presupuesto). Si el inicio futuro del contrato o el fin del período caen
/// dentro del horizonte, se agrega una entrada de frontera en ese instante.
///
/// `style` marca la superficie del kind; la activación la controla el
/// toggle de esa superficie (`WidgetState.menuBar` / `WidgetState.
/// notificationCenter`).
struct SalaryTimelineProvider: TimelineProvider {

    let style: WidgetStyle

    func placeholder(in context: Context) -> SalaryEntry {
        .init(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SalaryEntry) -> Void) {
        let now = Date()
        if context.isPreview {
            completion(.init(date: now, data: .placeholder))
        } else {
            let config = (try? WidgetPaths.configStore.load()) ?? nil
            let state = WidgetPaths.stateStore.load()
            completion(.init(date: now, data: makeData(now: now, config: config, engine: TrackerEngine(), state: state)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SalaryEntry>) -> Void) {
        let now = Date()
        let config = (try? WidgetPaths.configStore.load()) ?? nil
        let widgetState = WidgetPaths.stateStore.load()
        // TEMP-DEBUG (diagnóstico; se eliminará): traza cada getTimeline
        // con el estado leído y el resultado de la primera entrada.
        let trace: [String: Any] = [
            "kind": style == .menuBar ? "SalaryTrackerMenuBar" : "SalaryTrackerNotificationCenter",
            "at": ISO8601DateFormatter().string(from: now),
            "readMenu": widgetState.menuBar,
            "readNC": widgetState.notificationCenter,
            "surfaceEnabled": style.isEnabled(in: widgetState),
            "first": makeData(now: now, config: config, engine: TrackerEngine(), state: widgetState).status == .message(.disabled) ? "disabled" : "data",
            "stateFile": WidgetPaths.stateStore.fileURL.lastPathComponent,
        ]
        if let d = try? JSONSerialization.data(withJSONObject: trace) {
            let url = WidgetPaths.directory.appendingPathComponent("widget-trace.json")
            let arr = (try? JSONSerialization.jsonObject(with: (try? Data(contentsOf: url)) ?? Data()) as? [[String: Any]]) ?? []
            try? JSONSerialization.data(withJSONObject: arr + [trace], options: [.prettyPrinted])
                .write(to: url)
        }
        let engine = TrackerEngine()
        // Detección de fronteras dentro del horizonte (con la config real).
        let stateNow = engine.state(config: config, now: now)
        var entries: [SalaryEntry] = []
        let minute: TimeInterval = 60
        let maxEntries = 60
        var t = now
        for _ in 0..<maxEntries {
            entries.append(.init(date: t, data: makeData(now: t, config: config, engine: engine, state: widgetState)))
            t.addTimeInterval(minute)
        }
        // Frontera: inicio futuro del contrato (dentro del horizonte).
        if case .futureStart(let start, _, _, _) = stateNow,
           start > now, start <= t {
            entries.append(.init(date: start, data: makeData(now: start, config: config, engine: engine, state: widgetState)))
        }
        // Frontera: fin del período activo (dentro del horizonte).
        if case .active(let view) = stateNow,
           let end = view.end, end > now, end <= t {
            entries.append(.init(date: end, data: makeData(now: end, config: config, engine: engine, state: widgetState)))
        }
        let sorted = entries.sorted { $0.date < $1.date }
        let last = sorted.last!.date
        completion(Timeline(entries: sorted, policy: .after(last)))
    }

    /// Calcula los datos de presentación para `now`, aplicando el toggle
    /// de la superficie de este kind. Si el toggle está OFF, todas las
    /// entradas del timeline son `.message(.disabled)` y la vista pinta la
    /// tile transparente (widget ocultado de su lugar).
    ///
    /// La derivación pura vive en `WidgetDataMaker` (core); aquí solo se
    /// inyectan la localización (`L10nWidget`) y el estado del toggle.
    private func makeData(
        now: Date,
        config: SalaryConfig?,
        engine: TrackerEngine,
        state: WidgetState
    ) -> SalaryWidgetData {
        WidgetDataMaker.makeData(
            now: now,
            config: config,
            engine: engine,
            state: state,
            isEnabled: style.isEnabled(in: state),
            locale: L10nWidget.locale,
            remainingDaysHoursTemplate: L10nWidget.str("widget.remaining.daysHours"),
            remainingHoursMinutesTemplate: L10nWidget.str("widget.remaining.hoursMinutes")
        )
    }
}
