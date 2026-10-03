import AppKit
import SwiftUI
import SalaryTrackerCore

/// Ventana dedicada de configuración (specs/settings-view).
///
/// Gestionada con AppKit porque `openWindow` de SwiftUI no funciona desde el
/// contexto de `MenuBarExtra` (fix 2026-10-03). Al hacerse ventana key,
/// el popover transitorio de la barra pierde el foco y se oculta solo
/// (scenario "Estabilidad al seleccionar valores").
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var model: AppModel?

    /// Muestra (o re-utiliza) la ventana de configuración con el `model` dado.
    func show(model: AppModel) {
        self.model = model
        let win: NSWindow
        if let existing = window {
            win = existing
        } else {
            win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Configuración"
            win.delegate = self
            win.isReleasedWhenClosed = false
            win.minSize = NSSize(width: 400, height: 540)
            win.center()
            window = win
        }
        // Cada apertura regenera la vista: @State se re-inicializa y
        // onAppear recarga desde la config vigente.
        win.contentViewController = NSHostingController(
            rootView: SettingsView(onClose: { [weak self] in self?.closeWindow() })
                .environmentObject(model)
        )
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Cierra la ventana (la llaman "Guardar" y "Descartar").
    func closeWindow() {
        window?.close()
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        // Cierre por el botón rojo: liberar para recrear en la próxima apertura.
        Task { @MainActor [weak self] in
            self?.window = nil
            self?.model = nil
        }
    }
}
