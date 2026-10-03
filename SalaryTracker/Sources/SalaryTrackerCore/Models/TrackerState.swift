import Foundation

/// Vista de un período con todos los datos que la UI necesita (design.md D6).
/// El cálculo es numérico puro; el formateo textual es responsabilidad de la UI
/// (separación cálculo/presentación).
public struct PeriodView: Equatable, Sendable {
    /// Inicio del período (instante absoluto).
    public var start: Date
    /// Fin del período (próximo pago). `nil` solo en período abierto.
    public var end: Date?
    /// Sueldo total del período.
    public var salary: Decimal
    /// Código ISO de moneda (presentación).
    public var currencyCode: String
    /// Dinero ganado (acotado a [0, salary]).
    public var earned: Decimal
    /// Progreso del período en [0, 1].
    public var progress: Double
    /// Segundos restantes hasta el fin del período (`nil` si abierto).
    public var remainingSeconds: TimeInterval?
    /// Total ganado desde el inicio del contrato hasta ahora:
    /// `períodos completos × sueldo + ganado actual` (specs/period-engine
    /// "Total ganado acumulado"). El primer período cuenta aunque sea corto
    /// (cada período paga el sueldo completo al terminar).
    public var totalEarned: Decimal = 0

    public var isEnded: Bool { end == nil }
}

/// Estados posibles del tracker (specs: period-engine "Estados del motor",
/// configuration "Reconstrucción del estado al iniciar").
/// La transición entre estados ocurre exclusivamente al re-evaluar (≤ 1 s).
public enum TrackerState: Equatable, Sendable {
    /// Sin configuración persistida (primera ejecución).
    case notConfigured
    /// Configuración inválida (sueldo no positivo, pago anterior al inicio, etc).
    case invalid(reason: String)
    /// El inicio del contrato está en el futuro: dinero ganado = 0.
    case futureStart(startsAt: Date, firstPayment: Date?, salary: Decimal, currencyCode: String)
    /// Período en curso.
    case active(PeriodView)
    /// Período abierto (regla de fecha única agotada): sueldo completo ganado.
    case openEnded(PeriodView)

    /// Dinero ganado en la unidad numérica del estado (0 en futureStart/notConfigured).
    public var earned: Decimal {
        switch self {
        case .notConfigured: return 0
        case .invalid: return 0
        case .futureStart: return 0
        case .active(let v), .openEnded(let v): return v.earned
        }
    }

    /// Progreso en [0, 1] (0 en futureStart/notConfigured/invalid; 1 en openEnded).
    public var progress: Double {
        switch self {
        case .notConfigured, .invalid, .futureStart: return 0
        case .active(let v), .openEnded(let v): return v.progress
        }
    }

    /// Código de moneda vigente (para presentar valores), si aplica.
    public var currencyCode: String? {
        switch self {
        case .notConfigured, .invalid: return nil
        case .futureStart(_, _, _, let code): return code
        case .active(let v), .openEnded(let v): return v.currencyCode
        }
    }

    /// Total ganado acumulado desde el inicio del contrato (0 en
    /// notConfigured/invalid/futureStart).
    public var totalEarned: Decimal {
        switch self {
        case .notConfigured, .invalid, .futureStart: return 0
        case .active(let v), .openEnded(let v): return v.totalEarned
        }
    }
}
