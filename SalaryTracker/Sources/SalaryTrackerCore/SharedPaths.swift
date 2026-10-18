import Foundation

/// Ruta del estado compartido con la extensión del widget.
///
/// La extensión corre **sandboxeada** (`SalaryTrackerWidget.entitlements`)
/// y por defecto no puede leer `~/Library/Application Support/` (donde la
/// app guarda `config.json` y `widget-state.json`). El entitlement
/// `com.apple.security.temporary-exception.files.home-relative-path.
/// read-write` (mismo mecanismo que Tailscale usa para `~/.kube/`) le
/// concede acceso explícito a `~/Library/Application Support/SalaryTracker/`,
/// por lo que ambos procesos comparten directamente esos archivos, sin
/// App Group ni espejos.
public enum SharedPaths {

    /// Nombre del directorio de estado bajo `~/Library/Application Support/`.
    public static let folderName = "SalaryTracker"

    /// Home **real** del usuario (no el remapeado a su contenedor por
    /// sandbox): `getpwuid` lee la base de datos de contraseñas y no es
    /// interceptado por el sandbox, a diferencia de `NSHomeDirectory()`.
    static var realHome: URL {
        if let pw = getpwuid(getuid()) {
            return URL(fileURLWithPath: String(cString: pw.pointee.pw_dir),
                       isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    /// Directorio compartido de estado:
    /// `~/Library/Application Support/SalaryTracker/`.
    public static var stateDirectory: URL {
        realHome
            .appendingPathComponent("Library/Application Support/\(folderName)",
                                   isDirectory: true)
    }
}
