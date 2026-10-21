import WidgetKit
import SwiftUI

/// Bundle de widgets de SalaryTracker (feature: widgets).
///
/// Dos **kinds** **visualmente idénticos** (misma vista: dinero ganado
/// LCD, progreso y próximo pago) pero **separados**, cada uno en su
/// superficie y con su propio toggle de activación en Configuración:
///
/// - `SalaryTrackerMenuBar` → «SalaryTracker»: barra superior / Control
///   Center (toggle `WidgetState.menuBar`).
/// - `SalaryTrackerNotificationCenter` → «SalaryTracker · Avance»: centro
///   de notificaciones, el panel que se abre al presionar la fecha y hora
///   (toggle `WidgetState.notificationCenter`).
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
/// y próximo pago.
struct SalaryMainWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalaryTrackerMenuBar",
                            provider: SalaryTimelineProvider(style: .menuBar)) { entry in
            SalaryWidgetView(entry: entry)
        }
        .configurationDisplayName(L10nWidget.str("widget.name.main"))
        .description(L10nWidget.str("widget.desc.main"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Widget del centro de notificaciones (panel del reloj): mismo contenido
/// que el de la barra superior, como widget separado.
struct SalaryProgressWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalaryTrackerNotificationCenter",
                            provider: SalaryTimelineProvider(style: .notificationCenter)) { entry in
            SalaryWidgetView(entry: entry)
        }
        .configurationDisplayName(L10nWidget.str("widget.name.progress"))
        .description(L10nWidget.str("widget.desc.progress"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
