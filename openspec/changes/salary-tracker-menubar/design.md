# Design — Salary Tracker Menu Bar

## Context

Proyecto nuevo sobre un directorio vacío. Restricciones y estado actual:

- Plataforma: macOS nativo (Swift). Herramienta de build: Swift Package Manager
  (`swift build` / `swift test`) para el núcleo y sus tests (headless, CI-friendly),
  y `xcodebuild` con `.xcodeproj` para la app de Menu Bar (bundle `.app` con
  `LSUIElement`).
- Swift 6.3 / Xcode 26 / SDK macOS 26; deployment target de la app: macOS 13.0
  (mínimo para `MenuBarExtra`).
- No hay dependencias de terceros: solo Foundation, SwiftUI y AppKit.
- El requerimiento exige que la lógica financiera/temporal sea determinista,
  testeable y completamente separada de la UI, y que la fecha/hora se resuelva con
  APIs de calendario reales (sin aritmética 30 días / 24 horas).
- Ver proposal.md para el porqué y la lista de reglas explícitas (R-*) que resuelven
  las ambigüedades del requerimiento.

## Goals / Non-Goals

**Goals:**

- Núcleo 100% puro (sin imports de UI/AppKit/SwiftUI) con tests exhaustivos usando
  reloj inyectable.
- Un solo pipeline de datos: `Config + instant → PeriodState` (función pura) consumido
  por la UI; la UI nunca calcula.
- App de Menu Bar ligera: un tick por segundo, sin CPU sostenida.
- Reglas de pago registrables (`PaymentSchedule` protocol) para extender sin tocar el
  motor.
- Persistencia local atómica y offline.

**Non-Goals (v1):**

- Múltiples contratos/perfiles; sincronización en la nube; widgets de Notificación
  Center o de la pantalla de bloqueo; auto-arranque al iniciar sesión (se documenta
  cómo habilitarlo manualmente); reglas semanales/quincenales (la arquitectura las
  permite, pero no se implementan en v1); i18n completo (UI en español; formato de
  moneda según locale del sistema).

## Decisions

### D1 — Paquetes y targets

- **`SalaryTrackerCore`** (library SwiftPM, sin dependencias): dominio puro —
  `SalaryConfig`, `Clock` protocol, `SalaryCalculator`, `PaymentSchedule` protocol +
  `LastWeekdayOfMonthSchedule`, `MonthDaySchedule`, `SpecificDateSchedule`,
  `PaymentScheduleRegistry`, `AppState`/`PeriodState`/`TrackerState`, `CurrencyCatalog`
  + `CurrencyFormatter`.
- **`SalaryTrackerCoreTests`** (test target SwiftPM): tests de toda la lógica con
  `ManualClock`.
- **`SalaryTrackerApp`** (app target en `SalaryTracker.xcodeproj`, bundle id
  `dev.triton.salarytracker`): depende de `SalaryTrackerCore` por referencia local de
  paquete; contiene solo orquestación (app state observable, timer, persistencia
  `ConfigStore`, vistas SwiftUI). `LSUIElement = YES` (sin Dock).
- Razón: el requisito "probar la lógica sin ejecutar la GUI" se satisface de forma
  natural con `swift test`; la app queda delgada y fácil de auditar.
- Alternativa descartada: todo en un solo Xcode project con framework interno. Se
  descarta porque complica los tests headless y el build del núcleo.

### D2 — Modelo de dominio

```
struct SalaryConfig: Codable, Equatable {
    var salaryAmount: Decimal          // monto total del período
    var currencyCode: String           // ISO 4217
    var contractStartDate: LocalDate   // year, month, day (componentes locales)
    var contractStartTime: LocalTime   // hour, minute
    var paymentRule: PaymentRule       // enum codificable con parámetros
}

enum PaymentRule: Codable, Equatable {
    case lastWeekdayOfMonth(weekday: Int)   // v1: viernes = 5 (ISO-8601 weekday)
    case monthDay(day: Int)                 // 1...31 (R-SKIP)
    case specificDate(LocalDate)            // una sola fecha (R-ONESHOT)
}
```

