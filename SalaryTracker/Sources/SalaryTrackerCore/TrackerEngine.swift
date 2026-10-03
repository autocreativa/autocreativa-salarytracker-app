import Foundation

/// Orquestación fina de la evaluación (design.md D7): único punto de
/// derivación del estado para la UI.
///
/// Aísla el caso "sin configuración" (`notConfigured`) de la evaluación del
/// motor, de modo que la app (y sus tests) consuman UN método:
/// `state(config:now:calendar:)`. El motor (`SalaryCalculator`) permanece puro;
/// esta clase no mantiene estado mutante ni lee el reloj (R-RECOVERY: todo se
/// re-deriva del instante).
public struct TrackerEngine: Sendable {

    private let calculator: SalaryCalculator

    public init(calculator: SalaryCalculator = SalaryCalculator()) {
        self.calculator = calculator
    }

    /// Deriva el estado para el instante `now` a partir de `config`.
    /// - Parameters:
    ///   - config: configuración vigente; `nil` → `.notConfigured`.
    ///   - now: instante de evaluación (inyectado; en producción lo aporta el
    ///     `SystemClock` del tick).
    ///   - calendar: gregoriano con la zona horaria vigente (R-TZ). Por defecto
    ///     `TimeZone.current`, de modo que un cambio de zona del sistema
    ///     re-deriva el período en la siguiente evaluación.
    public func state(
        config: SalaryConfig?,
        now: Date,
        calendar: Calendar = .gregorian(timeZone: .current)
    ) -> TrackerState {
        guard let config else { return .notConfigured }
        return calculator.evaluate(config: config, now: now, calendar: calendar)
    }
}
