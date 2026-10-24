import Foundation

/// Superficie de cada kind de widget.
///
/// Los dos kinds son **visualmente idénticos** (misma vista: dinero
/// ganado, progreso y próximo pago) pero son widgets separados, cada uno
/// con su superficie: la barra superior (Control Center) y el centro de
/// notificaciones (panel del reloj). La activación la controla un toggle
/// **por superficie** (`WidgetState.menuBar` / `WidgetState.
/// notificationCenter`).
public enum WidgetStyle: Sendable {
    /// «SalaryTracker»: barra superior (Control Center).
    case menuBar
    /// «SalaryTracker · Avance»: centro de notificaciones (panel del reloj).
    case notificationCenter

    /// Toggle de activación correspondiente a esta superficie.
    public func isEnabled(in state: WidgetState) -> Bool {
        switch self {
        case .menuBar:             return state.menuBar
        case .notificationCenter:  return state.notificationCenter
        }
    }
}

/// Estados de mensaje (compartidos por los dos widgets; la vista los
/// resuelve a icono/título/detalle localizados).
public enum WidgetMessage: Equatable, Sendable {
    /// El inicio del contrato está en el futuro (fecha de inicio).
    case futureStart(startsAt: String)
    /// La app aún no tiene configuración guardada.
    case notConfigured
    /// La configuración guardada es inválida.
    case invalid
    /// El toggle de la superficie está OFF en Configuración: la vista
    /// intercepta este estado y pinta la tile transparente (widget
    /// ocultado de su lugar; ver `SalaryWidgetView` en la extensión).
    case disabled
}

/// Datos precomputados por el provider (las vistas no dependen del motor).
public struct SalaryWidgetData: Equatable, Sendable {

    public enum Status: Equatable, Sendable {
        /// Período en curso (o período abierto con sueldo completo).
        /// `progress` es el texto formateado; `progressValue` el ratio
        /// [0, 1] para la barra; `nextPayment` la fecha del próximo pago
        /// (texto formateado; `nil` en período abierto); `remaining` la
        /// cuenta atrás al próximo pago (texto formateado; `nil` en
        /// período abierto).
        case active(earned: String, progress: String, progressValue: Double,
                    nextPayment: String?, remaining: String?)
        /// Estado de mensaje (compartido por ambos widgets).
        case message(WidgetMessage)
    }

    public let status: Status

    public init(status: Status) {
        self.status = status
    }

    /// Muestra de galería (placeholder).
    public static let placeholder = SalaryWidgetData(
        status: .active(earned: "1.250.000", progress: "45,00 %", progressValue: 0.45,
                        nextPayment: nil, remaining: nil)
    )
}

/// Derivación pura de los datos de presentación del widget.
///
/// Vive en el core (y no en la extensión) para que el **gate de
/// superficie** —toggle OFF ⇒ todas las entradas del timeline son
/// `.message(.disabled)` ⇒ la vista oculta la tile— sea unit-testable sin
/// WidgetKit ni SwiftUI.
public enum WidgetDataMaker {

    /// Calcula los datos de presentación para `now` aplicando el toggle de
    /// la superficie. Re-deriva el estado del tracker para el instante de
    /// cada entrada (evaluación pura; `config`, `engine` y `state` se
    /// inyectan para no re-leer el disco en cada minuto).
    ///
    /// - Parameters:
    ///   - isEnabled: valor del toggle de la superficie (`WidgetStyle.
    ///     isEnabled(in:)`); `false` ⇒ `.message(.disabled)`.
    ///   - locale: locale de presentación coherente con `WidgetState.
    ///     language` (fechas y moneda).
    ///   - remainingDaysHoursTemplate / remainingHoursMinutesTemplate:
    ///     plantillas localizadas de la cuenta atrás
    ///     (`"%1$d d, %2$d h"` / `"%1$d h, %2$d min"`).
    public static func makeData(
        now: Date,
        config: SalaryConfig?,
        engine: TrackerEngine,
        state: WidgetState,
        isEnabled: Bool,
        locale: Locale,
        remainingDaysHoursTemplate: String,
        remainingHoursMinutesTemplate: String,
        calendar: Calendar = .gregorian(timeZone: .current)
    ) -> SalaryWidgetData {
        guard isEnabled else {
            return SalaryWidgetData(status: .message(.disabled))
        }
        let t = engine.state(config: config, now: now, calendar: calendar)
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
                ? remainingDaysHoursTemplate
                : remainingHoursMinutesTemplate
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
