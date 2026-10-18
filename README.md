# SalaryTracker

App de **Menu Bar** para macOS que muestra, en tiempo real y segundo a segundo,
cuánto de tu sueldo periodico ya has ganado, según la fecha/hora de inicio del
contrato y una regla de pago (último día-semana del mes, día N del mes, o fecha
específica).

- 100 % local y offline, sin dependencias de terceros.
- El estado **siempre se deriva** de `config + reloj actual`: no hay contadores
  acumulados, por lo que cerrar/abrir la app nunca desincroniza nada.
- Fuente de verdad del diseño: [`openspec/changes/salary-tracker-menubar/`](openspec/changes/salary-tracker-menubar/)
  (propuesta, diseño, 6 specs, tasks y [`acceptance.md`](openspec/changes/salary-tracker-menubar/acceptance.md)).

> **Repositorio de la landing (web de marketing):** repositorio hermano
> [`autocreativa-salarytracker-app-landing`](https://github.com/autocreativa/autocreativa-salarytracker-app-landing).
> Este repositorio contiene **solo la app**.

## Estructura

```
.
├── SalaryTracker/
│   ├── Package.swift                 # SwiftPM: librería SalaryTrackerCore (lógica pura, sin UI)
│   ├── Sources/SalaryTrackerCore/    # modelo, reglas de pago, motor, validación, monedas, ConfigStore, WidgetState
│   ├── Tests/SalaryTrackerCoreTests/ # 98 tests (XCTest) con reloj manual
│   ├── Scripts/make_icon.swift       # genera App/SalaryTrackerApp/AppIcon.icns desde cero
│   └── App/
│       ├── SalaryTracker.xcodeproj   # target de app macOS 13+ (LSUIElement) + target de widget + target de tests
│       ├── SalaryTrackerApp/         # @main, AppModel, WidgetService, SettingsWindowController, Views/*, AppIcon.icns
│   ├── SalaryTrackerWidget/      # extensión WidgetKit (2 kinds: «SalaryTracker» y «SalaryTracker · Avance»)
│       └── SalaryTrackerTests/       # 13 tests de app (8 integración AppModel + 5 render)
└── openspec/                         # fuente de verdad del diseño
    ├── config.yaml
    ├── specs/                        # specs vivas (capacidades)
    ├── changes/salary-tracker-menubar/  # propuesta: design, 6 specs, tasks, acceptance.md
    └── changes/widgets-support/        # widgets: proposal, design, spec, tasks
```

Lo que **no** se versiona (ver [`.gitignore`](.gitignore)): `.build/`,
`.swiftpm/`, `SalaryTracker/App/build/`, `SalaryTracker/dist/` (el `.app`
Release), `*.profraw`, `.idea/`, `.opencode/` y `.DS_Store`.

## Requisitos

- macOS 13+ (los builds se hicieron con macOS 27 / Xcode 27).
- **Importante:** si tu toolchain activo es CommandLineTools, `swift test`
  fallará (sin XCTest). Usa Xcode con `DEVELOPER_DIR`, o ejecuta una vez:
  `sudo xcode-select -s /Applications/Xcode.app`

## Build

```bash
cd SalaryTracker

# 1) Build + tests de la librería core (98 tests)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# 2) Build de la app (Debug o Release)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project App/SalaryTracker.xcodeproj -scheme SalaryTracker \
  -configuration Release build
```

## Tests

```bash
# Core: 98 tests
cd SalaryTracker
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# App: 13 tests (8 de integración de AppModel + 5 de render del indicador)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project App/SalaryTracker.xcodeproj -scheme SalaryTracker \
  -configuration Debug test
```

> Debug rápido de un test concreto del target de app:
> ```bash
> DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xctest \
>   -XCTest 'AppModelTests/testRolloverAfterPaymentYieldsNewPeriod' \
>   $(xcrun --find xctest >/dev/null; xcodebuild -project App/SalaryTracker.xcodeproj -scheme SalaryTracker -configuration Debug test -derivedDataPath /tmp/st_dd 2>/dev/null; find /tmp/st_dd -name 'SalaryTrackerTests.xctest' | head -1)
> ```

## Ejecutar

```bash
# Desde el build Debug de Xcode
open ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/SalaryTracker.app

# O la build Release empaquetada
open SalaryTracker/dist/SalaryTracker.app
# (opcional) instalarla permanentemente:
# cp -R SalaryTracker/dist/SalaryTracker.app /Applications/
```

La app no muestra icono en el Dock: vive en la **Menu Bar** como un chip oscuro
estilo LCD con un punto verde y el valor en dígitos de 7 segmentos (sin símbolo
de moneda), que se actualiza cada tick. Clic → popover con panel LCD (valor
grande + valor "fantasma" de referencia) y tarjetas de detalles (período,
próximo pago, tiempo restante, progreso). **Configuración** se abre en una
ventana dedicada que no se cierra al seleccionar valores.

> `MenuBarExtra` descarta shapes custom del label, por eso el contenido se
> pre-renderiza a un `NSImage` non-template con `ImageRenderer` antes de
> entregárselo al status item (ver `Views/MenuBarLabel.swift`).

> **Abrir al iniciar sesión:** en Configuración existe la opción «Abrir al iniciar sesión». Al activarla, la app se agrega a Login Items de macOS (System Settings → General → Login Items). Para que el cambio persista entre reinicios, la app debe estar ubicada en `/Applications/`.

## Multilenguaje

La UI está completamente localizada en **español (fuente), inglés,
portugués (Brasil), italiano, alemán y francés**. En Configuración hay una
sección «Idioma»:

- **Idioma del sistema** (por defecto): sigue el idioma de macOS.
- **Español / English / Português / Italiano / Deutsch / Français**: fijan ese
  idioma en la app sin tocar las preferencias del sistema.

Detalles de la implementación:

- Textos: `Localizable.strings` en `SalaryTrackerApp/` (es, región de
  desarrollo) + `en.lproj/`, `pt-BR.lproj/`, `it.lproj/`, `de.lproj/` y
  `fr.lproj/`; lookup vía `L10n` (`Localization.swift`), que devuelve la
  clave si no existe (visible → fácil de detectar).
- **Resolución explícita por idioma:** en macOS, cambiar `AppleLanguages` no
  re-resuelve `Bundle.main` en un proceso ya corriendo (el idioma del proceso
  queda congelado al arrancar). Por eso `L10n` carga el `.lproj` correspondiente
  directamente, y «Idioma del sistema» lee el idioma real de
  `AppleLanguages` en `UserDefaults` (dominio global, sin caché).
- **El core (`SalaryTrackerCore`) sigue siendo puro**: no conoce idiomas.
  Devuelve *claves estables* (`ValidationIssue`, `TrackerState.InvalidReason`);
  el mapeo clave → texto localizable vive solo en la app.
- Fechas, números y porcentajes se formatean con el locale del idioma vigente
  (`LanguageManager.effectiveLocale`, inyectado vía `.environment(\.locale, …)`
  para los `DatePicker`/`Picker` nativos).
- El cambio de idioma es **inmediato y persistente** (`UserDefaults`, clave
  `appLanguage`): se re-renderizan las vistas al instante (notificación
  `SalaryTrackerLanguageDidChange` → `objectWillChange` de `AppModel`).
- Para el modo «fijado» (es/en/pt/it/de/fr) la app escribe el override
  `AppleLanguages` en `UserDefaults`; «Idioma del sistema» lo borra.
- Para añadir un idioma: crear `<lang>.lproj/Localizable.strings` con todas
  las claves, registrarlo en el target (Xcode o `project.pbxproj`) y agregarlo
  a `AppLanguage`, `CFBundleLocalizations` y `knownRegions`.

## Widgets

SalaryTracker incluye una extensión **WidgetKit** con **dos kinds de
contenido diferenciado** (en macOS 26 ambos se colocan juntos en el mismo
panel — Control Center / Centro de Notificaciones unificados —, así que se
activan juntos con un solo switch):

- **SalaryTracker** (kind `SalaryTrackerMenuBar`) — dinero ganado en el
  período vigente (estilo LCD de la app), progreso y próximo pago.
- **SalaryTracker · Avance** (kind `SalaryTrackerNotificationCenter`) —
  porcentaje de avance del período, barra de progreso, próximo pago y
  cuenta atrás al mismo.

Ambos soportan las familias *small* y *medium* y los estados de mensaje
«contrato aún no comienza», «sin configurar», «configuración inválida» y
«widget desactivado». Los IDs de kind se conservan de la primera versión
(identidad de la colocación; renombrarlos huérfanos los widgets ya
colocados).

**Colocación** (el usuario, desde la galería de widgets de macOS): abrir
Control Center (el botón de dos interruptores en la barra de menús) → clic
en el lápiz para editar → buscar «SalaryTracker» y «SalaryTracker · Avance»
y añadirlos. macOS no permite a la app colocar ni quitar widgets de un
lugar, por eso:

- En **Configuración → Widgets** hay un **switch maestro** («Mostrar
  widgets»): **ON** = los widgets muestran datos; **OFF** = si ya están
  colocados, se pintan en gris con «Widget desactivado» (interruptor de
  contenido, no remoción).
- Si la detección (`WidgetCenter.getCurrentConfigurations`, macOS 13+) ve
  un kind instalado, se muestra un check «Instalado» por cada widget
  colocado; si no hay ninguno, un guion inline de colocación.

**Sincronización**: la app recarga los timelines al guardar la
configuración, al cambiar el idioma y al arrancar
(`WidgetCenter.reloadTimelines(ofKind:)`). El estado (switch maestro +
idioma) vive en `widget-state.json` (junto a `config.json`); la extensión
lo lee directamente y resuelve su propio `.lproj` según el idioma guardado
— no hereda el override de `AppleLanguages` de la app.

### Config (JSON local)

Ubicación: `~/Library/Application Support/SalaryTracker/config.json`

```json
{
  "v": 1,
  "config": {
    "salaryAmount": 1500000,
    "currencyCode": "CLP",
    "contractStart": { "year": 2026, "month": 9, "day": 1 },
    "contractStartTime": { "hour": 9, "minute": 0 },
    "paymentRule": { "lastWeekdayOfMonth": { "weekday": 5 } }
  }
}
```

- `paymentRule`: `lastWeekdayOfMonth.weekday` (1=Dom…5=Vie), `monthDay.month`/`.day`
  (día N con salto de meses cortos), o `specificDate` (período abierto al pasarla).
- **Primera ejecución:** sin `config.json` la app arranca con una configuración por
  defecto en memoria (sueldo **553.553 CLP**, "último viernes de cada mes", inicio del
  contrato en el instante actual) y la barra muestra el dinero ganado desde ese
  instante; solo se escribe el archivo al guardar desde Configuración.
- La app **solo escribe** el archivo cuando guardas en Configuración
  (swap atómico); un archivo corrupto produce estado `INVALID`, nunca un crash.

`widget-state.json` (misma carpeta, solo lo escribe la app; esquema **v2**):
switch maestro de los widgets + idioma para la extensión.

```json
{ "v": 2, "state": { "enabled": true, "language": "en" } }
```

- `enabled`: `false` → los widgets colocados se pintan «desactivado» en
  gris (no se quitan del lugar).
- `language`: `nil` → el widget usa el idioma del sistema (se omite la
  clave); el resto, código corto (`es`, `en`, `pt-BR`, `it`, `de`, `fr`).
- **Migración v1→v2** al cargar: el esquema v1
  (`{ "v": 1, "state": { "menuBar": bool, "notificationCenter": bool, … } }`)
  migra a `enabled = menuBar || notificationCenter` conservando `language`.
- Corrupto, ausente o de esquema desconocido → valores por defecto
  (`enabled: true`), nunca un error.

## Release

- **v1.0.0** (2026-10-04) — primer release público:
  [GitHub Releases](https://github.com/autocreativa/autocreativa-salarytracker-app/releases)
  con `SalaryTracker-1.0.0-macos-universal.zip` (universal x86_64/arm64,
  macOS 13+), icono y `SHA256SUMS`.

## Estado del proyecto

### 2026-10-18 — Revisión de widgets: switch maestro + contenido diferenciado

Antecedente: los toggles por superficie de la v1 no se correspondían con la
realidad en macOS 26 — ambos widgets viven juntos en el mismo panel
(Control Center / Centro de Notificaciones unificados) y los nombres no
describían su ubicación, lo que hacía que el widget visible no fuera el que
desactivaba el switch.

- **Switch maestro único** en Configuración → Widgets («Mostrar widgets»):
  activa/desactiva el contenido de **ambos** widgets a la vez; con OFF se
  pintan «desactivado» en gris. Checks «Instalado» por widget colocado y
  guion único de colocación.
- **Contenido diferenciado**: «SalaryTracker» (dinero ganado LCD + progreso
  + próximo pago) y «SalaryTracker · Avance» (% de avance + barra + próximo
  pago + cuenta atrás). IDs de kind conservados (identidad de la colocación).
- **`widget-state.json` v2**: `enabled` + `language`, con migración
  automática desde v1 (`enabled = menuBar || notificationCenter`).
- 100/100 tests del core (+3 de migración v1) y tests de app en verde;
  build Release y deploy verificados en vivo (logs de chronod: extensión
  nueva con estado v2, timelines recomputados con 60 entradas).

### 2026-10-18 — Widgets en barra de menús y Centro de Notificaciones · build 1.2.0

- **Extensión WidgetKit** (`SalaryTrackerWidget`, bundle
  `dev.triton.salarytracker.widget`, macOS 13+) embebida en
  `SalaryTracker.app/Contents/PlugIns/`: dos kinds (barra de menús /
  Centro de Notificaciones), familias small y medium, mismo estilo LCD de
  la app. Timeline de 60 entradas (1/min) re-derivadas con el motor puro
  del core; recarga al guardar config, cambiar idioma y al arrancar.
- **Configuración → Widgets**: toggle por superficie (interruptor maestro;
  OFF pinta el widget colocado como «desactivado»), guion inline de
  colocación y check «Instalado» vía
  `WidgetCenter.getCurrentConfigurations()`.
- **Estado compartido**: `WidgetState`/`WidgetStateStore` en el core →
  `widget-state.json` junto a `config.json` (escritura atómica, carga
  tolerante); la extensión lee el idioma guardado y resuelve su `.lproj`
  propio (17 claves `widget.*` en los 6 locales).
- 111/111 tests en verde (98 core + 13 de app).
- **Build 1.2.0** lista: `SalaryTracker/dist/SalaryTracker-1.2.0.dmg`
  (SHA256 `8f61d853…7f375e2`), `dist/SalaryTracker.app` (Release) y
  `/Applications/SalaryTracker.app` actualizados.

### 2026-10-18 — Multilenguaje: +it/de/fr y fix de «Idioma del sistema» · build 1.1.0

- **6 idiomas**: español (fuente), English, Português (BR), **Italiano,
  Deutsch, Français** (nuevos `it.lproj/`, `de.lproj/`, `fr.lproj/`);
  picker actualizado.
- **Fix «Idioma del sistema»**: el modo sistema leía `Locale.current`, que en
  un proceso ya corriendo queda congelado con el idioma del arranque; ahora
  `L10n` lee `AppleLanguages` real de `UserDefaults` (sin caché) y resuelve el
  `.lproj` explícito (en macOS, `Bundle.main` no se re-resuelve al cambiar el
  override en caliente).
- **Build 1.1.0** lista: `SalaryTracker/dist/SalaryTracker-1.1.0.dmg`
  (SHA256 `5b5dea26…bbdaea`), `dist/SalaryTracker.app` (Release) y
  `/Applications/SalaryTracker.app` actualizados.

### 2026-10-18 — Multilenguaje (es / en / pt-BR) · build 1.1.0

- UI 100 % localizada: popover, barra (accessibility), ventana de
  configuración y errores (validación + archivo de configuración).
- Picker de idioma en Configuración (sistema / Español / English / Português);
  cambio inmediato y persistente; fechas y números por locale del idioma.
- El core se mantiene puro: entrega claves estables (`ValidationIssue`,
  `TrackerState.InvalidReason`); la traducción vive solo en la app.
- 104/104 tests en verde (91 core + 13 de app).

### 2026-10-04 — v1.0.0

- **v1.0.0** — release del rediseño visual botanical/LCD tomado de la landing:
  chip oscuro en la barra, popover con panel LCD y tarjetas, y ventana de
  configuración con campos y acciones verdes. Icono propio: `$` en 7 segmentos
  estilo LCD sobre verde bosque (`Scripts/make_icon.swift`).
- 103/103 tests en verde (91 core + 12 de app: 8 integración + 4 render, dos de
  ellos nuevos para la geometría de los dígitos 7 segmentos).
- 18/20 criterios de aceptación verificados con evidencia automatizada o en
  vivo; 2 pendientes de confirmación visual (Dark/Light y animación del
  número): requieren permisos de captura de pantalla — ver
  [`acceptance.md`](openspec/changes/salary-tracker-menubar/acceptance.md).
