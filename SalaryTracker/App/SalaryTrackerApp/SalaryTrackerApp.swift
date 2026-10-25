import AppKit
import SalaryTrackerCore

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
    /// Monitor del directorio de estado compartido: detecta
    /// `widget-open-request.json` (la escribe `OpenSalaryTrackerIntent` al
    /// presionar el widget del centro de notificaciones).
    private var stateMonitor: DispatchSourceFileSystemObject?
    /// UUID de la última petición de apertura procesada (dedupe).
    private var lastWidgetOpenUUID: String?
    /// Posición del clic en el icono/widget de la barra superior (coordenadas
    /// de pantalla Cocoa, origen abajo-izquierda) que acompañó a la última
    /// petición de apertura. El popover se ancla a su izquierda.
    private var pendingOpenPoint: NSPoint?

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
                SettingsWindowController.shared.show(model: m)
            }
        }
        // Clic en el widget del centro de notificaciones (la escribe el
        // intent `OpenSalaryTrackerIntent` en el estado compartido): abre la
        // misma vista que el chip.
        NotificationCenter.default.addObserver(
            forName: .salaryTrackerWidgetOpen, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.openSalaryView()
            }
        }
        // Monitor del directorio de estado (detecta la petición de apertura)
        // + chequeo de petición pendiente (si el intent corrió durante
        // este mismo arranque, antes de que el monitor se registrara).
        startStateDirectoryMonitor()
        checkWidgetOpenRequest()
    }

    /// Abre la vista de sueldo (popover) al presionar el widget del centro
    /// de notificaciones: activa la app y pide al controlador del chip que
    /// muestre el popover (con ancla efímera si el chip está oculto).
    private func openSalaryView() {
        NSApp.activate(ignoringOtherApps: true)
        _ = chip.openPopover(near: pendingOpenPoint)
    }

    /// Segundos máximos entre la escritura de la petición y su procesamiento
    /// (más allá, la petición se considera caducada y se ignora).
    private let requestFreshness: TimeInterval = 60

    /// Monitor de directorio sobre el estado compartido: cualquier cambio
    /// (incluida la escritura de `widget-open-request.json`, que la escribe
    /// `OpenSalaryTrackerIntent` al presionar el widget del centro de
    /// notificaciones) dispara el chequeo de la petición. (`DispatchSource`
    /// sobre el fd del directorio: `makeDirectoryMonitor` no existe en
    /// macOS.)
    private func startStateDirectoryMonitor() {
        let dir = SharedPaths.stateDirectory
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let mon = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .attrib, .delete],
            queue: .main)
        mon.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.checkWidgetOpenRequest()
            }
        }
        mon.setCancelHandler { close(fd) }
        mon.resume()
        stateMonitor = mon
    }

    /// Si hay una petición de apertura fresca (< `requestFreshness`) y no
    /// procesada, emite `.salaryTrackerWidgetOpen` (el observer abre el
    /// popover).
    private func checkWidgetOpenRequest() {
        let url = SharedPaths.requestFile
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let mtime = attrs?[.modificationDate] as? Date
        let fresh = mtime.map { Date().timeIntervalSince($0) < requestFreshness } ?? false
        let data = try? Data(contentsOf: url)
        let obj = (try? JSONSerialization.jsonObject(with: data ?? Data())) as? [String: String]
        let uuid = obj?["uuid"]
        guard attrs != nil, fresh,
              let obj, let uuid, uuid != lastWidgetOpenUUID
        else { return }
        lastWidgetOpenUUID = uuid
        if let mx = obj["mouseX"], let my = obj["mouseY"],
           let x = Double(mx), let y = Double(my) {
            pendingOpenPoint = NSPoint(x: x, y: y)
        } else {
            pendingOpenPoint = nil
        }
        NotificationCenter.default.post(name: .salaryTrackerWidgetOpen, object: nil)
    }

    func applicationShouldHandleReopen(hasVisibleWindows: Bool) -> Bool {
        // Reapertura con la app ya corriendo: si el chip está oculto no hay
        // otro punto de entrada, así que se abre la configuración.
        NotificationCenter.default.post(name: .salaryTrackerAppReopen, object: nil)
        return false
    }
}
