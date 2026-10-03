## Purpose

Deriva de manera determinista, a partir de (sueldo, inicio del contrato, regla de pago
y un instante dado) el período de pago actual, el próximo pago, el tiempo transcurrido,
el porcentaje de progreso y el dinero ganado, incluyendo el rollover automático al
completarse un período, sin aproximaciones de días ni de horas.

## ADDED Requirements

### Requirement: Determinación del período actual
El motor SHALL determinar el período actual como el intervalo `[inicio, próximoPago)`
donde `inicio` es el inicio del contrato o el último momento de pago que sea anterior
o igual al instante de evaluación, y `próximoPago` es el primer momento de pago de la
regla que sea estrictamente posterior a `inicio`. El sueldo configurado representa el
monto total que corresponde a ese período completo.

#### Scenario: Período dentro del primer mes tras el inicio del contrato
- **WHEN** el inicio del contrato es 2026-09-01 09:00, la regla es "último viernes de cada mes" y el instante de evaluación es 2026-09-10 09:00
- **THEN** el período actual es `[2026-09-01 09:00, 2026-09-25 09:00)` (25 de septiembre es el último viernes de septiembre de 2026)

#### Scenario: Primer pago estrictamente posterior al inicio del contrato
- **WHEN** el inicio del contrato es 2026-09-25 09:00 (que es un momento de pago de la regla) y el instante de evaluación es 2026-09-26 10:00
- **THEN** el período actual comienza en 2026-09-25 09:00 y termina en 2026-10-30 09:00 (último viernes de octubre de 2026), porque el próximo pago debe ser estrictamente posterior al inicio del período

#### Scenario: Período que cruza el cambio de mes
- **WHEN** el inicio del contrato es 2026-09-25 09:00, la regla es "último viernes de cada mes" y el instante de evaluación es 2026-10-15 12:00
- **THEN** el período actual es `[2026-09-25 09:00, 2026-10-30 09:00)` y su duración refleja los días reales de septiembre y octubre, no una aproximación de 30 días

#### Scenario: Período que cruza el cambio de año
- **WHEN** la regla es "último viernes de cada mes", el inicio del período vigente es 2026-12-25 09:00 y el instante de evaluación es 2027-01-05 10:00
- **THEN** el próximo pago del período es el último viernes de enero de 2027 (2027-01-29 09:00), resuelto con el calendario real de enero de 2027

### Requirement: Cálculo proporcional del dinero ganado
El motor SHALL calcular el dinero ganado como
`sueldo × (ahora − inicio) / (próximoPago − inicio)` usando intervalos de tiempo
exactos en segundos (con precisión sub-segundo). El resultado SHALL estar acotado en
`[0, sueldo]`. La moneda no participa en el cálculo numérico.

#### Scenario: Mitad exacta del período
- **WHEN** el período es `[2026-09-01 09:00, 2026-09-25 09:00)`, el sueldo es 1 500 000 y el instante de evaluación es exactamente el punto medio del período
- **THEN** el dinero ganado es 750 000 y el porcentaje de progreso es 50 %

#### Scenario: Instante inicial del período
- **WHEN** el instante de evaluación es igual al inicio del período
- **THEN** el dinero ganado es 0 y el porcentaje de progreso es 0 %

#### Scenario: Un segundo antes del pago
- **WHEN** el período tiene 24 días de duración, el sueldo es 1 500 000 y el instante de evaluación es 1 segundo antes del próximo pago
- **THEN** el dinero ganado es estrictamente menor que 1 500 000 y estrictamente mayor que el valor correspondiente a 2 segundos antes del pago

#### Scenario: Crecimiento segundo a segundo
- **WHEN** se evalúan dos instantes consecutivos separados por 1 segundo dentro de un período de 30 días con sueldo 1 500 000
- **THEN** el dinero ganado aumenta en 1 500 000 / (30 × 86400) ≈ 0.5787 por segundo (con precisión sub-segundo)

