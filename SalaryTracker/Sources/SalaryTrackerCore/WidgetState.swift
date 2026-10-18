import Foundation

/// Estado del widget por ubicación (feature: widgets en barra de menú /
/// Centro de Notificaciones).
///
/// La colocación del widget es del usuario (galería de widgets de macOS);
/// este estado es el **switch maestro** que la app expone en Configuración:
/// si una ubicación está desactivada y el widget ya fue colocado, el widget
/// se muestra en estado "desactivado" (gris) en esa superficie.
///
/// - Archivo JSON en `Application Support/SalaryTracker/widget-state.json`
///   (junto a `config.json`; directorio inyectable para tests).
/// - Escritura **atómica** (temp file + `replaceItemAt`), mismo patrón que
///   `ConfigStore`.
/// - Carga tolerante: no existe o corrupto → valores por defecto (ambas
///   ubicaciones activas), nunca un error.
public struct WidgetState: Codable, Equatable, Sendable {

    /// Widget activo en la barra de menú (Control Center).
    public var menuBar: Bool

    /// Widget activo en el Centro de Notificaciones (panel del reloj).
    public var notificationCenter: Bool

    /// Idioma elegido en la app (identificador BCP-47 de `AppLanguage`,
    /// p. ej. `"en"`, `"pt-BR"`). `nil` → el widget usa el idioma del
    /// sistema. La extensión del widget lo lee para resolver su bundle de
    /// localización (la extensión no hereda el override de `AppleLanguages`
    /// del dominio de la app).
    public var language: String?

    public init(
        menuBar: Bool = true,
        notificationCenter: Bool = true,
        language: String? = nil
    ) {
        self.menuBar = menuBar
        self.notificationCenter = notificationCenter
        self.language = language
    }

    /// Valores por defecto: ambas ubicaciones activas.
    public static let `default` = WidgetState()

    /// Decodificación tolerante: las claves ausentes toman su valor por
    /// defecto (compatibilidad con `widget-state.json` de versiones
    /// anteriores, que no traen `language`).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.menuBar = try c.decodeIfPresent(Bool.self, forKey: .menuBar) ?? true
        self.notificationCenter = try c.decodeIfPresent(Bool.self, forKey: .notificationCenter) ?? true
        self.language = try c.decodeIfPresent(String.self, forKey: .language)
    }
}

/// Persistencia de `WidgetState` (JSON atómico junto a `config.json`).
public struct WidgetStateStore: Sendable {

    /// Versión del schema de persistencia.
    public static let schemaVersion = 1

    private struct Envelope: Codable {
        var v: Int
        var state: WidgetState
    }

    private let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// - Parameter directory: directorio base (por defecto
    ///   `Application Support/SalaryTracker`). El archivo es
    ///   `widget-state.json` dentro de ese directorio.
    public init(directory: URL? = nil) {
        let dir = directory ?? ConfigStore.defaultDirectory()
        self.url = dir.appendingPathComponent("widget-state.json")
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let dec = JSONDecoder()
        self.encoder = enc
        self.decoder = dec
    }

    /// URL del archivo de estado del widget.
    public var fileURL: URL { url }

    /// Carga el estado persistido.
    /// - Note: No existe, está corrupto o tiene un schema desconocido →
    ///   `WidgetState.default` (nunca lanza).
    public func load() -> WidgetState {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let env = try? decoder.decode(Envelope.self, from: data),
              env.v == Self.schemaVersion
        else {
            return .default
        }
        return env.state
    }

    /// Guarda el estado de forma **atómica** (temp file + swap).
    /// - Note: Best-effort: si la escritura falla, se descarta (el widget
    ///   simplemente conserva su estado anterior).
    public func save(_ state: WidgetState) {
        let dir = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true)
        } catch {
            return
        }
        let env = Envelope(v: Self.schemaVersion, state: state)
        guard let data = try? encoder.encode(env) else { return }
        let temp = dir.appendingPathComponent(
            ".widget-state.json.tmp-\(UUID().uuidString)")
        do {
            try data.write(to: temp, options: [.atomic, .completeFileProtection])
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
        } catch {
            try? FileManager.default.removeItem(at: temp)
        }
    }

    /// Elimina el archivo persistido (útil para tests / reset).
    public func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
