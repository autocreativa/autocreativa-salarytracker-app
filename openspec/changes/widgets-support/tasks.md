# Estado: 10/10 ítems completos. 111/111 tests en verde (98 core + 13 app).
# `BUILD SUCCEEDED` (Debug y Release, app + appex) y `TEST SUCCEEDED` (app).
# Build 1.2.0: `dist/SalaryTracker-1.2.0.dmg` + `/Applications/SalaryTracker.app`
# desplegados.

## 1. Core: estado compartido de widgets

- [x] 1.1 `WidgetState.swift`: `WidgetState` (menuBar/notificationCenter/language) + `WidgetStateStore` (load/save con swap atómico, envolvente `{v:1, state:{…}}`, corrupto/ausente → `.default`)
- [x] 1.2 `WidgetStateTests`: roundtrip, omisión de `language` nil, defecto con archivo ausente, tolerancia a JSON corrupto, inmutabilidad del default → core 98/98

## 2. Extensión WidgetKit

- [x] 2.1 Target `SalaryTrackerWidget` (appex macOS 13+, bundle `dev.triton.salarytracker.widget`) embebido en `Contents/PlugIns/` vía script phase «Embed Widget Extension» (fix del destino anidado de la fase copy-file estándar) + `ENABLE_USER_SCRIPT_SANDBOXING = NO` solo en el target de app
- [x] 2.2 `SalaryTrackerWidgetBundle.swift`: dos kinds (`SalaryTrackerMenuBar`, `SalaryTrackerNotificationCenter`), familias small/medium, preview
- [x] 2.3 `SalaryProvider.swift`: `L10nWidget` (bundle + locale por `WidgetState.language`), `WidgetSurface` (switch maestro), `SalaryTimelineProvider` (60 entradas de 1 min + fronteras, `.after(última)`), estados `active/openEnded/futureStart/notConfigured/invalid/disabled`
- [x] 2.4 `SalaryWidgetViews.swift`: vista LCD (dígitos 7 segmentos, progreso, próximo pago) + estados de mensaje, por familia

## 3. App: control y sincronización

- [x] 3.1 `WidgetService.swift`: `@Published installedKinds` + `state`, bindings por toggle, `refreshDetection()` vía `WidgetCenter.getCurrentConfigurations`, `syncLanguage` (nil para sistema), `reloadTimelines` de ambos kinds
- [x] 3.2 `AppModel.swift`: `@Published widgetService` (inyectable en init), `syncLanguage` + `reloadTimelines` + `refreshDetection` en arranque, `reloadTimelines` al guardar config, `syncLanguage` en `didChangeNotification`
- [x] 3.3 `SettingsView.swift`: sección «Widgets» entre «Idioma» y «Inicio» — dos toggles con guion inline de colocación / check «Instalado»
- [x] 3.4 `Localizable.strings` ×6 (es base, en, pt-BR, it, de, fr): 17 claves `widget.*` (sección, toggles, guiones, instalado, nombre/descripción por kind, etiquetas, estados)

## 4. Verificación y release

- [x] 4.1 Tests: core 98/98 (`swift test`) y app 13/13 (`xcodebuild test`); `BUILD SUCCEEDED` Debug y Release con appex embebido y firmado
- [x] 4.2 Smoke en vivo: app corriendo, toggle de idioma → `widget-state.json` con `{"language":"en","menuBar":true,"notificationCenter":true}`; appex con `Localizable.strings` + 5 lproj verificado en bundle
- [x] 4.3 Versionado 1.2.0 (app + appex), `dist/SalaryTracker-1.2.0.dmg` (UDZO, app + symlink `/Applications`), `dist/SalaryTracker.app` y `/Applications/SalaryTracker.app` actualizados
- [x] 4.4 Docs: README (estructura, sección «Widgets», `widget-state.json`, estado del proyecto) y este change de openspec
