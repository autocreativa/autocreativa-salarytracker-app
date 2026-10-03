# Estado: 32/32 ítems completos. Pendientes: solo confirmación visual/interacción manual (8.3, 9.1, 9.2, 10.1, 10.2 — bloque TCC de captura). Cierre de FASE 6 documentado en `acceptance.md`, que incluye los cambios de usuario v1.1–v1.3: barra sin símbolo, settings en ventana dedicada (AppKit), Resumen con "Total ganado" (core `totalEarned` + 7 tests) y dígitos de 7 segmentos en verde dinero (`DigiSeven`).

## 1. Setup del proyecto

- [x] 1.1 Crear el paquete SwiftPM `SalaryTrackerCore` (library) en `SalaryTracker/Package.swift` con target de tests `SalaryTrackerCoreTests` y verificar que `swift build` y `swift test` corren (test trivial de humo pasa) — 81 tests core en verde (requiere toolchain de Xcode: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`)
- [x] 1.2 Crear `SalaryTracker.xcodeproj` con target de app `SalaryTracker` (macOS 13+, `LSUIElement`) que depende del paquete local `SalaryTrackerCore`, y verificar que `xcodebuild -scheme SalaryTracker build` compila la app — **Nota:** el pbxproj original a mano omitía la `PBXFrameworksBuildPhase` (el producto del paquete no se vinculaba → "Unable to resolve module dependency"); corregido el 2026-10-03. Build Debug y Release: `BUILD SUCCEEDED`.

## 2. Modelos de dominio (core)

- [x] 2.1 Implementar `LocalDate`, `LocalTime`, `SalaryConfig` y `PaymentRule` (Codable/Equatable) con helpers de conversión a `Date` dado `Calendar`+`TimeZone` (regla R-TZ) y verificar con tests de codificación/descodificación y de resolución de fechas
- [x] 2.2 Implementar `Clock` (protocol), `SystemClock` y `ManualClock` y verificar que `ManualClock` permite fijar/avanzar el instante en los tests

## 3. Reglas de pago (core)

- [x] 3.1 Implementar el protocol `PaymentSchedule` (`nextPayment(after:payClock:calendar:)`, `label`) y `PaymentScheduleRegistry` que mapea `PaymentRule` → instancia, y verificar que el registry resuelve las 3 reglas v1 (`testRegistryResolvesAllRules`)
- [x] 3.2 Implementar `LastWeekdayOfMonthSchedule` (último día-semana del mes, sin aritmética 7/30) y verificar con tests: último viernes sep-2026 == 25, oct-2026 == 30, feb-2027 == 26, feb-2028 (bisiesto) == 25, sucesión dic-2026 → ene-2027 == 2027-01-29, estrictidad (`next` > `after`), y hora de referencia 09:00 aplicada
- [x] 3.3 Implementar `MonthDaySchedule` (día N del mes con R-SKIP) y verificar con tests: día 25 normal, día 31 salta meses cortos, día 30 omite feb-2027, día 29 incluye feb-2028
- [x] 3.4 Implementar `SpecificDateSchedule` (una fecha; `next` nil tras pasar) y verificar con tests: devuelve la fecha si posterior, nil si anterior, y etiqueta legible

## 4. Motor de cálculo (core)

- [x] 4.1 Implementar `SalaryCalculator.evaluate(config:rule:now:calendar:timeZone:)` puro produciendo `TrackerState` con `PeriodView` y verificar: período base sep-2026, mitad exacta == 50 % (750.000 CLP), instante inicial == 0, un segundo antes < sueldo, crecimiento por segundo ≈ 0.5787
- [x] 4.2 Implementar el rollover por derivación y verificar con tests: rollover en el instante exacto, evaluación tras 1 día del pago (1/35 del sueldo), varios pagos transcurridos, sin acumulación indefinida
- [x] 4.3 Cubrir estados `FUTURE_START`, `OPEN_ENDED` y `INVALID` y verificar con tests
- [x] 4.4 Verificar invariancia (doble evaluación determinista) y que `earned` ∈ `[0, sueldo]` con batería de instantes (`testEarnedBoundedOverRandomInstants`)

## 5. Casos de borde temporales (core)

- [x] 5.1 Verificar febrero y bisiestos (28 vs 29 días, diferencia exacta 86 400 s)
- [x] 5.2 Verificar cruce de año (`testPeriodCrossesYearBoundary`)
- [x] 5.3 Verificar resolución con zona horaria distinta (`testSameLocalComponentsDifferentTimeZones`, `testPeriodDerivedWithRespectiveTimeZones`)
- [x] 5.4 Verificar "inicio coincide con momento de pago" (`testStrictnessWhenQueryMatchesPaymentMoment`)

## 6. Validación (core)

- [x] 6.1 Implementar `ConfigValidator` con mensajes de error específicos y verificar con tests de cada regla de rechazo y de aceptación

## 7. Monedas (core)

- [x] 7.1 Implementar `CurrencyCatalog` (24 monedas ISO 4217) y verificar con tests: CLP=0, USD=2, JPY=0 decimales, presencia de todas las monedas del spec
- [x] 7.2 Implementar `CurrencyFormatter` y verificar con tests: 1500000 CLP sin decimales, 1500 USD con 2, redondeo halfUp, 1500 EUR, valor de entrada inmutable

## 8. Capa de aplicación (app target)

- [x] 8.1 Implementar `ConfigStore` (JSON en Application Support, escritura atómica, versión de schema) y verificar con tests: guardar/cargar idempotente, corrupto → error sin excepción, swap atómico, escritura concurrente sin archivo parcial (`testConcurrentWritesNeverLeavePartialFile`)
- [x] 8.2 Implementar `AppModel` (`@MainActor ObservableObject`): carga inicial, `tick()`/`evaluateNow()`, timer 1 s alineado, observadores de TZ/medianoche/despertar, publicar `TrackerState`+`config` — y test de integración con reloj manual: **nuevo target `SalaryTrackerTests` (2026-10-03) con 7 tests** (notConfigured, active + avance de clock, rollover, invalid, futureStart, corrupto, recarga persistida) → `xcodebuild test` = `TEST SUCCEEDED`
- [x] 8.3 Implementar la entrada `@main` con `MenuBarExtra` (estilo `.window`, `LSUIElement`) y el indicador de barra — verificado en vivo: proceso corre como `UIElement` de LaunchServices, vivo tras arrances múltiples, sin crash logs. (Confirmación visual del glifo en pantalla: pendiente por TCC, ver `acceptance.md`.)

## 9. Popover (app target)

- [x] 9.1 Implementar `PopoverView` (229 l.): valor dominante, período, próximo pago, tiempo restante, sueldo, barra de progreso con %, botón Configuración; variantes de los 5 estados; estilos de sistema (Dark/Light) — **Pendiente:** verificación visual con capturas (bloqueada por permisos TCC del entorno; código implementado y compilado)
- [x] 9.2 Implementar la microanimación de crecimiento (`.contentTransition(.numericText())` + dígitos monoespaciados, `MenuBarLabel.swift:40-42`) — **Pendiente:** confirmación visual en ejecución

## 10. Vista de configuración (app target)

- [x] 10.1 Implementar `SettingsView` (350 l.): secciones Sueldo, Inicio, Día de pago (tipo + parámetros + próximo pago en vivo) y Vista previa — **Pendiente:** confirmación visual de apertura/cierre en los 5 estados
- [x] 10.2 Cablear validación + guardado (Guardar habilitado solo si válido, vista previa recalculada en vivo, descartar no persiste) — **Pendiente:** secuencia manual guardado/descarte/cambio de moneda (requiere interacción en pantalla)

## 11. Empaquetado y verificación end-to-end

- [x] 11.1 Compilar release, generar `dist/SalaryTracker.app` (con `AppIcon.icns` e `Info.plist` correcto: `LSUIElement=true`, `dev.triton.salarytracker`, v1.0) y verificar que abre desde `/Applications` y persiste tras reinicio — hecho el 2026-10-03: instalada en `/Applications/SalaryTracker.app`, relanzada tras cierre, `config.json` inmutable (md5), estado derivado idéntico y ganado crecido con el reloj real
- [x] 11.2 Ejecutar la batería completa y verificar 100 % de tests en verde — **97/97**: 88 core (`swift test`, +7 tests de `totalEarned` en v1.3) + 9 app (`xcodebuild test` → `TEST SUCCEEDED`: 7 `AppModel` + 2 render `MenuBarLabel`/`DigiSeven` del fix v1.3.1), 2026-10-03 (re-verificado tras v1.3.1)
- [x] 11.3 Pasar `openspec validate salary-tracker-menubar --strict` — "Change 'salary-tracker-menubar' is valid" (2026-10-03)

## 12. Validación contra criterios de aceptación (FASE 6-7)

- [x] 12.1 Ejecutar la app y verificar los 20 criterios de aceptación y registrar en `acceptance.md` — **18/20 verificados con evidencia; 2 (Dark/Light y animación) pendientes de confirmación visual** (bloque TCC de captura de pantalla en el entorno de ejecución)
- [x] 12.2 Medir consumo de CPU en reposo (muestra de 75 s, muestreo cada 5 s) — máximo 0.30 %, promedio ≈ 0.16 %, 0.00 % en reposo pleno; < 1 % sostenido ✅; logs limpios, sin crash reports
- [x] 12.3 Revisión final de arquitectura y calidad: separación core/UI verificada (core sin imports de UI; 88 tests sin reloj real), README de build/run/test creado, `swift test` verde, OpenSpec sigue siendo fuente de verdad
