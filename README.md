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
│   ├── Sources/SalaryTrackerCore/    # modelo, reglas de pago, motor, validación, monedas, ConfigStore
│   ├── Tests/SalaryTrackerCoreTests/ # 88 tests (XCTest) con reloj manual
│   ├── Scripts/make_icon.swift       # genera App/AppIcon.icns desde cero
│   └── App/
│       ├── SalaryTracker.xcodeproj   # target de app macOS 13+ (LSUIElement) + target de tests
│       ├── SalaryTrackerApp/         # @main, AppModel, SettingsWindowController, Views/*, AppIcon.icns
│       └── SalaryTrackerTests/       # 9 tests de app (7 integración AppModel + 2 render)
└── openspec/                         # fuente de verdad del diseño
    ├── config.yaml
    ├── specs/                        # specs vivas (capacidades)
    └── changes/salary-tracker-menubar/  # propuesta: design, 6 specs, tasks, acceptance.md
```

Lo que **no** se versiona (ver [`.gitignore`](.gitignore)): `.build/`,
`.swiftpm/`, `SalaryTracker/App/build/`, `SalaryTracker/dist/` (el `.app`
Release), `*.profraw`, `.idea/`, `.opencode/` y `.DS_Store`.

## Requisitos

- macOS 13+ (los builds se hicieron con macOS 26 / Xcode 26).
- **Importante:** si tu toolchain activo es CommandLineTools, `swift test`
  fallará (sin XCTest). Usa Xcode con `DEVELOPER_DIR`, o ejecuta una vez:
  `sudo xcode-select -s /Applications/Xcode.app`

## Build

```bash
cd SalaryTracker

# 1) Build + tests de la librería core (88 tests)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# 2) Build de la app (Debug o Release)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project App/SalaryTracker.xcodeproj -scheme SalaryTracker \
  -configuration Release build
```

## Tests

```bash
# Core: 88 tests
cd SalaryTracker
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# App: 11 tests (7 de integración de AppModel + 4 de render del indicador)
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
- La app **solo escribe** el archivo cuando guardas en Configuración
  (swap atómico); un archivo corrupto produce estado `INVALID`, nunca un crash.

## Estado del proyecto (2026-10-03)

- **v1.2** — rediseño visual botanical/LCD tomado de la landing: chip oscuro en
  la barra, popover con panel LCD y tarjetas, y ventana de configuración con
  campos y acciones verdes.
- 99/99 tests en verde (88 core + 11 de app: 7 integración + 4 render, dos de
  ellos nuevos para la geometría de los dígitos 7 segmentos).
- 18/20 criterios de aceptación verificados con evidencia automatizada o en
  vivo; 2 pendientes de confirmación visual (Dark/Light y animación del
  número): requieren permisos de captura de pantalla — ver
  [`acceptance.md`](openspec/changes/salary-tracker-menubar/acceptance.md).
