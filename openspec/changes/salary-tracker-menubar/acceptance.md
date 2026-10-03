# Criterios de aceptación — salary-tracker-menubar

Ejecutado: 2026-10-03 · Máquina: MacBook Pro (arm64, macOS, Xcode 26.x)
Método: tests automatizados + verificación en vivo de la app real (binario Debug
de DerivedData) + inspección de arquitectura.

> **Nota de método:** la verificación *visual* (capturas de pantalla, Dark/Light
> en pantalla, animación del número) requiere permisos de TCC (Screen Recording /
> Accessibility) que no están concedidos al entorno de ejecución; esos puntos se
> marcan como ⚠️ pendiente de confirmación visual manual. Todo lo demás está
> verificado con evidencia automatizada o inspección estática del código.

## Resultado global: 18/20 verificados · 2 pendientes de confirmación visual (base v1; ver sección v1.1–v1.3)

| # | Criterio | Estado | Evidencia |
|---|----------|--------|-----------|
| 1 | La app vive solo en la Menu Bar, sin icono en el Dock | ✅ | `INFOPLIST_KEY_LSUIElement = YES` (pbxproj); LaunchServices reporta `type="UIElement"`; proceso corre en background (`background only: true` via System Events). Visual: ⚠️ sin captura. |
| 2 | El indicador se actualiza en tiempo real, segundo a segundo | ✅ | `AppModel.startTimer()`: `Timer` de 1 s alineado al segundo con tolerance 0.2 (`AppModel.swift:95-112`); `evaluateNow()` re-deriva desde el instante exacto. Visual: ⚠️. |
| 3 | El dinero ganado crece segundo a segundo de forma proporcional | ✅ | `CalculatorTests` (crecimiento por segundo ≈ 0.5787 CLP, tolerancia 1e-9); `AppModelTests.testSaveConfigYieldsActiveStateDerivedFromInjectedClock` (avanzar clock +1 d → earned estrictamente mayor, `remainingSeconds` decrece exactamente 86 400 s). |
| 4 | Configuración de los 4 datos: monto, moneda, inicio (fecha), hora + regla de pago | ✅ | `SettingsView.swift` (350 l.): monto + selector de moneda del catálogo, fecha/hora de inicio, tipo de regla con parámetros y "próximo pago" en vivo; validación `ConfigValidator` (`Validation.swift`) con tests de aceptación/rechazo. |
| 5 | Formateo monetario por moneda (CLP 0 decimales, USD/EUR 2, JPY 0…) | ✅ | `CurrencyTests` (24 monedas ISO 4217, símbolos, decimales, redondeo halfUp, valor de entrada inmutable). Verificado en vivo: el motor formatea `$345.328` para CLP. |
| 6 | Regla "último viernes de cada mes" (y último día-X) correcta | ✅ | `PaymentSchedulesTests`: último viernes sep-2026 == 25, oct-2026 == 30, feb-2027 == 26, feb-2028 (bisiesto) == 25, sucesión dic-2026 → ene-2027, estrictidad `next > after`, hora 09:00 aplicada. Verificado en vivo: con inicio 2026-09-01, el período real hoy es `[2026-09-25, 2026-10-30)`. |
| 7 | Regla "día N del mes" con R-SKIP (día 31 salta meses cortos) | ✅ | `PaymentSchedulesTests`: día 31 sep→oct→dic→ene-2027, día 30 omite feb-2027, día 29 incluye feb-2028. |
| 8 | Regla "fecha específica": al pasarla el período queda abierto (100 %) | ✅ | `TrackerEngineTests.testOpenEndedAfterSpecificDatePassed` (ganado = sueldo, progreso 1.0, sin próximo pago); estado `openEnded` en `TrackerState`. |
| 9 | Rollover automático tras cada pago (el reset es derivación, no arbitrario) | ✅ | `RolloverTests` (rollover en el instante exacto: 0 ganado, período nuevo; pureza de la derivación); `AppModelTests.testRolloverAfterPaymentYieldsNewPeriod` (clock tras el pago → período `[25 sep, 30 oct)` con progreso ≈ 1/35). |
| 10 | Varios pagos transcurridos mientras la app estuvo cerrada (R-MULTI/R-RECOVERY) | ✅ | `RolloverTests` + `CalculatorTests` (nov-2026 → período `[2026-10-30, 2026-11-27)`; sin acumulación indefinida). |
| 11 | Cierre y reapertura: comportamiento idéntico (estado siempre derivado de config + reloj) | ✅ | `AppModelTests.testReloadRestoresPersistedConfiguration` (nueva instancia → mismo estado); no hay estado acumulado que persistir (R-RECOVERY). Verificado en vivo: la app relanzada carga la misma config y deriva el mismo valor. |
| 12 | Persistencia local (JSON atómico) que sobrevive reinicios | ✅ | `ConfigStoreAndEngineTests` (guardar/cargar idempotente, swap atómico, corrupto → error sin excepción); verificado en vivo: `config.json` escrito a mano es leído por la app real y el motor deriva `$345.328` (23 %) con reloj real. |
| 13 | Archivo corrupto → estado `INVALID`, sin crash, con mensaje | ✅ | `AppModelTests.testCorruptedFileYieldsInvalidStateWithoutCrash`; verificado en vivo: app con `config.json` corrupto sigue viva (stdout/stderr limpios, sin crash log). |
| 14 | 100 % offline, sin dependencias de terceros | ✅ | `Package.swift` sin dependencias externas; la app solo importa Foundation/AppKit/SwiftUI; no hay código de red en el repositorio. |
| 15 | Cambio de zona horaria → re-derivación inmediata (R-TZ) | ✅ | `TrackerEngineTests.testTimezoneChangeRerivesPeriod`; `AppModel.observeContextChanges()` observa `.NSSystemTimeZoneDidChange` y re-evalúa (`AppModel.swift:114-132`). |
| 16 | Casos de borde temporales: medianoche, mes, año, febrero, bisiestos | ✅ | `EdgeCasesTests` (febrero 2027 vs 2028 difieren exactamente 86 400 s; cruce de año `[2026-12-25, 2027-01-29)`; resolución multi-zona; inicio == momento de pago). Observador `.NSCalendarDayChanged` cubre la medianoche. |
| 17 | Dark Mode y Light Mode, UI premium y minimalista | ⚠️ | Implementado con estilos de sistema de SwiftUI (sin colores hardcodeados; `PopoverView.swift` 229 l. con variantes de los 5 estados). **Pendiente:** confirmación visual en ambos modos (bloqueo TCC de captura de pantalla en el entorno de ejecución). |
| 18 | Microanimación del valor creciente sin parpadeo/reflow | ⚠️ | Indicador de barra con dígitos de 7 segmentos (`DigiSeven.swift`) en verde dinero, pre-renderizados a `NSImage` non-template y expuestos vía `Image(nsImage:)` (ver fix v1.3.1): `MenuBarExtra` descarta shapes custom del label, solo conserva imágenes. El dígito se actualiza de forma discreta por tick (como reloj digital real), sin parpadeo ni re-layout; segmentos apagados visibles al 10 %. Evidencia automatizada: snapshot del status item real (PNG 137×34 px, 284 muestras opacas, template=false, ancho 85 pt). **Pendiente:** confirmación visual en ejecución. |
| 19 | Tests automatizados de toda la lógica crítica con reloj inyectable | ✅ | **99/99 en verde**: 88 core (`swift test`, XCTest vía Xcode; +7 tests de `totalEarned` en v1.3) + 11 app (`xcodebuild test` → `TEST SUCCEEDED`: 7 integración `AppModel` + 4 render `MenuBarLabel`/`DigiSeven` incluyendo `testDigiSevenLightsExpectedSegmentsPerDigit` y `testMenuBarChipFitsStatusItemHeight`). Ningún test usa el reloj del sistema. |
| 20 | Coherencia con OpenSpec como fuente de verdad | ✅ | `openspec validate salary-tracker-menubar --strict` → "Change 'salary-tracker-menubar' is valid". Los nombres de reglas (R-PAYMENT-TIME, R-SKIP, R-TZ, R-RECOVERY, R-ONESHOT…) están implementados y referenciados en el código. |

