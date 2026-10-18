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

/// Variante de contenido de cada kind de widget.
///
/// En macOS 26 ambos kinds se colocan juntos en el mismo panel (Control
/// Center / Centro de Notificaciones unificados), por lo que se
/// diferencian por **contenido** (no por superficie) y la activación la
/// controla el switch maestro único `WidgetState.enabled`.
enum WidgetStyle: Sendable {
    /// «SalaryTracker»: dinero ganado (LCD), progreso y próximo pago.
    case main
    /// «SalaryTracker · Avance»: avance del período y cuenta atrás al
    /// próximo pago.
    case progress
}

/// Estados de mensaje (compartidos por los dos widgets; la vista los
/// resuelve a icono/título/detalle localizados).
enum WidgetMessage: Equatable, Sendable {
    /// El inicio del contrato está en el futuro (fecha de inicio).
    case futureStart(startsAt: String)
    /// La app aún no tiene configuración guardada.
    case notConfigured
    /// La configuración guardada es inválida.
    case invalid
    /// Los widgets están desactivados en Configuración (switch maestro).
    case disabled
}

/// Datos precomputados por el provider (las vistas no dependen del core).
struct SalaryWidgetData: Equatable, Sendable {

    enum Status: Equatable, Sendable {
        /// Período en curso (o período abierto con sueldo completo).
        /// `progress` es el texto formateado; `progressValue` el ratio
        /// [0, 1] para la barra; `remaining` la cuenta atrás al próximo
        /// pago (texto formateado; `nil` en período abierto).
        case active(earned: String, progress: String, progressValue: Double,
                    nextPayment: String?, remaining: String?)
        /// Estado de mensaje (compartido por ambos widgets).
        case message(WidgetMessage)
    }

    let status: Status

    /// Muestra de galería (placeholder).
    static let placeholder = SalaryWidgetData(
        status: .active(earned: "1.250.000", progress: "45,00 %", progressValue: 0.45,
                        nextPayment: nil, remaining: nil)
    )
}

/// Entrada de timeline.
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
/// `style` marca la variante de contenido (main/avance); la activación la
/// controla el switch maestro `WidgetState.enabled` (común a ambos kinds).
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

    /// Calcula los datos de presentación para `now`, aplicando el switch
    /// maestro. Re-deriva el estado del tracker para el instante de cada
    /// entrada (la evaluación es pura; `config`, `engine` y `state` se
    /// inyectan para no re-leer el disco en cada minuto).
    private func makeData(
        now: Date,
        config: SalaryConfig?,
        engine: TrackerEngine,
        state: WidgetState
    ) -> SalaryWidgetData {
        guard state.enabled else {
            return SalaryWidgetData(status: .message(.disabled))
        }
        let t = engine.state(config: config, now: now)
        let locale = L10nWidget.locale
        let dateFmt = DateFormatter()
        dateFmt.locale = locale
        dateFmt.dateStyle = .medium
        dateFmt.timeStyle = .none
        let dateText: (Date) -> String = { dateFmt.string(from: $0) }
        // Cuenta atrás al próximo pago: "d d, h h" (o "h h, m min" si
        // faltan menos de 24 h); `nil` en período abierto.
        let remainingText: (TimeInterval?) -> String? = { seconds in
            guard let s = seconds, s > 0 else { return nil }
            let totalMinutes = Int(s / 60)
            let days = totalMinutes / (24 * 60)
            let hours = (totalMinutes % (24 * 60)) / 60
            let minutes = totalMinutes % 60
            let template = days > 0
                ? L10nWidget.str("widget.remaining.daysHours")
                : L10nWidget.str("widget.remaining.hoursMinutes")
            return String(format: template, locale: locale, days, hours, minutes)
        }
        switch t {
        case .active(let view):
            return SalaryWidgetData(status: .active(
                earned: CurrencyFormatter.format(view.earned, code: view.currencyCode, locale: locale),
                progress: CurrencyFormatter.formatProgress(view.progress, locale: locale),
                progressValue: view.progress,
                nextPayment: view.end.map(dateText),
                remaining: remainingText(view.remainingSeconds)
            ))
        case .openEnded(let view):
            return SalaryWidgetData(status: .active(
                earned: CurrencyFormatter.format(view.earned, code: view.currencyCode, locale: locale),
                progress: CurrencyFormatter.formatProgress(view.progress, locale: locale),
                progressValue: view.progress,
                nextPayment: nil,
                remaining: nil
            ))
        case .futureStart(let startsAt, _, _, _):
            return SalaryWidgetData(
                status: .message(.futureStart(startsAt: dateText(startsAt))))
        case .notConfigured:
            return SalaryWidgetData(status: .message(.notConfigured))
        case .invalid:
            return SalaryWidgetData(status: .message(.invalid))
        }
    }
}
