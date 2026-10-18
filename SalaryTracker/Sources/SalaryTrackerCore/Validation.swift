import Foundation

/// Causas estables de configuración inválida (specs/configuration
/// "Validación antes de guardar").
///
/// Son claves de máquina (NO texto para mostrar): la UI las traduce a su
/// idioma vía `Localizable.strings` (multilenguaje). El core es puro y no
/// depende de la localización de la app.
public enum ValidationIssue: String, CaseIterable, Equatable, Sendable, Codable {
    /// Sueldo cero o negativo.
    case salaryNotPositive
    /// Sueldo fuera del rango soportado (> 9 999 999 999 999).
    case salaryTooLarge
    /// Código de moneda no es un ISO 4217 válido de 3 letras.
    case invalidCurrencyCode
    /// `lastWeekdayOfMonth` con weekday fuera de 1…7.
    case invalidWeekday
    /// `monthDay` con día fuera de 1…31.
    case invalidMonthDay
    /// `specificDate` anterior al inicio del contrato.
    case specificDateBeforeStart
}

/// Validación de configuración antes de persistir (specs/configuration
/// "Validación antes de guardar"). Devuelve causas estables y deterministas
/// (claves `ValidationIssue`); la traducción a texto visible corresponde a la UI.
public enum ConfigValidator {

    public struct Result: Equatable, Sendable {
        public let isValid: Bool
        /// Causas estables de invalidación (vacío si es válido).
        public let issues: [ValidationIssue]
        public init(isValid: Bool, issues: [ValidationIssue]) {
            self.isValid = isValid
            self.issues = issues
        }
    }

    /// Valida una configuración candidata.
    public static func validate(_ config: SalaryConfig) -> Result {
        var issues: [ValidationIssue] = []

        // 1) Monto: numérico y positivo.
        if config.salaryAmount <= 0 {
            issues.append(.salaryNotPositive)
        } else if config.salaryAmount > 9_999_999_999_999 {
            issues.append(.salaryTooLarge)
        }

        // 2) Moneda: código ISO de 3 letras.
        if config.currencyCode.count != 3 || !config.currencyCode.allSatisfy(\.isLetter) {
            issues.append(.invalidCurrencyCode)
        }

        // 3) Regla de pago completa.
        switch config.paymentRule {
        case .lastWeekdayOfMonth(let weekday):
            if !(1...7).contains(weekday) {
                issues.append(.invalidWeekday)
            }
        case .monthDay(let day):
            if !(1...31).contains(day) {
                issues.append(.invalidMonthDay)
            }
        case .specificDate:
            break
        }

        // 4) Fecha específica posterior al inicio del contrato (a nivel de fecha
        //    local; la hora de referencia es la misma en ambos).
        if case .specificDate(let payDay) = config.paymentRule {
            if payDay < config.contractStart {
                issues.append(.specificDateBeforeStart)
            }
        }

        return Result(isValid: issues.isEmpty, issues: issues)
    }
}
