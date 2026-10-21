import Foundation

/// Estado del widget (feature: widgets).
///
/// Hay **dos kinds** con apariencia idéntica pero colocación independiente:
/// «SalaryTracker» (`SalaryTrackerMenuBar`, superficie *barra superior* /
/// Control Center) y «SalaryTracker · Avance»
/// (`SalaryTrackerNotificationCenter`, superficie *centro de
/// notificaciones*, el panel que se abre al presionar la fecha y hora).
/// Cada superficie tiene su **propio toggle** (`menuBar` /
/// `notificationCenter`), así el usuario activa o desactiva cada widget
/// por separado. Si un widget está desactivado y ya fue colocado, se
/// muestra en estado "desactivado" (gris): la colocación siempre es del
/// usuario (galería de widgets de macOS) y no existe API para des-colocar
/// un widget programáticamente.
///
/// - Archivo JSON en `Application Support/SalaryTracker/widget-state.json`
///   (junto a `config.json`; directorio inyectable para tests).
/// - Escritura **atómica** (temp file + `replaceItemAt`), mismo patrón que
///   `ConfigStore`.
/// - Carga tolerante: no existe o corrupto → valores por defecto
///   (widgets activados), nunca un error. Los esquemas anteriores se
///   migran en la carga: v2 (switch maestro `enabled`) → ambos toggles al
///   valor de `enabled`; v1 (toggles por superficie) → mapeo directo.
public struct WidgetState: Codable, Equatable, Sendable {

    /// Widget activo en la barra superior (Control Center).
    public var menuBar: Bool

    /// Widget activo en el centro de notificaciones (panel del reloj).
    public var notificationCenter: Bool

    /// Idioma elegido en la app (identificador BCP-47 de `AppLanguage`,
    /// p. ej. `"en"`, `"pt-BR"`). `nil` → el widget usa el idioma del
    /// sistema. La extensión del widget lo lee para resolver su bundle de
    /// localización (la extensión no hereda el override de `AppleLanguages`
    /// del dominio de la app).
    public var language: String?

    public init(menuBar: Bool = true, notificationCenter: Bool = true,
                language: String? = nil) {
        self.menuBar = menuBar
        self.notificationCenter = notificationCenter
        self.language = language
    }

    /// Valores por defecto: ambos widgets activados.
    public static let `default` = WidgetState()

    /// Decodificación tolerante: las claves ausentes toman su valor por
    /// defecto (compatibilidad con archivos parciales).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.menuBar = try c.decodeIfPresent(Bool.self, forKey: .menuBar) ?? true
        self.notificationCenter = try c.decodeIfPresent(
            Bool.self, forKey: .notificationCenter) ?? true
        self.language = try c.decodeIfPresent(String.self, forKey: .language)
    }
}

/// Persistencia de `WidgetState` (JSON atómico junto a `config.json`).
public struct WidgetStateStore: Sendable {

    /// Versión actual del schema de persistencia.
    public static let schemaVersion = 3

    private struct Envelope: Codable {
        var v: Int
        var state: WidgetState
    }

    /// Schema v2 (switch maestro único). Solo lectura, para migrar.
    private struct V2State: Codable {
        var enabled: Bool
        var language: String?
    }

    private struct V2Envelope: Codable {
        var v: Int
        var state: V2State
    }

    /// Schema v1 (toggles por superficie). Solo lectura, para migrar.
    private struct V1Envelope: Codable {
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
    ///   `WidgetState.default` (nunca lanza). Migraciones: v2
    ///   (`enabled`) → ambos toggles al valor del switch maestro; v1
    ///   (toggles por superficie) → mapeo directo. Se conserva `language`.
    public func load() -> WidgetState {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url)
        else {
            return .default
        }
        if let env = try? decoder.decode(Envelope.self, from: data),
           env.v == Self.schemaVersion {
            return env.state
        }
        if let v2 = try? decoder.decode(V2Envelope.self, from: data),
           v2.v == 2 {
            return WidgetState(
                menuBar: v2.state.enabled,
                notificationCenter: v2.state.enabled,
                language: v2.state.language
            )
        }
        if let v1 = try? decoder.decode(V1Envelope.self, from: data),
           v1.v == 1 {
            return v1.state
        }
        return .default
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
