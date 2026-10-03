## Why

No existe una utilidad nativa de macOS que muestre de forma continua, en la barra de
menú, cuánto dinero se ha generado dentro del período de pago actual. El usuario quiere
ver, segundo a segundo, el crecimiento de su sueldo entre el inicio del período y el
pago, sin depender de una app de terceros, con funcionamiento 100% offline y local.

## What Changes

- Nueva aplicación nativa de macOS (Swift) que vive exclusivamente en la Menu Bar
  (sin icono en el Dock) y muestra el dinero ganado del período actual en tiempo real.
- Motor de cálculo determinista y desacoplado de la UI que, a partir de
  (sueldo, inicio del contrato, regla de pago, reloj) determina el período actual,
  el próximo pago, el tiempo transcurrido, el porcentaje de progreso y el dinero
  ganado, con rollover automático tras cada pago (el reset es consecuencia directa de
  la lógica temporal, nunca un reset arbitrario).
- Reglas de pago extensibles: "último viernes de cada mes" (y último día-X del mes),
  "día N de cada mes" y "fecha específica de pago" (próximo pago), con arquitectura
  que permite agregar más reglas sin modificar el motor.
- Configuración completa (monto, moneda ISO, fecha y hora de inicio del contrato,
  regla de pago) validada antes de guardar, persistida localmente y 100% offline.
- Formateo monetario correcto por moneda (CLP, USD, EUR, etc.) usando el catálogo
  ISO 4217 del sistema; la moneda solo afecta la presentación, nunca el cálculo.
- UI premium y minimalista: indicador compacto en la Menu Bar, popover con el valor
  dominante, período, próximo pago, tiempo restante, barra de progreso y acceso a la
  vista de configuración; Dark Mode y Light Mode; animación sutil del valor creciente.
- Pruebas automatizadas de toda la lógica crítica con reloj inyectable (sin depender
  del reloj real del sistema).

## Capabilities

### New Capabilities

- `period-engine`: Motor determinista de períodos de pago y cálculo de dinero ganado
  (período actual, próximo pago, tiempo transcurrido, porcentaje, rollover, estados).
- `payment-schedules`: Reglas de calendario de pago (último día-X del mes, día N del
  mes, fecha específica) con resolución de próximos pagos y fecha límite mensual.
- `configuration`: Modelo de configuración, validación, persistencia local y
  reconstrucción del estado al iniciar la aplicación.
- `currency-formatting`: Catálogo de monedas ISO 4217, representación simbólica y
  formato numérico por moneda (decimales, separadores).
- `menubar-experience`: Indicador de Menu Bar, popover en tiempo real, actualización
  periódica eficiente, manejo de estados en la UI, suspensiones y cambios de zona
  horaria.
- `settings-view`: Vista de configuración (sueldo, moneda, inicio, regla de pago,
  vista previa, validación y guardado).

### Modified Capabilities

(ninguna — proyecto nuevo)

## Impact

- Código nuevo: paquete Swift (`SalaryTrackerCore` pura, sin dependencias de UI) y
  aplicación de Menu Bar (`SalaryTrackerApp`), más tests (`SalaryTrackerCoreTests`).
- Sin dependencias externas de terceros; solo frameworks nativos de macOS
  (Foundation, AppKit/SwiftUI).
- Persistencia local en el contenedor de datos de la app (JSON), sin red.
- Requisitos: macOS con SwiftUI `MenuBarExtra` (macOS 13+).

## Análisis del requerimiento — ambigüedades y reglas explícitas

Se identificaron las siguientes ambigüedades en el requerimiento. Cada una se resuelve
con una regla explícita que se incorpora a la especificación (no se asume
silenciosamente):

- **A1 — Hora del momento de pago.** El requerimiento define el *día* de pago pero no
  su *hora*. **Regla R-PAYMENT-TIME:** el momento de pago ocurre en la misma hora que
  la hora de inicio del contrato (p. ej. inicio 09:00 → pago cada último viernes a las
  09:00). El inicio del período siguiente coincide con ese momento exacto, de modo que
  no exista intervalo muerto ni solapamiento entre períodos.
- **A2 — Regla "próximo día de pago".** Se interpreta como **una fecha específica de
  pago** elegida por el usuario (no recurrente). **Regla R-ONESHOT:** el período
  termina en esa fecha (a la hora de inicio del contrato); a partir de entonces el
  período se considera **abierto** (sin próximo pago definido): el dinero ganado se
  mantiene igual al sueldo (100%) y la UI indica que no hay próximo pago. La
  arquitectura permite agregar reglas recurrentes adicionales después.
- **A3 — Primera ejecución / sin configuración.** **Regla R-BOOT:** sin
  configuración la app queda en estado `NOT_CONFIGURED`; la Menu Bar muestra un
  indicador estático (sin dinero) y el popover muestra una invitación a configurar.
  El motor nunca se ejecuta con datos inexistentes.
