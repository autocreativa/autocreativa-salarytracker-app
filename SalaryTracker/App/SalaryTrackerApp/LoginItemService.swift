import Foundation
import AppKit
import SwiftUI
import ServiceManagement

/// Servicio de "abrir al iniciar sesión" (login item) para la app.
///
/// Usa `SMAppService` (macOS 13+), que crea/elimina una entrada en
/// System Settings → General → Login Items. Requiere que la app esté en
/// `/Applications` para que el login item persista entre reinicios.
///
/// ## Nota sobre pruebas
/// `SMAppService.register()` lanza un error en el sandbox de los tests
/// (`swift test` / `xcodebuild test`) porque el proceso de test no está en
/// `/Applications`. Por eso `isEnabled` se cachea al iniciar y los tests
/// verifican solo la parte de la vista (label + binding), no la llamada real
/// a `SMAppService`.
@MainActor
final class LoginItemService: ObservableObject {

    /// Estado del login item, sincronizado con el sistema al iniciar.
    @Published private(set) var isEnabled: Bool

    /// Binding para el toggle de la vista: cualquier escritura pasa por
    /// `setEnabled`, que es la que realmente escribe en el sistema (y publica
    /// el estado real si macOS lo revierte).
    var toggleBinding: Binding<Bool> {
        Binding(
            get: { [weak self] in self?.isEnabled ?? false },
            set: { [weak self] newValue in self?.setEnabled(newValue) }
        )
    }

    /// Razón por la que la activación falló (nil si nunca falló).
    @Published private(set) var lastError: String?

    private let service: SMAppService

    init() {
        let svc = SMAppService.mainApp
        self.service = svc
        // Estado inicial desde el sistema (sin pedir permisos ni modificar nada).
        self.isEnabled = (try? svc.status == .enabled) ?? false
    }

    /// Activa o desactiva el inicio automático de la app.
    /// - Returns: `true` si el estado quedó sincronizado con el sistema.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            lastError = nil
            isEnabled = (try? service.status == .enabled) ?? enabled
            return true
        } catch {
            lastError = "No se pudo \(enabled ? "activar" : "desactivar") el inicio automático: \(error.localizedDescription)"
            // El estado real puede haber cambiado igualmente; sincronizamos.
            isEnabled = (try? service.status == .enabled) ?? isEnabled
            return false
        }
    }
}