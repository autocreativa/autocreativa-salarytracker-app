import Foundation

/// Validación de configuración antes de persistir (specs/configuration
/// "Validación antes de guardar"). Mensajes específicos y estables (la UI los
/// muestra tal cual).
public enum ConfigValidator {

    public struct Result: Equatable, Sendable {
        public let isValid: Bool
        public let errors: [String]
        public init(isValid: Bool, errors: [String]) {
            self.isValid = isValid
            self.errors = errors
        }
    }

    /// Valida una configuración candidata.
    public static func validate(_ config: SalaryConfig) -> Result {
        var errors: [String] = []

        // 1) Monto: numérico y positivo.
        if config.salaryAmount <= 0 {
            errors.append("El sueldo debe ser mayor que cero.")
        } else if config.salaryAmount > 9_999_999_999_999 {
            errors.append("El sueldo es demasiado grande.")
        }

        // 2) Moneda: código ISO de 3 letras.
        if config.currencyCode.count != 3 || !config.currencyCode.allSatisfy(\.isLetter) {
            errors.append("Selecciona una moneda válida del catálogo.")
        }

        // 3) Regla de pago completa.
        switch config.paymentRule {
        case .lastWeekdayOfMonth(let weekday):
            if !(1...7).contains(weekday) {
                errors.append("Día de la semana inválido para la regla de pago.")
            }
        case .monthDay(let day):
            if !(1...31).contains(day) {
                errors.append("El día de pago debe estar entre 1 y 31.")
            }
        case .specificDate:
            break
        }

        // 4) Fecha específica posterior al inicio del contrato (a nivel de fecha
        //    local; la hora de referencia es la misma en ambos).
        if case .specificDate(let payDay) = config.paymentRule {
            if payDay < config.contractStart {
                errors.append("La fecha de pago debe ser posterior al inicio del contrato.")
            }
        }

        return Result(isValid: errors.isEmpty, errors: errors)
    }
}