- `LocalDate`/`LocalTime` son structs de componentes (Codables propios) para cumplir
  R-TZ: se almacenan componentes locales y se resuelven contra
  `TimeZone.current` en cada evaluación. No se almacenan `Date`/UTC absolutos porque
  un cambio de zona horaria del sistema tendría que re-interpretar el valor.
- Monto como `Decimal` para exactitud decimal; la interpolación temporal se hace en
  `Double` (segundos) y el resultado final se multiplica sobre el `Decimal` del
  sueldo (o equivalente en `Double` con verificación de acotación `[0, sueldo]`; la
  precisión de 53 bits de `Double` sobra para montos reales).

### D3 — `Clock` e inyectabilidad

```
protocol Clock { var now: Date { get } }
struct SystemClock: Clock { ... }              // Date()
struct ManualClock: Clock { var date: Date }   // tests
```

`SalaryCalculator.evaluate(config:rule:instant:calendar:timeZone:)` es **pura**:
recibe el instante explícitamente y no lee el reloj. La UI inyecta `SystemClock`.
Razón: tests deterministas (regla del proposal "no depender del reloj real") y
posibilidad de simular suspensiones/avances de tiempo.

### D4 — Algoritmo del motor (período actual y rollover)

```
func evaluate(config, rule, now) -> TrackerState:
    if config.salaryAmount <= 0: return .invalid("sueldo")
    start0 = resolve(config.contractStart)            // en TimeZone.current (R-TZ)
    if now < start0:
        return .futureStart(startsAt: start0,
                            firstPayment: rule.next(after: start0))
    switch rule:
    case .specificDate(let day):
        pay = resolve(day)
        if pay <= start0: return .invalid("pago anterior al inicio")
        if now < pay:    return .active(start: start0, end: pay)
        else:            return .openEnded(salary)
    case recurrent:
        // cadena estricta: p1 < p2 < p3 ...  (R-RECOVERY, acotada)
        pPrev = nil
        p     = rule.next(after: start0)              // estricto: > start0
        while let p2 = rule.next(after: p), p2 <= now { pPrev = p; p = p2 }
        periodStart = pPrev ?? start0                 // último pago ≤ now, o start0
        return .active(start: periodStart, end: p)    // earned = salary*(now-start)/(p-start)
```

Detalles que garantizan los invariantes:

- El `while` está acotado: ≤ ~12 iteraciones por año transcurrido; con salto por
  años (saltar meses cuando `now` está lejos de `start0`) queda en O(años) y es < 5 ms
  incluso para inicios en 2000. Nunca se repite un pago (sucesión estrictamente
  creciente), por lo que no hay riesgo de bucle infinito.
- "Primer pago estrictamente posterior" (`next(after:)` estricto) evita el período
  cero-duración cuando el inicio coincide con un momento de pago (escenario del
  spec).
- El rollover no es un evento: es la consecuencia de evaluar con un `now` mayor al
  fin del período. No hay estado mutante.
- Período abierto (`OPEN_ENDED`): solo con `specificDate` tras su momento;
  `earned = salary`, `progress = 1.0`, `nextPayment = nil`.
- `INVALID`: `salaryAmount <= 0` → se reporta error de validación; el motor no
  evalúa (la app conserva el último estado válido, R-LIVE/inv).

### D5 — Reglas de pago (`PaymentSchedule`)

```
protocol PaymentSchedule {
    /// Primer momento de pago estrictamente posterior a `after`, a la hora de
    /// referencia (`payClock` = hora del inicio del contrato, R-PAYMENT-TIME),
    /// o nil si la regla no tiene sucesores.
    func nextPayment(after: Date, payClock: (hour: Int, minute: Int),
                     calendar: Calendar) -> Date?
    var label: String { get }
}
```

Implementaciones v1:

