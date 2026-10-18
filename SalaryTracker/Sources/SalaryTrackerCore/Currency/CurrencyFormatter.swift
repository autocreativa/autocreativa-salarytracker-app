import Foundation

/// Formateo de presentación de valores monetarios
/// (specs/currency-formatting "Formato numérico por moneda" y
/// "Redondeo de presentación").
///
/// Función pura de presentación: el motor de cálculo NUNCA usa este tipo
/// (separación cálculo/presentación, regla R-PRECISION del proposal).
public enum CurrencyFormatter {

    private static let cache: NSCache<NSString, NumberFormatter> = {
        let c = NSCache<NSString, NumberFormatter>()
        c.countLimit = 64
        return c
    }()

    /// Formatea `value` en la moneda `code` según el locale (por defecto, el del
    /// sistema) y los decimales estándar de la moneda.
    /// - Note: El redondeo es `halfUp` y es exclusivamente de presentación.
    public static func format(_ value: Decimal,
                              code: String,
                              locale: Locale = .current) -> String {
        let formatter = formatter(code: code, locale: locale)
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    /// Formatea un valor Double (p. ej. salidos de interpolación) con la misma
    /// política de presentación.
    public static func format(_ value: Double,
                              code: String,
                              locale: Locale = .current) -> String {
        format(Decimal(value), code: code, locale: locale)
    }

    /// Variante compacta para el indicador de Menu Bar: mismos decimales,
    /// redondeo y separadores que `format`, pero SIN el símbolo de moneda
    /// (el símbolo visual lo aporta el glifo de la barra; decisión de diseño
    /// 2026-10-03, specs/currency-formatting "Indicador compacto sin símbolo").
    public static func formatCompact(_ value: Decimal,
                                     code: String,
                                     locale: Locale = .current) -> String {
        let formatter = compactFormatter(code: code, locale: locale)
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    /// Sufijo de días por defecto (se mantiene neutro para no acoplar el core
    /// a un idioma; la UI lo reemplaza con su etiqueta localizable).
    public static let daysSuffix = "d"

    /// Formatea segundos restantes como "Dd HH:MM:SS" (popover, specs/menubar).
    /// - Note: Sin días se muestra "HH:MM:SS". El sufijo de días es un parámetro
    ///   (por defecto `daysSuffix`) para que la UI pueda localizarlo.
    public static func formatRemaining(_ seconds: TimeInterval,
                                       daysSuffix: String = daysSuffix) -> String {
        let total = Int(max(0, seconds).rounded())
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60
        if days > 0 {
            return String(format: "%d%@ %02d:%02d:%02d", days, daysSuffix, hours, minutes, secs)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    /// Porcentaje de progreso con 2 decimales (p. ej. "67.42 %").
    /// - Parameter locale: locale de presentación (por defecto, el del sistema).
    public static func formatProgress(_ ratio: Double,
                                      locale: Locale = .current) -> String {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.locale = locale
        return f.string(from: NSNumber(value: ratio)) ?? ""
    }

    private static func formatter(code: String, locale: Locale) -> NumberFormatter {
        let key = "\(code)|\(locale.identifier)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = locale
        let normalized = code.uppercased()
        if CurrencyCatalog.currency(forCode: normalized) != nil {
            f.currencyCode = normalized
        } else {
            // Moneda fuera de catálogo: NumberFormatter emitiría el símbolo
            // genérico "¤". Mostramos el código ISO como símbolo.
            f.currencyCode = nil
            f.currencySymbol = normalized
        }
        let decimals = CurrencyCatalog.minorUnitDecimals(forCode: normalized)
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        f.roundingMode = .halfUp
        f.usesGroupingSeparator = true
        cache.setObject(f, forKey: key)
        return f
    }

    /// Como `formatter`, pero con estilo decimal (sin símbolo de moneda).
    private static func compactFormatter(code: String, locale: Locale) -> NumberFormatter {
        let key = "compact|\(code)|\(locale.identifier)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = locale
        let decimals = CurrencyCatalog.minorUnitDecimals(forCode: code.uppercased())
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        f.roundingMode = .halfUp
        f.usesGroupingSeparator = true
        cache.setObject(f, forKey: key)
        return f
    }
}
