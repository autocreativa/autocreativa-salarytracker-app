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

/// Provider compartido de los dos kinds (reloj en vivo, cadencia 1 s).
///
/// **Estrategia de timeline en vivo**: `getTimeline` precalcula una entrada
/// por segundo para los próximos `liveSeconds` (5 min) y usa política
/// `.atEnd`; WidgetKit avanza por las entradas con el reloj, así el monto
/// ganado cambia **cada segundo** sin depender del presupuesto de recargas
/// (`reloadTimelines`/`.after(1 s)`): WidgetKit agrupa/limita esas
/// peticiones y el widget se quedaba congelado. Al agotarse el horizonte se
/// pide un timeline nuevo y el reloj sigue.
///
/// `style` marca la superficie declarada del kind; la activación la
/// controla el switch «Centro de notificaciones» (`WidgetState.
/// notificationCenter`): OFF ⇒ `.message(.disabled)` ⇒ mensaje de
/// reactivación (nunca una tile en blanco).
struct SalaryTimelineProvider: TimelineProvider {

    /// Segundos de reloj precalculados por timeline (1 entrada por segundo).
    /// 5 min cubre de sobra una consulta del panel; el coste es trivial
    /// (cálculo aritmético, sin I/O por entrada).
    static let liveSeconds = 300

    let style: WidgetStyle

    /// Muestra de galería (solo previews/inspector; nunca en vivo): valor
    /// de muestra y superficie activa.
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

    /// Timeline de reloj vivo: una entrada por segundo + `.atEnd` (ver
    /// encabezado del provider). Se comparten config/estado/engine entre
    /// entradas (una sola lectura por timeline).
    func getTimeline(in context: Context, completion: @escaping (Timeline<SalaryEntry>) -> Void) {
        let now = Date()
        let config = (try? WidgetPaths.configStore.load()) ?? nil
        let widgetState = WidgetPaths.stateStore.load()
        let engine = TrackerEngine()
        let entries: [SalaryEntry] = (0..<Self.liveSeconds).map { offset in
            let date = now.addingTimeInterval(TimeInterval(offset))
            return SalaryEntry(
                date: date,
                data: makeData(now: date, config: config, engine: engine, state: widgetState)
            )
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// Calcula los datos de presentación para `now`, aplicando el toggle de
    /// widgets (`WidgetState.notificationCenter`).
    ///
    /// **Reparto de switches**: el switch «Barra superior» controla SOLO el
    /// chip de la app en la barra de menús (`AppModel.showMenuBarChip`); el
    /// switch «Centro de notificaciones» controla la tile del widget (los
    /// dos kinds: macOS coloca los widgets en el panel del reloj o en el
    /// escritorio, no realmente «en la barra superior»). Así, apagar el chip
    /// no hace desaparecer el widget ya colocado y cada switch tiene un
    /// efecto visible propio.
    ///
    /// La derivación pura vive en `WidgetDataMaker` (core); aquí solo se
    /// inyectan la localización (`L10nWidget`) y el estado del toggle.
    private func makeData(
        now: Date,
        config: SalaryConfig?,
        engine: TrackerEngine,
        state: WidgetState
    ) -> SalaryWidgetData {
        return WidgetDataMaker.makeData(
            now: now,
            config: config,
            engine: engine,
            state: state,
            isEnabled: state.notificationCenter,
            locale: L10nWidget.locale,
            remainingDaysHoursTemplate: L10nWidget.str("widget.remaining.daysHours"),
            remainingHoursMinutesTemplate: L10nWidget.str("widget.remaining.hoursMinutes")
        )
    }
}
