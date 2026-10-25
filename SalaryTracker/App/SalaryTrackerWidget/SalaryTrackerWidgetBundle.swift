import WidgetKit
import SwiftUI
import AppIntents

/// Bundle de widgets de SalaryTracker.
///
/// Dos **kinds** **visualmente idénticos** (misma vista: dinero ganado
/// LCD, progreso y próximo pago) pero **separados**, cada uno en su
/// superficie y con su propio toggle de activación en Configuración
/// (sección única «Widgets»):
///
/// - `SalaryTrackerMenuBar` → «SalaryTracker»: barra superior / Control
///   Center. Comparte superficie con el chip de la app: su visibilidad
///   sigue el switch maestro «Widgets» (`WidgetState.menuBar`; el chip
///   `AppModel.showMenuBarChip` lo deriva).
/// - `SalaryTrackerNotificationCenter` → «SalaryTracker · Avance»: centro
///   de notificaciones, el panel que se abre al presionar la fecha y hora
///   (toggle `WidgetState.notificationCenter`). **Al presionarlo se abre la
///   misma vista que abre el chip** (intent interactivo, ver
///   `SalaryProgressWidget`). Se actualiza **cada segundo** (timeline en
///   vivo de 1 s).
///
/// Los **IDs de kind no se renombraron** a propósito: son la identidad de
/// la colocación y cambiarlos huérfanos los widgets que el usuario ya
/// colocó.
///
/// La colocación en el panel la hace el usuario desde la galería de
/// widgets de macOS (no existe API pública para forzar la colocación).
@main
struct SalaryTrackerWidgetBundle: WidgetBundle {

    var body: some Widget {
        SalaryMainWidget()
        SalaryProgressWidget()
    }
}

/// Widget de la barra superior (Control Center): dinero ganado, progreso
/// y próximo pago. Su visibilidad sigue el switch «Barra superior»
/// (comparte superficie con el chip: ON ⇒ tile con datos; OFF ⇒ tile
/// transparente).
struct SalaryMainWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalaryTrackerMenuBar",
                            provider: SalaryTimelineProvider(style: .menuBar)) { entry in
            if #available(macOS 14.0, *) {
                Button(intent: OpenSalaryTrackerIntent()) {
                    SalaryWidgetView(entry: entry, style: .menuBar)
                }
                .buttonStyle(.plain)
            } else {
                SalaryWidgetView(entry: entry, style: .menuBar)
            }
        }
        .configurationDisplayName(L10nWidget.str("widget.name.main"))
        .description(L10nWidget.str("widget.desc.main"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Widget del centro de notificaciones (panel del reloj): mismo contenido
/// que el de la barra superior, como widget separado.
///
/// **Apertura**: la tile entera es un `Button(intent:)` (`OpenSalaryTracker
/// Intent`, interactividad de widgets macOS 14+): al presionarlo, el
/// sistema ejecuta el intent **en el proceso de la app** (la lanza si no
/// corre) y este escribe `widget-open-request.json` en el estado
/// compartido; la app lo detecta (monitor de directorio en `AppDelegate`)
/// y abre el popover (la misma vista que abre el clic en el chip), anclado
/// a una ventana efímera si el chip está oculto. En macOS < 14 la tile es
/// una vista simple (sin apertura).
///
/// **Actualización**: cada segundo (reloj en vivo del provider: 1 entry +
/// renovación a los 1 s).
///
/// **Desactivado** (switch OFF): muestra un mensaje con las instrucciones
/// para reactivarlo (a diferencia de la barra superior, que se oculta).
struct SalaryProgressWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalaryTrackerNotificationCenter",
                            provider: SalaryTimelineProvider(style: .notificationCenter)) { entry in
            progressContent(entry: entry)
        }
        .configurationDisplayName(L10nWidget.str("widget.name.progress"))
        .description(L10nWidget.str("widget.desc.progress"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }

    /// Tile interactiva (macOS 14+): botón con la vista completa; en macOS
    /// anteriores, la vista sin interactividad.
    @ViewBuilder
    private func progressContent(entry: SalaryEntry) -> some View {
        if #available(macOS 14.0, *) {
            Button(intent: OpenSalaryTrackerIntent()) {
                SalaryWidgetView(entry: entry, style: .notificationCenter)
            }
            .buttonStyle(.plain)
        } else {
            SalaryWidgetView(entry: entry, style: .notificationCenter)
        }
    }
}
