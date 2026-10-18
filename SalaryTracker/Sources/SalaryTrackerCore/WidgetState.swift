import Foundation

/// Estado del widget (feature: widgets).
///
/// Los dos kinds («SalaryTracker» y «SalaryTracker · Avance») se muestran
/// juntos en el mismo panel de macOS 26, por lo que la activación es
/// **maestra y única**: `enabled` es el switch de Configuración que controla
/// ambos widgets. Si está desactivado y un widget ya fue colocado, el
/// widget se muestra en estado "desactivado" (gris) — la colocación siempre
/// es del usuario (galería de widgets de macOS); no existe API para
/// des-colocar un widget programáticamente.
///
/// - Archivo JSON en `Application Support/SalaryTracker/widget-state.json`
///   (junto a `config.json`; directorio inyectable para tests).
/// - Escritura **atómica** (temp file + `replaceItemAt`), mismo patrón que
///   `ConfigStore`.
/// - Carga tolerante: no existe o corrupto → valores por defecto
///   (widgets activados), nunca un error. El schema v1 (toggles por
///   superficie: `menuBar`/`notificationCenter`) se migra en la carga:
///   `enabled = menuBar || notificationCenter`.
public struct WidgetState: Codable, Equatable, Sendable {

    /// Switch maestro: widgets visibles (contenido activo). `false` → los
    /// widgets colocados muestran el estado «desactivado» en gris.
    public var enabled: Bool

    /// Idioma elegido en la app (identificador BCP-47 de `AppLanguage`,
    /// p. ej. `"en"`, `"pt-BR"`). `nil` → el widget usa el idioma del
    /// sistema. La extensión del widget lo lee para resolver su bundle de
    /// localización (la extensión no hereda el override de `AppleLanguages`
    /// del dominio de la app).
    public var language: String?

    public init(enabled: Bool = true, language: String? = nil) {
        self.enabled = enabled
        self.language = language
    }

    /// Valores por defecto: widgets activados.
    public static let `default` = WidgetState()

    /// Decodificación tolerante: las claves ausentes toman su valor por
    /// defecto (compatibilidad con archivos sin `language`).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.language = try c.decodeIfPresent(String.self, forKey: .language)
    }
}

/// Persistencia de `WidgetState` (JSON atómico junto a `config.json`).
public struct WidgetStateStore: Sendable {

    /// Versión actual del schema de persistencia.
    public static let schemaVersion = 2

    private struct Envelope: Codable {
        var v: Int
        var state: WidgetState
    }

    /// Schema v1 (toggles por superficie). Solo lectura, para migrar.
    private struct LegacyV1State: Codable {
        var menuBar: Bool
        var notificationCenter: Bool
        var language: String?
    }

    private struct LegacyV1Envelope: Codable {
        var v: Int
        var state: LegacyV1State
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
    ///   `WidgetState.default` (nunca lanza). El schema v1 se migra:
    ///   `enabled = menuBar || notificationCenter` (si alguna superficie
    ///   estaba activa, los widgets se consideran activos).
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
        if let legacy = try? decoder.decode(LegacyV1Envelope.self, from: data),
           legacy.v == 1 {
            return WidgetState(
                enabled: legacy.state.menuBar || legacy.state.notificationCenter,
                language: legacy.state.language
            )
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
