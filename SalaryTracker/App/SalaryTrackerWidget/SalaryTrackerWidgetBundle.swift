import WidgetKit
import SwiftUI

/// Bundle de widgets de SalaryTracker (feature: widgets).
///
/// Dos **kinds** con **contenido diferenciado** (en macOS 26 ambos se
/// colocan juntos en el mismo panel — Control Center / Centro de
/// Notificaciones unificados —, así que no tiene sentido activarlos por
/// superficie):
///
/// - `SalaryTrackerMenuBar` → «SalaryTracker» (variante *main*): dinero
///   ganado (LCD), progreso y próximo pago.
/// - `SalaryTrackerNotificationCenter` → «SalaryTracker · Avance»
///   (variante *progress*): avance del período y cuenta atrás al próximo
///   pago.
///
/// La activación la controla el switch maestro único de Configuración
/// (`WidgetState.enabled`), común a ambos kinds. Los **IDs de kind no se
/// renombraron** a propósito: son la identidad de la colocación y
/// cambiarlos huérfanos los widgets que el usuario ya colocó.
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

/// Widget principal: dinero ganado, progreso y próximo pago.
struct SalaryMainWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalaryTrackerMenuBar",
                            provider: SalaryTimelineProvider(style: .main)) { entry in
            SalaryWidgetView(entry: entry)
        }
        .configurationDisplayName(L10nWidget.str("widget.name.main"))
        .description(L10nWidget.str("widget.desc.main"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Widget de avance: progreso del período y cuenta atrás al próximo pago.
struct SalaryProgressWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalaryTrackerNotificationCenter",
                            provider: SalaryTimelineProvider(style: .progress)) { entry in
            ProgressWidgetView(entry: entry)
        }
        .configurationDisplayName(L10nWidget.str("widget.name.progress"))
        .description(L10nWidget.str("widget.desc.progress"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
