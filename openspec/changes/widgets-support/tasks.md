# Estado: 11/11 ítems completos (incluida la sección 5, revisión «ambos»:
# switch maestro + contenido diferenciado). Core 100/100 tests + app
# `TEST SUCCEEDED`; `BUILD SUCCEEDED` Release; deploy verificado en vivo.
# Última verificación v1: 111/111 tests en verde, build 1.2.0 desplegado.

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

## 5. Revisión «ambos»: switch maestro + contenido diferenciado

Antecedente: los widgets no se desactivaban como esperaba el usuario — en
macOS 26 ambos kinds viven en el **mismo panel** y los toggles por
superficie no se correspondían con la ubicación real (los nombres de cada
widget describían la superficie «opuesta»). Diagnóstico completado
(estrategia de rutas `getpwuid` verificada vía log de chronod + estado vivo
del archivo; sin código de diagnóstico residual).

- [x] 5.1 Core `WidgetState.swift`: `WidgetState { enabled: Bool; language: String? }`, esquema v2 + migración v1 (`enabled = menuBar || notificationCenter`, conserva `language`); v desconocida/corrupto → `.default`
- [x] 5.2 `WidgetStateTests`: actualización a `enabled` + 3 tests de migración v1 (uno ON → ON, ambos OFF → OFF, conserva `language`) + roundtrip/corrupto/esquema errado/directorio/`remove()`
- [x] 5.3 Provider `SalaryProvider.swift`: `WidgetSurface` → `WidgetStyle { main, progress }`; `Status.active` con `remaining`; estados de mensaje unificados en `Status.message(WidgetMessage)`; `remainingText` (días/horas o horas/minutos vía `String(format:locale:)`); `guard state.enabled`
- [x] 5.4 `SalaryTrackerWidgetBundle.swift`: nombres «SalaryTracker» / «SalaryTracker · Avance» + descripciones nuevas; kind NC usa `ProgressWidgetView`; IDs de kind conservados
- [x] 5.5 `SalaryWidgetViews.swift`: `ProgressWidgetView` (small/medium: % LCD, barra, próximo pago, cuenta atrás) + `WidgetMessageView` compartido
- [x] 5.6 App `WidgetService.swift`: `enabledBinding` (reemplaza los 2 bindings por superficie); `mainKind`/`progressKind`
- [x] 5.7 `SettingsView.swift`: switch maestro único + líneas «Instalado» por widget + guion único de galería
- [x] 5.8 `Localizable.strings` ×6: se retiran 8 claves de toggles/nombres por superficie; se agregan `widget.toggle.show`, `widget.guide`, `widget.name.main/desc.main`, `widget.name.progress/desc.progress`, `widget.progressLabel`, `widget.remaining`, `widget.remaining.daysHours/hoursMinutes`
- [x] 5.9 Tests: core 100/100 (`swift test`, +3 migración v1) y app `TEST SUCCEEDED` (`xcodebuild test`); `BUILD SUCCEEDED` Release con appex
- [x] 5.10 Deploy + smoke: pkill extensión (proceso viejo), re-firma appex→app, `lsregister`, `/Applications/SalaryTracker.app` desplegado; verificado en `/tmp/chrono-boot.log`: extensión nueva carga estado v2, `SalaryTrackerMenuBar` reload «succeeded with 60 entries» / «Reload success»
- [x] 5.11 Docs: README sección «Widgets» (switch maestro, nombres, `widget-state.json` v2, changelog)