## Consumo de CPU en reposo (tarea 12.2)

Muestreo `ps -o %cpu` del proceso real cada 5 s durante **75 s** (config viva,
sin interacción):

```
t+05s: 0.30%   t+15s: 0.20%   t+25s: 0.20%   t+35s: 0.20%
t+10s: 0.30%   t+20s: 0.20%   t+30s: 0.20%   t+40s: 0.10%
t+45s: 0.20%   t+55s: 0.10%   t+65s: 0.00%
t+50s: 0.30%   t+60s: 0.10%   t+70s: 0.00%   t+75s: 0.00%
```

- Máximo: **0.30 %** · Promedio: **≈ 0.16 %** · Estable a **0.00 %** en reposo pleno.
- **Criterio < 1 % sostenido: CUMPLE** ✅
- Logs: stderr vacío; sin crash reports de `SalaryTracker` en `DiagnosticReports`.

## Verificación en vivo (app real, binario Debug)

1. Arranque sin config → proceso vivo, `type="UIElement"` (criterio 1).
2. Config viva escrita (`1.500.000 CLP`, inicio 2026-09-01 09:00, último viernes)
   → el motor (misma librería que la app) deriva para el instante real:
   período `[2026-09-25 09:00, 2026-10-30 09:00)`, ganado `$345.328` (23 %),
   restante 2 327 818 s (≈ 26.9 d) — coherente con el calendario (criterios 5, 6, 12).
3. Config corrupta → app sigue viva, estado `INVALID`, sin crash (criterio 13).
4. 75 s en reposo → CPU < 0.3 % (tarea 12.2).

## Cambios de 2026-10-03 (v1.1–v1.3, pedidos del usuario)

