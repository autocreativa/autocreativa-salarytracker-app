import Foundation

/// Una moneda del catálogo (specs/currency-formatting "Catálogo de monedas").
public struct Currency: Equatable, Hashable, Codable, Sendable {
    /// Código ISO 4217 (p. ej. "CLP").
    public let code: String
    /// Símbolo de presentación (p. ej. "$", "€").
    public let symbol: String
    /// Decimales menores estándar (CLP/JPY: 0; USD/EUR: 2).
    public let minorUnitDecimals: Int
    /// Nombre localizado de referencia (locale es).
    public let name: String
}

/// Catálogo de monedas disponibles (specs/currency-formatting).
/// Lista fija y amplia; la lógica numérica del motor es independiente de la
/// moneda (R-CURRENCY del proposal).
public enum CurrencyCatalog {
    public static let all: [Currency] = [
        Currency(code: "CLP", symbol: "$", minorUnitDecimals: 0, name: "Peso chileno"),
        Currency(code: "USD", symbol: "$", minorUnitDecimals: 2, name: "Dólar estadounidense"),
        Currency(code: "EUR", symbol: "€", minorUnitDecimals: 2, name: "Euro"),
        Currency(code: "GBP", symbol: "£", minorUnitDecimals: 2, name: "Libra esterlina"),
        Currency(code: "ARS", symbol: "$", minorUnitDecimals: 2, name: "Peso argentino"),
        Currency(code: "BRL", symbol: "R$", minorUnitDecimals: 2, name: "Real brasileño"),
        Currency(code: "MXN", symbol: "$", minorUnitDecimals: 2, name: "Peso mexicano"),
        Currency(code: "JPY", symbol: "¥", minorUnitDecimals: 0, name: "Yen japonés"),
        Currency(code: "CAD", symbol: "$", minorUnitDecimals: 2, name: "Dólar canadiense"),
        Currency(code: "AUD", symbol: "$", minorUnitDecimals: 2, name: "Dólar australiano"),
        Currency(code: "CHF", symbol: "CHF", minorUnitDecimals: 2, name: "Franco suizo"),
        Currency(code: "CNY", symbol: "¥", minorUnitDecimals: 2, name: "Yuan chino"),
        Currency(code: "KRW", symbol: "₩", minorUnitDecimals: 0, name: "Won surcoreano"),
        Currency(code: "PLN", symbol: "zł", minorUnitDecimals: 2, name: "Zloty polaco"),
        Currency(code: "CZK", symbol: "Kč", minorUnitDecimals: 2, name: "Corona checa"),
        Currency(code: "SEK", symbol: "kr", minorUnitDecimals: 2, name: "Corona sueca"),
        Currency(code: "NOK", symbol: "kr", minorUnitDecimals: 2, name: "Corona noruega"),
        Currency(code: "DKK", symbol: "kr", minorUnitDecimals: 2, name: "Corona danesa"),
        Currency(code: "AED", symbol: "د.إ", minorUnitDecimals: 2, name: "Dirham de EAU"),
        Currency(code: "SGD", symbol: "S$", minorUnitDecimals: 2, name: "Dólar de Singapur"),
        Currency(code: "ZAR", symbol: "R", minorUnitDecimals: 2, name: "Rand sudafricano"),
        Currency(code: "COP", symbol: "$", minorUnitDecimals: 0, name: "Peso colombiano"),
        Currency(code: "PEN", symbol: "S/", minorUnitDecimals: 2, name: "Sol peruano"),
        Currency(code: "TRY", symbol: "₺", minorUnitDecimals: 2, name: "Lira turca")
    ]

    /// Busca una moneda por código ISO (case-insensitive).
    public static func currency(forCode code: String) -> Currency? {
        let normalized = code.uppercased()
        return all.first { $0.code == normalized }
    }

    /// Decimales menores estándar de una moneda (2 por defecto si es desconocida).
    public static func minorUnitDecimals(forCode code: String) -> Int {
        currency(forCode: code)?.minorUnitDecimals ?? 2
    }

    /// Símbolo de presentación (fallback: el propio código).
    public static func symbol(forCode code: String) -> String {
        currency(forCode: code)?.symbol ?? code.uppercased()
    }
}
