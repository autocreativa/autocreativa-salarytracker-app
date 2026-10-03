import XCTest
@testable import SalaryTrackerCore

/// Tests de catálogo y formato de monedas (specs/currency-formatting).
final class CurrencyTests: XCTestCase {

    func testCatalogContainsRequiredISO4217() {
        // Mínimo del requerimiento "Catálogo de monedas".
        let required = ["CLP", "USD", "EUR", "GBP", "ARS", "BRL", "MXN", "JPY",
                        "CAD", "AUD", "CHF", "CNY", "KRW", "PLN", "CZK", "SEK",
                        "NOK", "DKK", "AED", "SGD", "ZAR", "COP", "PEN"]
        let codes = Set(CurrencyCatalog.all.map(\.code))
        for c in required {
            XCTAssertTrue(codes.contains(c), "el catálogo no incluye \(c)")
        }
        // Código ISO de 3 letras y símbolo no vacío; sin duplicados.
        XCTAssertEqual(CurrencyCatalog.all.count, codes.count, "hay códigos duplicados")
        for c in CurrencyCatalog.all {
            XCTAssertEqual(c.code.count, 3)
            XCTAssertFalse(c.symbol.isEmpty)
            XCTAssertGreaterThanOrEqual(c.minorUnitDecimals, 0)
        }
    }

    func testMinorUnitDecimals() {
        // Scenario "Decimales por moneda": CLP 0, USD 2, JPY 0.
        XCTAssertEqual(CurrencyCatalog.minorUnitDecimals(forCode: "CLP"), 0)
        XCTAssertEqual(CurrencyCatalog.minorUnitDecimals(forCode: "USD"), 2)
        XCTAssertEqual(CurrencyCatalog.minorUnitDecimals(forCode: "JPY"), 0)
        XCTAssertEqual(CurrencyCatalog.minorUnitDecimals(forCode: "EUR"), 2)
        // Desconocida → 2 por defecto.
        XCTAssertEqual(CurrencyCatalog.minorUnitDecimals(forCode: "XXX"), 2)
    }

    func testCLPFormatNoDecimals() {
        // Scenario "Formato CLP": símbolo $, miles con punto, 0 decimales (es_CL).
        let s = CurrencyFormatter.format(Decimal(1_500_000), code: "CLP",
                                         locale: Locale(identifier: "es_CL"))
        XCTAssertTrue(s.contains("$"), s)
        XCTAssertTrue(s.contains("1.500.000"), s)
        // 0 decimales: sin separador decimal ("," en es_CL)
        XCTAssertFalse(s.contains(","), s)
    }

    func testUSDFormatTwoDecimals() {
        // Scenario "Formato USD": dos decimales, separadores según locale.
        let s = CurrencyFormatter.format(Decimal(1500), code: "USD",
                                         locale: Locale(identifier: "en_US"))
        XCTAssertTrue(s.contains("$"), s)
        XCTAssertTrue(s.contains("1,500.00"), s)
    }

    func testEURFormat() {
        // Scenario "Formato EUR": símbolo € y dos decimales (en_US: €1,500.00).
        let s = CurrencyFormatter.format(Decimal(1500), code: "EUR",
                                         locale: Locale(identifier: "en_US"))
        XCTAssertTrue(s.contains("€"), s)
        XCTAssertTrue(s.contains("1,500.00"), s)
    }

    func testPresentationIndependentOfCalculation() {
        // Scenario "Presentación independiente del cálculo": el valor numérico
        // es invariante; solo cambia la representación textual.
        let clp = CurrencyFormatter.format(843_291.3687, code: "CLP",
                                           locale: Locale(identifier: "es_CL"))
        let usd = CurrencyFormatter.format(843_291.3687, code: "USD",
                                           locale: Locale(identifier: "en_US"))
        // CLP: 0 decimales → 843.291 ; USD: 2 decimales halfUp → 843,291.37
        XCTAssertTrue(clp.contains("843.291"), clp)
        XCTAssertTrue(usd.contains("843,291.37"), usd)
    }

    func testRoundingToMinorUnit() {
        // Scenario "Redondeo a la unidad menor": 843291.48 CLP → 843.291
        let clp = CurrencyFormatter.format(843_291.48, code: "CLP",
                                           locale: Locale(identifier: "es_CL"))
        XCTAssertTrue(clp.contains("843.291"), clp)
        // Scenario "Moneda con decimales": 1234.5678 USD → 1,234.57
        let usd = CurrencyFormatter.format(1234.5678, code: "USD",
                                           locale: Locale(identifier: "en_US"))
        XCTAssertTrue(usd.contains("1,234.57"), usd)
    }