- **A4 — Inicio del contrato en el pasado.** **Regla R-FIRST-PERIOD:** el primer
  período inicia en el inicio del contrato y su pago es el **primer** momento de pago
  estrictamente posterior al inicio del contrato. Se asume que el usuario ya recibió
  pagos anteriores a la instalación de la app (no se retroceden períodos ni se
  acumulan salarios de meses pasados).
- **A5 — Inicio del contrato en el futuro.** **Regla R-FUTURE:** estado
  `FUTURE_START`; dinero ganado = 0, sin progreso; al llegar el inicio el período
  empieza automáticamente.
- **A6 — Fecha de pago imposible (día 31 en mes corto).** **Regla R-SKIP:** si el
  día N no existe en el mes, el pago se resuelve al **próximo mes** en el que exista.
  (Alternativa descartada: truncar al último día del mes, porque cambiaría el monto
  real del período de forma silenciosa.)
- **A7 — Configuración inválida.** **Regla R-INVALID:** sueldo ≤ 0 o datos de fecha
  incompletos producen estado `INVALID_CONFIGURATION`; el último estado válido se
  conserva en la UI con aviso; el guardado falla con mensajes de error.
- **A8 — Zona horaria.** **Regla R-TZ:** toda la configuración se almacena como
  componentes de fecha/hora **local** (p. ej. 09:00). El cálculo resuelve los
  componentes en la zona horaria **actual del sistema** en cada evaluación, por lo
  que un cambio de zona horaria se refleja inmediatamente y consistentemente, sin
  recálculo de datos almacenados.
- **A9 — Precisión.** **Regla R-PRECISION:** el cálculo interno usa intervalos de
  tiempo exactos (segundos fraccionarios, `Double`); la presentación redondea a la
  unidad menor de la moneda (CLP: 0 decimales; USD/EUR: 2). El valor mostrado nunca
  excede el sueldo del período.
- **A10 — Pago mientras la app está cerrada o el Mac suspendido.** **Regla
  R-RECOVERY:** el período actual se **deriva siempre** de (configuración + reloj
  actual) al evaluar, avanzando la cadena de pagos hasta el primero que sea posterior
  al tiempo actual (búsqueda acotada, ≤ ~10 años hacia adelante). No hay estado
  acumulado que persistir más allá de la configuración; por tanto el comportamiento
  es idéntico después de cierres, reinicios, suspensiones o cambios de hora.
- **A11 — Último viernes (o último día-X) del mes.** **Regla R-LASTWD:** se resuelve
  con la API de calendario (no con aritmética 7/30): se busca el último día de la
  semana X dentro del mes; existen 3 o 4 por mes según el calendario gregoriano.
- **A12 — Febrero y años bisiestos.** **Regla R-CAL:** todo el cálculo de fechas usa
  un calendario gregoriano nativo con la zona horaria actual; no se usan
  aproximaciones de 30 días/24 horas para nada que involucre fechas.
- **A13 — Monedas.** **Regla R-CURRENCY:** se almacena el código ISO 4217. El símbolo
  y el formato provienen del catálogo nativo del sistema (CLP sin decimales, USD/EUR
  con 2, JPY con 0, etc.). La lista de selección incluye un catálogo amplio fijo
  (incluye CLP, USD, EUR, GBP, ARS, BRL, MXN, JPY y más); la lógica numérica es
  independiente de la moneda.
- **A14 — Cambio de configuración durante un período activo.** **Regla R-LIVE:** los
  cambios guardados toman efecto **inmediato**: el período se re-deriva con la
  nueva configuración (p. ej. cambiar el inicio del contrato reinicia el período en
  ese nuevo inicio). No se conservan "ganancias congeladas".
- **A15 — Rollover múltiple (varios pagos transcurridos).** **Regla R-MULTI:** si
  transcurrieron N pagos mientras la app estuvo cerrada, el período actual es el que
  sigue al **último** pago transcurrido (R-RECOVERY lo cubre de forma natural).

## Casos de borde (cubiertos por la especificación)

1. Inicio de la app por primera vez (A3). 2. Sin configuración (A3).
3. Modificación del sueldo (A14). 4. Modificación de la moneda (A13, presentación
   solo). 5. Modificación del inicio del contrato (A14). 6. Modificación del día de
   pago (A14). 7-8. Cierre y reapertura (A10). 9-10. Suspensión y despertar del Mac
   (A10: el valor se deriva del reloj al evaluar; no hay catch-up de "tiempo perdido"
   porque el tiempo transcurrido es absoluto). 11. Cambio de zona horaria (A8).
12. Cruce de medianoche (A12). 13. Cruce de mes (A12, A11). 14. Febrero (A12, A6).
15. Año bisiesto (A12). 16. Último viernes del mes (A11). 17. Inicio posterior al
   momento actual (A5). 18. Fecha de pago ya pasada (A6, A4). 19. Pago con app
   cerrada (A10). 20. Pago durante suspensión (A10). 21. Cambio de configuración en
   período activo (A14).
