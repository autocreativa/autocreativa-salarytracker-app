import AppKit
import SalaryTrackerCore

/// TEMP-DEBUG (diagnóstico; se eliminará): agrega una línea al log de
/// eventos del chip en el directorio de estado compartido.
@MainActor
private func appendChipTrace(_ line: String) {
    let url = SharedPaths.stateDirectory.appendingPathComponent("chip-events.log")
    let data = Data((line + "\n").utf8)
    if let h = try? FileHandle(forWritingTo: url) {
        h.seekToEndOfFile()
        _ = try? h.write(contentsOf: data)
        try? h.close()
    } else {
        try? data.write(to: url)
    }
}

/// Punto de entrada (design.md D7, task 8.3) — agente de la barra de menús.
///
/// Ciclo de vida **puro AppKit** (sin `SwiftUI.App`): la app es `LSUIElement`
/// (sin icono en Dock) y su única UI visible es el chip de la barra, un
/// `NSStatusItem` gestionado por `MenuBarChipController`. Se abandonó
/// `MenuBarExtra` (escena SwiftUI) porque `SceneBuilder` no admite `if/else`:
/// la escena no puede ocultarse en caliente, y el toggle «Barra superior»
/// (AppModel.showMenuBarChip) necesita mostrar/ocultar el chip sin
/// reiniciar.
///
/// Reapertura con el chip oculto (Spotlight/`open` →
/// `applicationShouldHandleReopen`): emite `salaryTrackerAppReopen` y el
/// delegate abre la configuración (donde está el toggle para volver a
/// mostrar el chip).
@main
enum SalaryTrackerMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        // Retención fuerte: `NSApplication.delegate` es weak; el local
        // mantiene vivo el delegate durante `run()` (que no retorna hasta
        // terminar la app).
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var model: AppModel?
    private let chip = MenuBarChipController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let m = AppModel()
        model = m
        // El controller se suscribe al modelo: el toggle «Barra superior»
        // muestra/oculta el chip en caliente.
        chip.attach(model: m)
        // Reapertura (Spotlight/`open`) con el chip oculto: no hay otro
        // punto de entrada a la UI → se abre la configuración (donde está
        // el toggle para volver a mostrar el chip).
        NotificationCenter.default.addObserver(
            forName: .salaryTrackerAppReopen, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, let m = self.model, !m.showMenuBarChip else { return }
                // TEMP-DEBUG (diagnóstico; se eliminará): traza la reapertura.
                appendChipTrace("reopen→openSettings \(ISO8601DateFormatter().string(from: Date()))")
                SettingsWindowController.shared.show(model: m)
            }
        }
    }

    func applicationShouldHandleReopen(hasVisibleWindows: Bool) -> Bool {
        // TEMP-DEBUG: traza que llegó el reopen.
        appendChipTrace("reopen(hasVisibleWindows=\(hasVisibleWindows)) \(ISO8601DateFormatter().string(from: Date()))")
        // Reapetura con la app ya corriendo: si el chip está oculto no hay
        // otro punto de entrada, así que se abre la configuración.
        NotificationCenter.default.post(name: .salaryTrackerAppReopen, object: nil)
        return false
    }
}