    func testUnknownCurrencyFallsBackToCode() {
        let s = CurrencyFormatter.format(Decimal(100), code: "XXX",
                                         locale: Locale(identifier: "en_US"))
        XCTAssertTrue(s.contains("XXX"), s)
        XCTAssertTrue(s.contains("100.00"), s)
    }

    func testCompactFormatHasNoSymbol() {
        // Scenario "Indicador compacto sin símbolo" (Menu Bar): mismos dígitos,
        // decimales, redondeo y separadores que `format`, pero sin el símbolo.
        let clp = CurrencyFormatter.formatCompact(Decimal(1_500_000), code: "CLP",
                                                  locale: Locale(identifier: "es_CL"))
        XCTAssertEqual(clp, "1.500.000")
        XCTAssertFalse(clp.contains("$"), clp)

        let usd = CurrencyFormatter.formatCompact(Decimal(1500), code: "USD",
                                                  locale: Locale(identifier: "en_US"))
        XCTAssertEqual(usd, "1,500.00")
        XCTAssertFalse(usd.contains("$"), usd)

        // Mismo redondeo halfUp que el formato completo.
        let rounded = CurrencyFormatter.formatCompact(843_291.48, code: "CLP",
                                                      locale: Locale(identifier: "es_CL"))
        XCTAssertEqual(rounded, "843.291")
    }

    func testFormatRemaining() {
        XCTAssertEqual(CurrencyFormatter.formatRemaining(3671), "01:01:11")
        XCTAssertEqual(CurrencyFormatter.formatRemaining(90_000), "1d 01:00:00")
        XCTAssertEqual(CurrencyFormatter.formatRemaining(-5), "00:00:00")
    }

    func testFormatProgress() {
        // es_CL: separador decimal "," (p. ej. "67,42 %").
        let s = CurrencyFormatter.formatProgress(0.6742)
        XCTAssertTrue(s.contains("67"), s)
        XCTAssertTrue(s.contains("42"), s)
        XCTAssertTrue(s.contains("%"), s)
    }
}

/// Tests de validación de configuración (specs/configuration "Validación antes
/// de guardar").
final class ConfigValidatorTests: XCTestCase {

    func testValidConfig() {
        let r = ConfigValidator.validate(T.baseConfig())
        XCTAssertTrue(r.isValid)
        XCTAssertTrue(r.errors.isEmpty)
    }

    func testZeroAndNegativeSalaryInvalid() {
        for bad in [Decimal(0), Decimal(-1)] {
            let r = ConfigValidator.validate(T.baseConfig(salary: bad))
            XCTAssertFalse(r.isValid)
            XCTAssertTrue(r.errors.contains { $0.lowercased().contains("sueldo") },
                          "\(r.errors)")
        }
    }

    func testTooBigSalaryInvalid() {
        let r = ConfigValidator.validate(T.baseConfig(salary: 10_000_000_000_000))
        XCTAssertFalse(r.isValid)
    }

    func testInvalidCurrencyCode() {
        var config = T.baseConfig()
        config.currencyCode = "CL"
        XCTAssertFalse(ConfigValidator.validate(config).isValid)
        config.currencyCode = "CLP1"
        XCTAssertFalse(ConfigValidator.validate(config).isValid)
    }

    func testSpecificDateBeforeStartInvalid() {
        let config = T.baseConfig(
            start: LocalDate(year: 2026, month: 9, day: 25),
            rule: .specificDate(LocalDate(year: 2026, month: 9, day: 10)))
        let r = ConfigValidator.validate(config)
        XCTAssertFalse(r.isValid)
        XCTAssertTrue(r.errors.contains { $0.contains("posterior al inicio") },
                      "\(r.errors)")
    }

    func testSpecificDateSameDayAsStartIsValid() {
        // Mismo día local: la hora de referencia es idéntica (R-PAYMENT-TIME),
        // por lo que la fecha NO es anterior al inicio.
        let config = T.baseConfig(
            start: LocalDate(year: 2026, month: 9, day: 25),
            rule: .specificDate(LocalDate(year: 2026, month: 9, day: 25)))
        XCTAssertTrue(ConfigValidator.validate(config).isValid)
    }

    func testMonthDayOutOfRangeInvalid() {
        let config = T.baseConfig(rule: .monthDay(day: 32))
        let r = ConfigValidator.validate(config)
        XCTAssertFalse(r.isValid)
        XCTAssertTrue(r.errors.contains { $0.contains("1 y 31") }, "\(r.errors)")
    }

    func testLastWeekdayOutOfRangeInvalid() {
        let config = T.baseConfig(rule: .lastWeekdayOfMonth(weekday: 8))
        XCTAssertFalse(ConfigValidator.validate(config).isValid)
    }
}
