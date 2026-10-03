import Foundation

/// Persistencia de la configuración (design.md D8; specs/configuration
/// "Persistencia local").
///
/// - Archivo JSON en `Application Support/SalaryTracker/config.json` (el
///   directorio base es inyectable para tests).
/// - Escritura **atómica**: serializar → escribir a un archivo temporal en el
///   mismo directorio → `replaceItemAt` (swap vía rename atómico). El archivo
///   anterior permanece válido hasta el swap; una escritura interrumpida nunca
///   deja un archivo parcial.
/// - Versión de schema (`"v": 1`) para migraciones futuras.
/// - Carga: no existe → `nil`; corrupto → `StoreError` (sin excepciones/
///   crashes).
public struct ConfigStore: Sendable {

    /// Versión del schema de persistencia.
    public static let schemaVersion = 1

    public enum StoreError: LocalizedError, Equatable, Sendable {
        /// El archivo existe pero no puede decodificarse (corrupto o schema
        /// incompatible).
        case corrupted
        /// El archivo no puede leerse del disco (permisos, I/O).
        case unreadable(String)
        /// No se pudo escribir/swap-ear el archivo.
        case writeFailed(String)

        public var errorDescription: String? {
            switch self {
            case .corrupted:
                return "El archivo de configuración está corrupto."
            case .unreadable(let detail):
                return "No se pudo leer la configuración: \(detail)"
            case .writeFailed(let detail):
                return "No se pudo guardar la configuración: \(detail)"
            }
        }
    }

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Envelope con versión de schema (D8).
    private struct Envelope: Codable {
        var v: Int
        var config: SalaryConfig
    }

    /// - Parameter directory: directorio base (por defecto
    ///   `Application Support/SalaryTracker`). El archivo es `config.json`
    ///   dentro de ese directorio.
    public init(directory: URL? = nil) {
        self.directory = directory ?? ConfigStore.defaultDirectory()
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let dec = JSONDecoder()
        self.encoder = enc
        self.decoder = dec
    }

    /// Directorio base por defecto: `Application Support/SalaryTracker`.
    public static func defaultDirectory() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory())
        return base.appendingPathComponent("SalaryTracker", isDirectory: true)
    }

    /// URL del archivo de configuración.
    public var fileURL: URL { directory.appendingPathComponent("config.json") }

    /// Carga la configuración persistida.
    /// - Returns: la configuración, o `nil` si no existe todavía (primera
    ///   ejecución → `notConfigured`).
    /// - Throws: `StoreError.corrupted` si el archivo existe pero es ilegible
    ///   para el schema; `StoreError.unreadable` si falla la lectura del disco.
    public func load() throws -> SalaryConfig? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw StoreError.unreadable(error.localizedDescription)
        }
        do {
            let env = try decoder.decode(Envelope.self, from: data)
            guard env.v == ConfigStore.schemaVersion else {
                throw StoreError.corrupted
            }
            return env.config
        } catch let e as StoreError {
            throw e
        } catch {
            throw StoreError.corrupted
        }
    }

    /// Guarda la configuración de forma **atómica** (temp file + swap).
    /// - Note: El directorio se crea si no existe. Si el swap falla, el
    ///   archivo anterior permanece intacto y se lanza `StoreError.writeFailed`.
    public func save(_ config: SalaryConfig) throws {
        let dir = fileURL.deletingLastPathComponent()
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw StoreError.writeFailed(error.localizedDescription)
        }
        let env = Envelope(v: ConfigStore.schemaVersion, config: config)
        let data: Data
        do {
            data = try encoder.encode(env)
        } catch {
            throw StoreError.writeFailed(error.localizedDescription)
        }
        // Temp file en el MISMO directorio (mismo volumen → rename atómico).
        let temp = dir.appendingPathComponent(
            ".config.json.tmp-\(UUID().uuidString)")
        do {
            try data.write(to: temp, options: [.atomic, .completeFileProtection])
        } catch {
            try? fm.removeItem(at: temp)
            throw StoreError.writeFailed(error.localizedDescription)
        }
        do {
            // replaceItemAt: swap atómico (rename). Si fileURL no existe,
            // también funciona (equivalente a move). El resultado (backup URL)
            // no se conserva: la copia anterior se descarta.
            _ = try fm.replaceItemAt(fileURL, withItemAt: temp)
        } catch {
            try? fm.removeItem(at: temp)
            throw StoreError.writeFailed(error.localizedDescription)
        }
    }

    /// Elimina el archivo persistido (útil para tests / reset).
    public func remove() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private var fm: FileManager { FileManager.default }
}
