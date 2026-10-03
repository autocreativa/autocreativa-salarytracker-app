import SwiftUI
import AppKit
import SalaryTrackerCore

/// Punto de entrada de la app de Menu Bar (design.md D7, task 8.3).
///
/// `MenuBarExtra` estilo `.window` (indicador + popover de detalle). La
/// configuración vive en una `NSWindow` dedicada gestionada por
/// `SettingsWindowController` (AppKit): al ser una ventana de primera clase,
/// no se cierra al interactuar con pickers/datepicker, y al abrirse el
/// popover de la barra se oculta (specs/settings-view, fix 2026-10-03).
/// `LSUIElement`: sin icono en Dock.
@main
struct SalaryTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(model)
        } label: {
            MenuBarLabel(state: model.state)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Delegate mínimo: no hay windows propias (las escenas las gestiona SwiftUI).
/// Se mantiene para un posible control futuro del ciclo de vida.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {}
}
