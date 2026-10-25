import AppIntents
import AppKit
import Foundation
import SalaryTrackerCore

/// Intent que se ejecuta al **presionar el widget del centro de
/// notificaciones** (la tile entera es un `Button(intent:)`).
///
/// WidgetKit ejecuta el intent **en el proceso de la app** (la lanza si no
/// corre), por lo que `perform()` puede pedirle a la UI de la app que muestre
/// el popover de sueldo: la **misma vista** que abre el clic en el chip de
/// la barra superior.
///
/// No se expone en Atajos/Siri (no hay `AppShortcutsProvider` que lo
/// liste): solo existe para manejar el clic del widget.
struct OpenSalaryTrackerIntent: AppIntent {

    static let title: LocalizedStringResource = "Open SalaryTracker"
    static let description = IntentDescription("Opens the salary view.")

    /// Marca en el estado compartido que el usuario presionó el widget: la
    /// app (ya en marcha, o recién lanzada por el sistema) lo detecta vía
    /// monitor de directorio (`AppDelegate`) y abre el popover. El payload
    /// lleva un `UUID` + fecha para que una misma pulsación no se re-procese.
    ///
    /// **Sin `try?`**: si la escritura falla (p. ej. la excepción de sandbox
    /// `temporary-exception.files.home-relative-path.read-write` del
    /// directorio compartido no está presente o está mal escrita), el intent
    /// lanza y el fallo queda en el log del sistema. Un `try?` silencioso
    /// hizo que una pulsación del widget «no hiciera nada» sin rastro: el
    /// entitlement llevaba el path absoluto `/Library/...` (sistema) en vez
    /// del home-relative `Library/...` (usuario).
    func perform() async throws -> some IntentResult {
        let fm = FileManager.default
        // Posición del clic (coordenadas Cocoa, origen abajo-izquierda): la
        // app ancla el popover a la IZQUIERDA del icono/widget pulsado. Si
        // `NSEvent.mouseLocation` no está disponible, se omite y la app usa
        // el respaldo (extremo superior derecho).
        let mouse = NSEvent.mouseLocation
        let payload: [String: String] = [
            "uuid": UUID().uuidString,
            "at": ISO8601DateFormatter().string(from: Date()),
            "mouseX": String(format: "%.1f", mouse.x),
            "mouseY": String(format: "%.1f", mouse.y),
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try fm.createDirectory(at: SharedPaths.stateDirectory, withIntermediateDirectories: true)
        try data.write(to: SharedPaths.requestFile, options: .atomic)
        return .result()
    }
}
