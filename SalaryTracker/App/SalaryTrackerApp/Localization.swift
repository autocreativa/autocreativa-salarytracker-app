import Foundation
import SalaryTrackerCore

/// Capa de localización de la app (multilenguaje).
///
/// Todos los textos de UI se leen con `L10n` desde `Localizable.strings`.
/// El core (`SalaryTrackerCore`) es puro y entrega **claves estables**
/// (`ValidationIssue`, `TrackerState.InvalidReason`); aquí se mapean a texto
/// localizable. La UI nunca hardcodea mensajes.
///
/// **Nota (macOS):** cambiar `AppleLanguages` en `UserDefaults` **no** hace
/// que un proceso ya corriendo re-resuelva `Bundle.main` (la lista de idiomas
/// del proceso se cachea al arrancar; a diferencia de iOS). Por eso `L10n`
/// resuelve el bundle `.lproj` **explícitamente** según el idioma elegido
/// (`L10n.language`, que `LanguageManager` mantiene sincronizado): el cambio
/// de idioma es inmediato, sin relanzar la app.
@MainActor
enum L10n {

    /// Idioma vigente (lo fija `LanguageManager` al iniciar y en cada cambio).
    static var language: AppLanguage = .system

    /// Caché de bundles resueltos por idioma.
    private static var bundleCache: [AppLanguage: Bundle] = [:]

    /// Traduce una clave al idioma vigente.
    /// - Note: Si la clave no existe, devuelve la clave (visible → fácil de detectar).
    static func str(_ key: String) -> String {
        bundle(for: language).localizedString(forKey: key, value: key, table: nil)
    }

    /// Traduce una clave con argumentos de formato (`%@`, `%d`, `%lf`, …).
    static func str(_ key: String, _ args: CVarArg...) -> String {
        let template = str(key)
        return String(format: template, locale: language.locale, arguments: args)
    }

    /// Bundle de localizaciones para el idioma pedido.
    ///
    /// - `.system`: usa la localización de la app que coincida con el idioma
    ///   del sistema; si no hay coincidencia, Español (región de desarrollo).
    private static func bundle(for lang: AppLanguage) -> Bundle {
        // `.system` no se cachea: el idioma del sistema puede cambiar en
        // caliente y la resolución es barata (un read de defaults).
        if lang != .system, let cached = bundleCache[lang] { return cached }
        let resolved: Bundle
        switch lang {
        case .system:
            // Idioma REAL del sistema: `AppleLanguages` de `UserDefaults`
            // (después de borrar el override de la app devuelve el dominio
            // global). NO `Locale.current`: en un proceso ya corriendo queda
            // congelado con el idioma que tenía al arrancar.
            let code = (UserDefaults.standard
                .stringArray(forKey: "AppleLanguages") ?? [])
                .first
                .flatMap { Locale.Language(identifier: $0).languageCode?.identifier }
            let candidates: [String]
            switch code {
            case "en": candidates = ["en"]
            case "pt": candidates = ["pt-BR"]
            case "it": candidates = ["it"]
            case "de": candidates = ["de"]
            case "fr": candidates = ["fr"]
            default:   candidates = []   // es (y demás) → región de desarrollo
            }
            resolved = candidates
                .compactMap { Self.lprojBundle($0) }
                .first ?? .main
        case .spanish:
            // Español es la región de desarrollo: sin directorio `.lproj`,
            // los strings están en la raíz de `Contents/Resources/`.
            resolved = .main
        case .english:
            resolved = Self.lprojBundle("en") ?? .main
        case .portuguese:
            resolved = Self.lprojBundle("pt-BR") ?? .main
        case .italian:
            resolved = Self.lprojBundle("it") ?? .main
        case .german:
            resolved = Self.lprojBundle("de") ?? .main
        case .french:
            resolved = Self.lprojBundle("fr") ?? .main
        }
        if lang != .system { bundleCache[lang] = resolved }
        return resolved
    }

    /// Directorio `.lproj` dentro del bundle de la app para un código de
    /// idioma (nil si no existe).
    private static func lprojBundle(_ languageCode: String) -> Bundle? {
        guard let url = Bundle.main.url(forResource: languageCode, withExtension: "lproj")
        else { return nil }
        return Bundle(url: url)
    }
}

// MARK: - Mapeo de claves del core → texto localizable

extension ValidationIssue {
    /// Mensaje localizable para mostrar al usuario (specs/configuration
    /// "Validación antes de guardar").
    @MainActor
    var localizedMessage: String {
        switch self {
        case .salaryNotPositive:
            return L10n.str("validation.salaryNotPositive")
        case .salaryTooLarge:
            return L10n.str("validation.salaryTooLarge")
        case .invalidCurrencyCode:
            return L10n.str("validation.invalidCurrencyCode")
        case .invalidWeekday:
            return L10n.str("validation.invalidWeekday")
        case .invalidMonthDay:
            return L10n.str("validation.invalidMonthDay")
        case .specificDateBeforeStart:
            return L10n.str("validation.specificDateBeforeStart")
        }
    }
}

extension TrackerState.InvalidReason {
    /// Mensaje localizable del estado `.invalid`.
    ///
    /// - Note: En `.configStore`, si la app tiene un detalle cargado
    ///   (`AppModel.loadIssue`), la UI lo prefiere; esta es la reserva.
    @MainActor
    var localizedMessage: String {
        switch self {
        case .validation(let issue):
            return issue.localizedMessage
        case .configStore:
            return L10n.str("store.configUnreadable")
        }
    }
}

extension ConfigStore.StoreError {
    /// Mensaje localizable con el detalle del error del sistema.
    @MainActor
    var localizedMessage: String {
        switch self {
        case .corrupted:
            return L10n.str("store.corrupted")
        case .unreadable(let detail):
            return L10n.str("store.unreadable", detail)
        case .writeFailed(let detail):
            return L10n.str("store.writeFailed", detail)
        }
    }
}
