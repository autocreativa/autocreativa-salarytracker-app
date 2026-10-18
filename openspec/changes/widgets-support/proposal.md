# Propuesta: Widgets de SalaryTracker (barra de menús / Centro de Notificaciones)

## Why

La app vive solo en la barra de menús: para ver el dinero ganado hay que hacer
clic y abrir el popover. En macOS 13+ existe superficie nativa adicional
(widgets en **Control Center / barra de menús** y en el **Centro de
Notificaciones**) que muestra información en todo momento sin interacción.
El usuario pidió esa visibilidad pasiva, controlada desde la propia app.

## What Changes

- **Extensión WidgetKit** `SalaryTrackerWidget` (bundle
  `dev.triton.salarytracker.widget`, macOS 13+, embeddada en
  `SalaryTracker.app/Contents/PlugIns/` vía script phase «Embed Widget
  Extension»).
- **Dos kinds**, mismo contenido, interruptores independientes:
  `SalaryTrackerMenuBar` («SalaryTracker · Barra de menús») y
  `SalaryTrackerNotificationCenter` («SalaryTracker · Centro de
  Notificaciones»). Cada kind: `WidgetFamily.systemSmall` +
  `systemMedium` y `TimelineProvider` con **timeline de 60 entradas**
  (1/min, 1 h) re-derivadas con el motor puro del core
  (`TrackerEngine.state(config:now:)`).
- **Estado compartido en el disco**: `WidgetState`/`WidgetStateStore` en
  `SalaryTrackerCore` → `widget-state.json` junto a `config.json`
  (escritura atómica, carga tolerante, valores por defecto si falta/corrupto).
  La app lo escribe (toggles + idioma); la extensión lo lee y re-deriva el
  estado con `SalaryCalculator`.
- **Configuración → Widgets**: toggle por superficie (interruptor maestro —
  OFF deja el widget colocado pintado como «desactivado»), guion inline de
  colocación (galería del Control Center) y check «Instalado» detectado con
  `WidgetCenter.getCurrentConfigurations` (macOS 13+).
- **Idioma de la extensión**: la app guarda el idioma corto en el estado; la
  extensión resuelve su propio `.lproj` (es base + en/pt-BR/it/de/fr) — no
  hereda el override `AppleLanguages` de la app. 17 claves `widget.*` en los
  6 locales.
- **Recarga de timelines**: `WidgetCenter.reloadTimelines(ofKind:)` al
  guardar configuración, al cambiar idioma y al arrancar.

## Impact

- Affected specs: `widgets` (nueva capacidad).
- Affected code: `SalaryTrackerCore` (+`WidgetState`, +`WidgetStateStore`),
  `SalaryTrackerApp` (+`WidgetService.swift`, cambios en `AppModel.swift`,
  `SettingsView.swift`), extensión nueva `SalaryTrackerWidget/`
  (`SalaryTrackerWidgetBundle.swift`, `SalaryProvider.swift`,
  `SalaryWidgetViews.swift`), `Localizable.strings` ×6,
  `project.pbxproj` (target de extensión + embedding), `SalaryTrackerTests`
  (AppModel sigue compilando con `WidgetService` por defecto).
- Versionado: **1.2.0** (feature). `dist/SalaryTracker-1.2.0.dmg` y
  `/Applications/SalaryTracker.app` actualizados.
- Tests: +7 de core (`WidgetStateTests`) → **98 core + 13 app = 111** en verde.