- `LastWeekdayOfMonthSchedule(weekday:)`: último día-semana del mes. Algoritmo:
  tomar el final del mes conteniendo/`after` el candidato, buscar hacia atrás el
  último día con `weekday == weekday`; si el resultado ≤ `after`, avanzar al mes
  siguiente. Sin aritmética 7/30.
- `MonthDaySchedule(day:)`: día N del mes de `after` (o siguiente si ya pasó) a la
  hora de referencia; si N > días del mes → siguiente mes con N existente (R-SKIP).
- `SpecificDateSchedule(date: LocalDate)`: un único momento (fecha + hora de
  referencia); `next(after:)` devuelve nil si el candidato ya pasó.

`PaymentScheduleRegistry`: mapea `PaymentRule` → instancia; agregar una nueva regla
= nueva struct + nuevo case + entrada en el registry (cumple el escenario
"Nueva regla sin tocar el motor").

### D6 — Estados de la app

```
enum TrackerState: Equatable {
    case notConfigured
    case invalid(message: String)
    case futureStart(startsAt: Date, firstPayment: Date?)
    case active(PeriodView)        // start, end, salary, earned, progress, remaining
    case openEnded(salary: Decimal, currencyCode: String)
}
```

`PeriodView` contiene todo lo que la UI necesita (incluyendo textos formateados o
inputs para formatearlos). La transición entre casos ocurre exclusivamente al
re-evaluar (máx. 1 s de latencia). No hay estado "PAYMENT_REACHED" persistente: en el
instante exacto del pago el estado es ya `active` del período nuevo (o
`openEnded`), lo cual cubre el requisito de "no acumular indefinidamente" sin un
estado intermedio.

### D7 — UI y temporización

- `MenuBarExtra("…", ...) { PopoverView() }.menuBarExtraStyle(.window)` — popover
  como window (permite el diseño custom premium; el estilo `.menu` no permite
  layouts libres).
- `@MainActor final class AppModel: ObservableObject` (o `@Observable` según target):
  - `state: TrackerState`, `config: SalaryConfig?`
  - `tick()`: `now = clock.now` → `state = calculator.evaluate(...)` → publica.
  - Timer: `Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true)` alineado al
    segundo (el primer fire se alinea al próximo tick de segundo completo para
    evitar saltos); `tolerance = 0.2`. Alternativa evaluada: `TimelineView(.periodic)`
    solo para el popover visible; se combina: timer global de 1 s (barra siempre
    actual) + `TimelineView` opcional si el popover está abierto (no necesario en v1).
  - Re-evaluación inmediata (sin esperar tick) ante: `NSScreen.screens`/cambio de
    `TimeZone`, `NSCalendarDayChanged` (cruce de medianoche), cambio de `NSApp`
    active/appear (despertar de suspensión), y guardado de configuración.
- CPU: un tick por segundo con trabajo O(años+meses) despreciable; el timer con
  tolerance permite coalescing del sistema. No hay trabajo en background.
- Menos de 1 % de CPU objetivo en reposo (verificación manual en FASE 7).

### D8 — Persistencia

- `ConfigStore` (AppKit/App target): archivo JSON en
  `Application Support/SalaryTracker/config.json` (o sandbox `Application Support`;
  sin sandbox en v1, firmado ad-hoc).
- Escritura **atómica**: serializar → escribir a temp file en el mismo directorio →
  `replaceItem` (equivalente `dispatch_io`/`FileManager.replaceItemAt`); el archivo
  anterior permanece válido hasta el swap (escenario "escritura atómica").
- Versión del schema (`"v": 1`) para migraciones futuras.
- Carga en launch: si no existe → `notConfigured`; si es corrupto → `invalid`
  (mensura) + respeta último backup.

### D9 — Formato de moneda

- `CurrencyCatalog`: lista fija (24 monedas del spec) con `code`, `symbol`,
  `minorUnitDecimals`, `localizedNames`. Símbolos desde `Locale`
  (`currencySymbol`) con fallback al catálogo (R-CURRENCY).