### Requirement: Rollover automático de período
Cuando el instante de evaluación sea mayor o igual al `próximoPago` del período, el
motor SHALL cerrar ese período y abrir automáticamente el nuevo período que comienza
en el momento de pago, cuyo próximo pago es el siguiente momento de la regla. El
dinero ganado del nuevo período SHALL ser 0 en el instante exacto del pago y crecer
desde entonces. El rollover SHALL derivarse exclusivamente de la comparación temporal
con el calendario de pagos; no existe ningún mecanismo de reset manual ni dependiente
del estado de ejecución de la aplicación.

#### Scenario: Rollover en el instante exacto del pago
- **WHEN** el período `[2026-09-01 09:00, 2026-09-25 09:00)` tiene sueldo 1 500 000 y el instante de evaluación es exactamente 2026-09-25 09:00
- **THEN** el período actual es `[2026-09-25 09:00, 2026-10-30 09:00)` y el dinero ganado es 0

#### Scenario: Evaluación posterior al pago con la aplicación reiniciada
- **WHEN** el período `[2026-09-01 09:00, 2026-09-25 09:00)` ya terminó, la aplicación se cerró, y se reabre con el instante 2026-09-26 09:00
- **THEN** el período actual es `[2026-09-25 09:00, 2026-10-30 09:00)` y el dinero ganado corresponde al tiempo transcurrido desde 2026-09-25 09:00 hasta 2026-09-26 09:00 (exactamente 1/35 del sueldo), sin acumular nada del período anterior

#### Scenario: Múltiples pagos transcurridos durante el cierre
- **WHEN** la aplicación estuvo cerrada desde 2026-09-10 hasta 2026-11-10 con la regla "último viernes de cada mes"
- **THEN** al reabrir, el período actual es el que comienza en el último viernes de octubre de 2026 (2026-10-30 09:00) y termina en el último viernes de noviembre de 2026 (2026-11-27 09:00), y el dinero ganado refleja solo el tiempo transcurrido en ese período

#### Scenario: No acumulación indefinida tras el pago
- **WHEN** el instante de evaluación es 7 días posteriores al `próximoPago` del período vigente
- **THEN** el dinero ganado no supera el sueldo del período; el motor reporta el período nuevo que comenzó en el momento de pago

### Requirement: Estados del motor
El motor SHALL reportar un estado explícito y consistente por evaluación: `ACTIVE`
(período en curso con inicio pasado y pago futuro), `FUTURE_START` (el inicio del
contrato es posterior al instante de evaluación), `OPEN_ENDED` (período sin próximo
pago definido, dinero ganado igual al sueldo) o `INVALID_CONFIGURATION` (configuración
inválida, p. ej. sueldo no positivo o fecha de pago anterior al inicio del período).
No existe estado de "reset" separado: el rollover es una transición temporal de
`ACTIVE` a `ACTIVE`.

#### Scenario: Inicio del contrato en el futuro
- **WHEN** el inicio del contrato es 2026-10-01 09:00 y el instante de evaluación es 2026-09-05 12:00
- **THEN** el estado es `FUTURE_START`, el dinero ganado es 0, el porcentaje es 0 y el próximo pago reportado es el primer momento de pago estrictamente posterior al inicio del contrato

#### Scenario: Período abierto sin próximo pago
- **WHEN** la regla es "fecha específica de pago" con fecha 2026-09-25 09:00 y el instante de evaluación es 2026-10-01 09:00
- **THEN** el estado es `OPEN_ENDED`, el dinero ganado es igual al sueldo completo y el porcentaje es 100 %

#### Scenario: Configuración inválida
- **WHEN** el sueldo configurado es 0 o un valor negativo
- **THEN** el estado es `INVALID_CONFIGURATION` y el motor no produce un valor de dinero ganado