1. **Indicador de barra sin símbolo** (v1.1): el glifo de moneda
   (`dollarsign.circle`) sustituye al `$` del texto — la barra muestra
   `[glifo] 346.540`, no `[glifo] $346.540`. Implementado con
   `CurrencyFormatter.formatCompact` (misma política de
   decimales/redondeo/separadores, estilo `.decimal`) + test core
   `testCompactFormatHasNoSymbol`. VoiceOver conserva el formato completo con
   símbolo; el popover mantiene el símbolo. Specs: menubar-experience
   ("Indicador activo"), currency-formatting ("Indicador compacto sin símbolo").
2. **Configuración en ventana dedicada** (v1.1/v1.2): el `SettingsView` pasó
   de hoja (`.sheet`) dentro de la ventana transitoria de la barra a una
   ventana AppKit de primera clase (`SettingsWindowController`, `NSWindow`
   440×620 con `NSHostingController`). Causa del bug de cierre: al seleccionar
   en pickers, la ventana transitoria de la `MenuBarExtra` perdía el foco y se
   cerraba (y `openWindow(id:)` de SwiftUI no funciona desde `MenuBarExtra`).
   Como ventana propia no se cierra al interactuar y al hacerla key el popover
   de la barra se oculta solo. Márgenes internos 18–20 pt; selector de regla
   `.menu`. Specs: settings-view (estructura + "Estabilidad al seleccionar
   valores").
3. **Resumen + Total ganado** (v1.3): la sección "Vista previa" pasó a
   **Resumen** con filas **Sueldo base**, **Ganado este mes**, **Total ganado**
   (nuevo), Progreso y **Próximo pago solo con día/mes/año** (ej. "30 de
   octubre de 2026", `DateFmt.dateOnly`). Core: `TrackerState.totalEarned` =
   sueldos de períodos completados + ganado del período en curso (derivado del
   calendario, sin historial; 0 en `FUTURE_START`/`INVALID`; sueldo completo
   en `OPEN_ENDED`; primer período corto cuenta sueldo completo). +7 tests core
   (`CalculatorTests`, sección "Total ganado acumulado") → core 88. Verificado
   en vivo con reloj real: sueldo 1 800 000, inicio 2026-08-10 09:00, regla
   "último viernes" → total ganado `$4.017.384` (2 períodos completados
   08/28 y 09/25 + ganado parcial 417 384 del período `[09/25, 10/30)`);
   próximo pago "30 de octubre de 2026". Specs: period-engine (requirement
   "Total ganado acumulado"), settings-view (Resumen + scenario "Próximo pago
   solo día, mes y año").
4. **Dígitos de 7 segmentos en verde dinero** (v1.3): el número de la barra se
   renderiza con `DigiSeven` (segments A–G + punto decimal; apagados al 10 %
   de opacidad) en verde dinero adaptativo (barra oscura ≈ `#38D466`, barra
   clara ≈ `#0D7336`). Glifo de moneda precede al display; VoiceOver escucha el
   valor completo. Specs: menubar-experience ("Indicador activo" + scenario
   "Transición de dígitos en el display de 7 segmentos").
5. **Fix: dígitos invisibles en la barra** (v1.3.1): el usuario reportó que en
   la barra solo se veía el glifo, no los números. Diagnóstico con un snapshot
   del `NSStatusBarWindow` real (env `SALARYTRACKER_SNAPSHOT`, ya removido): el
   `NSStatusBarButton` de `MenuBarExtra` solo retenía el `Image(systemName:)`
   del label (SF Symbol 15×15 template) y descartaba el `DigiSeven` (shapes
   custom). Workaround verificado: pre-renderizar glifo + `DigiSeven` a un
   `NSImage` non-template (coloreado, escala 2) y exponerlo como
   `Image(nsImage:)` — `MenuBarExtra` sí respeta esa imagen (snapshot: ancho
   85 pt, PNG 137×34 px, 284 muestras opacas, template=false). Consecuencia:
   el cambio de dígito es discreto por tick (sin microanimación por segmento en
   la barra; scenario de spec actualizado). States `notConfigured`/`invalid`
   conservan sus símbolos de sistema. +2 tests de render (`MenuBarLabelRenderTests`)
   → app 11. Tests finales v1.2: **99/99** (88 core + 11 app).
6. Build Release + re-empaquetado de `dist/SalaryTracker.app` + reinstalación
   en `/Applications` + app corriendo con la config del usuario (PID verificado
   post-instalación) en cada versión.

## Pendientes (requieren pantalla / interacción del usuario)

- Confirmación visual del display de 7 segmentos (forma de los dígitos, verde
  dinero en barra oscura/clara, actualización discreta al cambiar de número) y
  de la sección Resumen (filas Sueldo base / Ganado este mes / Total ganado,
  próximo pago sin hora).
- Capturas del popover en los 5 estados (notConfigured, active, futureStart,
  openEnded, invalid) en Dark y Light (criterio 17).
- Secuencia manual de Configuración: guardar/descartar/cambio de moneda
  (tarea 10.2 "FASE 6") y verificación del indicador en la barra (tarea 8.3).
