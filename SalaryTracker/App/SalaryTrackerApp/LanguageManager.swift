import Foundation
import SwiftUI
import SalaryTrackerCore

/// Idiomas soportados por la app (multilenguaje).
///
/// `system` sigue el idioma del sistema macOS. El resto fija un locale
/// independiente del sistema: la app se muestra en ese idioma sin tocar
/// las preferencias de macOS.
enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case spanish
    case english
    case portuguese
    case italian
    case german
    case french

    var id: String { rawValue }

    /// Etiqueta nativa para el picker (cada idioma se escribe en su propio
    /// idioma, sin traducir).
    @MainActor
    var displayName: String {
        switch self {
        case .system:     return L10n.str("language.system")
        case .spanish:    return "Español"
        case .english:    return "English"
        case .portuguese: return "Português"
        case .italian:    return "Italiano"
        case .german:     return "Deutsch"
        case .french:     return "Français"
        }
    }

    /// Locale efectivo para formateo (fechas, números, pickers nativos) y
    /// lookups de strings. `es_CL`/`pt_BR` para mantener la identidad original.
    var locale: Locale {
        switch self {
        case .system:     return .current
        case .spanish:    return Locale(identifier: "es_CL")
        case .english:    return Locale(identifier: "en_US")
        case .portuguese: return Locale(identifier: "pt_BR")
        case .italian:    return Locale(identifier: "it_IT")
        case .german:     return Locale(identifier: "de_DE")
        case .french:     return Locale(identifier: "fr_FR")
        }
    }

    /// Identificadores BCP-47 para el override de `AppleLanguages` de
    /// `Bundle.main` (vacío ⇒ borrar el override → idioma del sistema).
    var languageIdentifiers: [String] {
        switch self {
        case .system:     return []
        case .spanish:    return ["es"]
        case .english:    return ["en"]
        case .portuguese: return ["pt-BR"]
        case .italian:    return ["it"]
        case .german:     return ["de"]
        case .french:     return ["fr"]
        }
    }
}

/// Gestiona el idioma de la app (multilenguaje).
///
/// - Persistencia: `UserDefaults` (clave `appLanguage`); sobrevive reinicios.
/// - Aplicación inmediata: `L10n` resuelve el bundle `.lproj` **explícito**
///   según la selección (en macOS, `Bundle.main` no se re-resuelve al cambiar
///   `AppleLanguages` en caliente) y, al cambiar la selección, se publica
///   `didChangeNotification` para que las vistas refresquen en vivo. El
///   locale de fechas/números lo inyecta cada vista desde `selection.locale`
///   (environment `\.locale`).
@MainActor
final class LanguageManager: ObservableObject {

    /// Notificación de cambio de idioma (las vistas re-renderizan en vivo).
    static let didChangeNotification = Notification.Name("SalaryTrackerLanguageDidChange")

    /// Selección vigente (persistida al cambiar).
    @Published var selection: AppLanguage {
        didSet {
            guard oldValue != selection else { return }
            defaults.set(selection.rawValue, forKey: Self.defaultsKey)
            Self.applySystemOverride(selection)
            L10n.language = selection
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    /// Locale efectivo actual (para inyectar en el environment de SwiftUI).
    var effectiveLocale: Locale { selection.locale }

    private let defaults: UserDefaults
    private static let defaultsKey = "appLanguage"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.defaultsKey),
           let lang = AppLanguage(rawValue: raw) {
            self.selection = lang
        } else {
            self.selection = .system
        }
        // `L10n` resuelve los strings según este idioma (didSet no corre en init).
        L10n.language = selection
    }

    /// Escribe (o borra) el override de idioma de `Bundle.main`.
    ///
    /// Es la única forma estándar de localizar una app macOS sin relanzarla
    /// completa: `NSLocalizedString`/`Text` consultan `AppleLanguages` en
    /// `UserDefaults` al resolver la localización del bundle.
    static func applySystemOverride(_ lang: AppLanguage) {
        if lang.languageIdentifiers.isEmpty {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set(lang.languageIdentifiers, forKey: "AppleLanguages")
        }
    }
}