- `CurrencyFormatter`: envuelve `NumberFormatter` (`.currency` style, `currencyCode`
  fija, locale del sistema, decimales forzados por moneda, `roundingMode = .halfUp`
  de presentación). Función pura `format(Decimal, code) -> String`; el motor no la
  usa (separación cálculo/presentación, R-PRECISION).

### D10 — Estructura del código

```
SalaryTracker/
├─ Package.swift                     # SalaryTrackerCore + tests
├─ Sources/SalaryTrackerCore/
│  ├─ Clock.swift
│  ├─ Models/            (SalaryConfig, LocalDate, LocalTime, PaymentRule,
│  │                      TrackerState, PeriodView)
│  ├─ Schedules/         (PaymentSchedule, LastWeekdayOfMonthSchedule,
│  │                      MonthDaySchedule, SpecificDateSchedule, Registry)
│  ├─ SalaryCalculator.swift
│  ├─ Validation.swift   (validación de config + mensajes)
│  └─ Currency/          (CurrencyCatalog, CurrencyFormatter)
├─ Tests/SalaryTrackerCoreTests/
│  ├─ SchedulesTests.swift
│  ├─ CalculatorTests.swift
│  ├─ RolloverTests.swift
│  ├─ EdgeCasesTests.swift   (febrero, bisiestos, año nuevo, TZ, inicio futuro, ...)
│  ├─ ValidationTests.swift
│  └─ CurrencyTests.swift
└─ App/
   ├─ SalaryTracker.xcodeproj
   └─ SalaryTrackerApp/
      ├─ SalaryTrackerApp.swift      # @main, MenuBarExtra
      ├─ AppModel.swift              # ObservableObject + timer + re-derivación
      ├─ ConfigStore.swift           # persistencia atómica
      └─ Views/          (IndicatorLabel, PopoverView, ProgressGauge,
                          SettingsView, PreviewSection)
```

## Risks / Trade-offs

- **[`MenuBarExtra` con `.window` y animaciones]** Puede redibujar el popover en
  cada tick → Mitigación: solo el texto del número cambia; usar `contentTransition`
  sutil y `TimelineView`/`Text` con monospace figures para evitar reflow; validar
  visualmente en FASE 7.
- **[Cambio de TZ re-deriva el período]** El período puede "saltar" ±horas al
  cambiar de zona. Es comportamiento especificado (R-TZ) y deseable; se documenta en
  el popover (el período se muestra en hora local actual).
- **[Búsqueda de período O(años)]** Con inicio de contrato muy lejano (p. ej. 2000)
  la primera evaluación itera ~1000 pagos → Mitigación: salto por años (D4); en
  cualquier caso < 5 ms una sola vez.
- **[`Date` vs componentes locales]** Almacenar componentes (D2) sacrifica la
  posibilidad de mostrar "el instante absoluto original" si el usuario cambia de
  zona; a cambio cumple R-TZ y R-RECOVERY. Decisión aceptada y documentada.
- **[Sin sandbox/ad-hoc signing]** La app no es distribuible en App Store en v1;
  para uso local es suficiente y se mantiene el pipeline de build simple.
- **[`Decimal` vs `Double` en interpolación]** Se usa `Double` para los intervalos y
  `Decimal` para el sueldo; el producto final se redondea a la unidad menor de
  presentación (R-PRECISION) — el error de redondeo es < 0.005 de la unidad menor,
  imperceptible y acotado.

## Migration Plan

Proyecto nuevo: sin migración. Plan de despliegue:

1. `swift build` + `swift test` (núcleo) — CI local.
2. `xcodebuild -scheme SalaryTracker -configuration Release build` → `.app` en
   `dist/`.
3. Instalación manual: mover `SalaryTracker.app` a `/Applications` (se documenta en
   README). Rollback: borrar el `.app`; los datos están en
   `~/Library/Application Support/SalaryTracker/`.

## Open Questions

- Nombre final del producto y del bundle (v1: "Salary Tracker",
  `dev.triton.salarytracker`). No afecta specs ni arquitectura.
- Auto-arranque al login: out-of-scope v1 (se habilita manualmente en Ajustes del
  sistema). No afecta specs.
