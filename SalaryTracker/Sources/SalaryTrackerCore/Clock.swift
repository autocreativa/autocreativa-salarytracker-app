import Foundation

/// Abstracción del tiempo (diseño D3). El motor nunca lee el reloj del sistema:
/// el instante se inyecta, lo que permite tests deterministas con fechas fijas.
public protocol Clock: Sendable {
    var now: Date { get }
}

/// Reloj real del sistema (producción).
public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}

/// Reloj manual para tests: instante fijo y controlable.
public struct ManualClock: Clock {
    public var date: Date
    public init(date: Date) {
        self.date = date
    }
    public var now: Date { date }
    public mutating func advance(by seconds: TimeInterval) {
        date.addTimeInterval(seconds)
    }
}
