import Foundation
import SwiftUI
import WidgetKit
import SalaryTrackerCore

/// Servicio de widgets de la app (feature: widgets).
///
/// - **Detección**: `WidgetCenter.getCurrentConfigurations` (basada en
///   completion, disponible desde macOS 13) reporta qué `kind` de widget
///   tiene el usuario colocado en el sistema.
/// - **Recarga**: `reloadTimelines(ofKind:)` ante cambios de configuración o
///   de idioma, y al arrancar la app.
///
/// El estado (un toggle **por superficie**: barra superior / centro de
/// notificaciones, + idioma) vive en `WidgetStateStore`
/// (archivo `widget-state.json` junto a `config.json`) en el directorio
/// compartido `~/Library/Application Support/SalaryTracker/` (`SharedPaths`):
/// la extensión sandboxeada lo lee gracias a su excepción de sandbox.
@MainActor
final class WidgetService: ObservableObject {

    /// Kinds de cada widget (deben coincidir con la extensión).
    /// Los IDs se conservan de la primera versión (identidad de colocación).
    static let mainKind = "SalaryTrackerMenuBar"
    static let progressKind = "SalaryTrackerNotificationCenter"

    /// Kinds de widgets colocados por el usuario (vacío = ninguno).
    @Published private(set) var installedKinds: Set<String> = []

    /// Estado vigente de widgets (toggles por superficie + idioma).
    @Published private(set) var state: WidgetState = .default

    /// Store sobre el directorio compartido con la extensión (ver
    /// `SharedPaths`): la extensión sandboxeada lo lee vía su excepción
    /// de sandbox `temporary-exception.files.home-relative-path`.
    private let stateStore = WidgetStateStore(directory: SharedPaths.stateDirectory)

    init() {
        state = stateStore.load()
    }

    /// Binding del toggle de la barra superior (Control Center). Al
    /// escribir, persiste a disco y recarga los timelines.
    /// `@MainActor`: los closures se ejecutan en el thread principal (SwiftUI).
    @MainActor var menuBarBinding: Binding<Bool> {
        Binding(
            get: { self.state.menuBar },
            set: { newValue in self.updateState { $0.menuBar = newValue } }
        )
    }

    /// Binding del toggle del centro de notificaciones (panel del reloj).
    /// Al escribir, persiste a disco y recarga los timelines.
    @MainActor var notificationCenterBinding: Binding<Bool> {
        Binding(
            get: { self.state.notificationCenter },
            set: { newValue in self.updateState { $0.notificationCenter = newValue } }
        )
    }

    /// Actualiza la detección de widgets colocados.
    func refreshDetection() {
        WidgetCenter.shared.getCurrentConfigurations { [weak self] result in
            guard let self, case .success(let infos) = result else { return }
            let kinds = Set(infos.map(\.kind))
            // TEMP-DEBUG (diagnóstico; se eliminará): traza los widgets
            // colocados según el sistema.
            if let d = try? JSONSerialization.data(withJSONObject: [
                "at": ISO8601DateFormatter().string(from: Date()),
                "placed": infos.map { "\($0.kind):\($0.family.rawValue)" }.sorted(),
            ], options: [.prettyPrinted]) {
                try? d.write(to: SharedPaths.stateDirectory
                    .appendingPathComponent("widget-placed.json"))
            }
            Task { @MainActor in
                self.installedKinds = kinds
            }
        }
    }

    /// Si el widget de la superficie indicada está colocado.
    func isInstalled(_ kind: String) -> Bool { installedKinds.contains(kind) }

    /// Escribe el idioma de la app en el estado de widgets. La extensión
    /// resuelve su propio bundle `.lproj` según este valor (no hereda el
    /// override de `AppleLanguages` de la app): `.system` → `nil`, y la
    /// extensión sigue el idioma del sistema; el resto → código corto
    /// (`es`, `en`, `pt-BR`, `it`, `de`, `fr`).
    func syncLanguage(_ lang: AppLanguage) {
        let code: String?
        switch lang {
        case .system: code = nil
        default:      code = lang.languageIdentifiers.first
        }
        guard state.language != code else { return }
        state.language = code
        stateStore.save(state)
        reloadTimelines()
    }

    /// Persiste el estado de widgets (toggles/idioma) y recarga los timelines.
    func updateState(_ mutate: (inout WidgetState) -> Void) {
        var next = state
        mutate(&next)
        state = next
        stateStore.save(next)
        reloadTimelines()
    }

    /// Notifica a los widgets que sus datos cambiaron (guardar config,
    /// cambiar idioma, arranque de la app). Recarga los dos kinds.
    func reloadTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: Self.mainKind)
        WidgetCenter.shared.reloadTimelines(ofKind: Self.progressKind)
    }
}
