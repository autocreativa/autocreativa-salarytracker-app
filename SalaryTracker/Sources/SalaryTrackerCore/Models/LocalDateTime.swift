import Foundation

/// Fecha local por componentes (regla R-TZ del proposal): se almacenan los
/// componentes de fecha locales y se resuelven contra la zona horaria vigente al
/// calcular. No se almacenan instantes absolutos, para que un cambio de zona
/// horaria del sistema re-derive el período consistentemente.
public struct LocalDate: Codable, Equatable, Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    /// - Precondition: `date` es una fecha gregoriana válida (el día debe existir
    ///   en el mes/año, p. ej. no 2027-02-30).
    public init(year: Int, month: Int, day: Int) {
        precondition((1...12).contains(month) && (1...31).contains(day),
                     "LocalDate inválida: \(year)-\(month)-\(day)")
        let cal = Self.gregorian()
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        // DateComponents con día inexistente (30 en feb) se normaliza al mes
        // siguiente; detectamos y rechazamos.
        let normalized = cal.date(from: comps)!
        let back = cal.dateComponents([.year, .month, .day], from: normalized)
        precondition(back.year == year && back.month == month && back.day == day,
                     "LocalDate inexistente en el calendario gregoriano: \(year)-\(month)-\(day)")
        self.year = year
        self.month = month
        self.day = day
    }

    public init?(date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Resuelve la fecha local al mediodía absoluto NO; resuelve a la hora dada
    /// (componentes locales) en la zona horaria del calendario.
    public func resolve(at time: LocalTime, calendar: Calendar) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = time.hour
        comps.minute = time.minute
        comps.second = 0
        return calendar.date(from: comps)!
    }

    /// Cantidad de días reales que tiene el mes (febrero corto/largo según bisiesto).
    public var daysInMonth: Int {
        Self.gregorian().range(of: .day, in: .month, for: resolve(at: LocalTime(hour: 0, minute: 0), calendar: Self.gregorian()))?.count ?? 0
    }

    /// Día de la semana (ISO-8601: 1 = lunes … 7 = domingo) del día local.
    public func isoWeekday(calendar: Calendar) -> Int {
        let d = resolve(at: LocalTime(hour: 12, minute: 0), calendar: calendar)
        return calendar.component(.weekday, from: d).isoToWeekday
    }

    static func gregorian() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }
}

/// Hora local por componentes (solo hora:minuto).
public struct LocalTime: Codable, Equatable, Hashable, Sendable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        precondition((0...23).contains(hour) && (0...59).contains(minute),
                     "LocalTime inválida: \(hour):\(minute)")
        self.hour = hour
        self.minute = minute
    }
}

extension Calendar {
    /// Calendario gregoriano con la zona horaria dada (resolución de fechas, D2).
    public static func gregorian(timeZone: TimeZone) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }
}

extension Int {
    /// Convierte weekday de Foundation (1 = domingo … 7 = sábado) al ISO-8601
    /// (1 = lunes … 7 = domingo).
    fileprivate var isoToWeekday: Int {
        self == 1 ? 7 : self - 1
    }
}
