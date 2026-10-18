import WidgetKit
import SwiftUI

/// Bundle de widgets de SalaryTracker (feature: widgets).
///
/// Dos **kinds** comparten la misma vista y la misma lógica de provider,
/// pero cada uno honra su propio switch maestro de Configuración
/// (decisión de diseño: activar/desactivar **por superficie** — WidgetKit no
/// expone la ubicación de colocación del widget, por lo que un kind por
/// superficie es la única forma de que el toggle funcione de forma
/// determinista):
///
/// - `SalaryTrackerMenuBar`: widget para la **barra de menú (Control
///   Center)**; honra `WidgetState.menuBar`.
/// - `SalaryTrackerNotificationCenter`: widget para el **Centro de
///   Notificaciones** (panel que se abre al hacer clic en el reloj);
///   honra `WidgetState.notificationCenter`.
///
/// La colocación en cada superficie la hace el usuario desde la galería de
/// widgets de macOS (no existe API pública para forzar la colocación).
@main
struct SalaryTrackerWidgetBundle: WidgetBundle {

    var body: some Widget {
        SalaryMenuBarWidget()
        SalaryNotificationCenterWidget()
    }
}

/// Widget para la barra de menú (Control Center).
struct SalaryMenuBarWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalaryTrackerMenuBar", provider: SalaryTimelineProvider(surface: .menuBar)) { entry in
            SalaryWidgetView(entry: entry)
        }
        .configurationDisplayName(L10nWidget.str("widget.name.menubar"))
        .description(L10nWidget.str("widget.desc.menubar"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Widget para el Centro de Notificaciones (panel del reloj).
struct SalaryNotificationCenterWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalaryTrackerNotificationCenter", provider: SalaryTimelineProvider(surface: .notificationCenter)) { entry in
            SalaryWidgetView(entry: entry)
        }
        .configurationDisplayName(L10nWidget.str("widget.name.nc"))
        .description(L10nWidget.str("widget.desc.nc"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
