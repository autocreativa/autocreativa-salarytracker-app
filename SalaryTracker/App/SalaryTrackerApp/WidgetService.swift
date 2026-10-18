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
/// El estado (toggles por superficie + idioma) vive en `WidgetStateStore`
/// (archivo `widget-state.json` junto a `config.json`): la extensión lo lee
/// directamente, por lo que la app es su única escritora.
@MainActor
final class WidgetService: ObservableObject {

    /// Kinds de cada superficie de widget (deben coincidir con la extensión).
    static let menuBarKind = "SalaryTrackerMenuBar"
    static let notificationCenterKind = "SalaryTrackerNotificationCenter"

    /// Kinds de widgets colocados por el usuario (vacío = ninguno).
    @Published private(set) var installedKinds: Set<String> = []

    /// Estado vigente de widgets (toggles por superficie + idioma).
    @Published private(set) var state: WidgetState = .default

    private let stateStore = WidgetStateStore()

    init() {
        state = stateStore.load()
    }

    /// Bindings de los toggles de la sección «Widgets» (leer del estado
    /// vigente; al escribir, persisten a disco y recargan los timelines).
    /// `@MainActor`: los closures se ejecutan en el thread principal (SwiftUI).
    @MainActor var menuBarBinding: Binding<Bool> {
        Binding(
            get: { self.state.menuBar },
            set: { newValue in self.updateState { $0.menuBar = newValue } }
        )
    }

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
    /// cambiar idioma, arranque de la app).
    func reloadTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: Self.menuBarKind)
        WidgetCenter.shared.reloadTimelines(ofKind: Self.notificationCenterKind)
    }
}