#### Scenario: Fecha de pago anterior al inicio del período
- **WHEN** la regla es "fecha específica" y ese momento resuelto es anterior al inicio del contrato
- **THEN** el estado es `INVALID_CONFIGURATION` y el motor no produce un período

### Requirement: Independencia del reloj de la aplicación
El motor SHALL ser una función pura de sus entradas (configuración, regla de pago e
instante de evaluación). Dos evaluaciones con los mismos inputs SHALL producir
siempre la misma salida. El motor no SHALL leer el reloj del sistema ni mantener
estado mutante entre evaluaciones; la inyección del instante debe permitir pruebas
deterministas con fechas fijas.

#### Scenario: Misma entrada, misma salida
- **WHEN** se evalúa el motor dos veces con la misma configuración y el mismo instante inyectado 2026-09-15 12:34:56
- **THEN** ambas evaluaciones producen idéntico período, porcentaje y dinero ganado

#### Scenario: Evaluación tras suspensión del equipo
- **WHEN** el Mac estuvo suspendido 10 horas dentro de un período activo y la aplicación vuelve a evaluar
- **THEN** el dinero ganado corresponde al instante actual real (el tiempo transcurrido durante la suspensión cuenta proporcionalmente), sin saltos artificiales ni pérdida de consistencia

### Requirement: Total ganado acumulado
El motor SHALL reportar además del dinero ganado del período en curso el total de
dinero ganado desde el inicio del contrato: la suma de los sueldos de todos los
períodos ya completados (cada período completado cuenta el sueldo completo aunque su
duración sea menor que la de un mes normal, p. ej. el primer período corto) más el
dinero ganado proporcional del período actual. En `OPEN_ENDED` el total es el sueldo
completo; en `FUTURE_START` y `INVALID_CONFIGURATION` es 0. El cálculo se deriva
exclusivamente del calendario de pagos y no requiere persistencia de historial.

#### Scenario: Primer período en curso
- **WHEN** el inicio del contrato es 2026-09-01 09:00, la regla es "último viernes de cada mes", el sueldo es 1 500 000 y el instante de evaluación es 2026-09-13 09:00 (sin pagos completados aún)
- **THEN** el total ganado es igual al dinero ganado del período en curso (750 000)

#### Scenario: Período completado en el instante exacto del pago
- **WHEN** el período `[2026-09-01 09:00, 2026-09-25 09:00)` tiene sueldo 1 500 000 y el instante de evaluación es exactamente 2026-09-25 09:00
- **THEN** el total ganado es 1 500 000 (el período 1 se completó justo en ese instante) y el dinero ganado del nuevo período es 0

#### Scenario: Múltiples períodos completados
- **WHEN** el inicio del contrato es 2026-09-01 09:00, el sueldo es 1 500 000 y el instante de evaluación es 2026-11-10 12:00 (pagos completados: 2026-09-25 y 2026-10-30)
- **THEN** el total ganado es 3 000 000 más el dinero ganado proporcional del período `[2026-10-30 09:00, 2026-11-27 09:00)`, y cumple `ganado ≤ total < 4 500 000`

#### Scenario: Primer período corto cuenta sueldo completo
- **WHEN** el inicio del contrato es 2026-09-20 09:00, la regla es "último viernes de cada mes" (primer pago 2026-09-25, solo 5 días de período) y el instante de evaluación es 2026-10-01 00:00
- **THEN** el total ganado incluye el sueldo completo del primer período (aunque duró 5 días) más el ganado del período en curso

#### Scenario: Período abierto
- **WHEN** la regla es "fecha específica" con fecha 2026-09-15 09:00, el sueldo es 1 500 000 y el instante de evaluación es 2026-10-01 12:00
- **THEN** el estado es `OPEN_ENDED` y el total ganado es 1 500 000

#### Scenario: Inicio en el futuro
- **WHEN** el inicio del contrato es posterior al instante de evaluación
- **THEN** el total ganado es 0
