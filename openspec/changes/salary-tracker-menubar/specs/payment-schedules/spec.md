## Purpose

Define las reglas de calendario que determinan en qué instantes ocurren los pagos,
proporcionando al motor los momentos de pago de forma recursiva y exacta, y
permitiendo agregar nuevas reglas sin modificar el motor de cálculo.

## ADDED Requirements

### Requirement: Abstracción de reglas de pago
El sistema SHALL exponer una abstracción de regla de pago con dos responsabilidades:
generar el momento de pago que sigue a un instante dado (hacia adelante), y
declarar si la regla es recurrente o de una sola fecha. La comparación es
**estricta**: el momento retornado es siempre estrictamente posterior al instante de
consulta; si este coincide con un momento de pago, el resultado es el momento
siguiente (esto impide períodos de duración cero). Toda la resolución de fechas
SHALL usar el calendario gregoriano nativo y la zona horaria indicada; no se
permiten aproximaciones de días por semana o horas por día en la resolución de
fechas.

#### Scenario: La regla responde "próximo pago después de X"
- **WHEN** se pregunta a la regla "último viernes de cada mes" por el próximo pago después de 2026-09-10 10:00
- **THEN** el resultado es 2026-09-25 09:00 (último viernes de septiembre a la hora de referencia de la regla)

#### Scenario: Reglas recurrentes vs fecha única
- **WHEN** la regla "día N de cada mes" se consulta repetidamente hacia adelante
- **THEN** produce una sucesión infinita de momentos de pago, mientras que la regla "fecha específica" produce exactamente un momento y luego declara no tener sucesores

#### Scenario: Estrictidad cuando la consulta coincide con un momento de pago
- **WHEN** se consulta a la regla "último viernes de cada mes" (hora de referencia 09:00) el próximo pago después de 2026-09-25 09:00 (que es un momento de pago)
- **THEN** el resultado es 2026-10-30 09:00 (el momento posterior), nunca 2026-09-25 09:00

### Requirement: Último día de la semana del mes
La regla "último día-X de cada mes" (v1: viernes, extensible a cualquier día) SHALL
resolver el último día de la semana X dentro de cada mes usando el calendario real.
La hora del momento de pago SHALL ser la hora de inicio del contrato definida por el
usuario (regla R-PAYMENT-TIME del proposal).

#### Scenario: Mes con cuatro viernes
- **WHEN** se resuelve el último viernes de septiembre de 2026
- **THEN** el resultado es 2026-09-25 (septiembre de 2026 tiene 30 días y 4 viernes: 4, 11, 18 y 25)

#### Scenario: Mes con cinco viernes
- **WHEN** se resuelve el último viernes de octubre de 2026
- **THEN** el resultado es 2026-10-30 (octubre de 2026 tiene 31 días y 5 viernes: 2, 9, 16, 23 y 30)

#### Scenario: Resolución en años bisiestos
- **WHEN** se resuelve el último viernes de febrero de 2028 (año bisiesto, 29 días)
- **THEN** el resultado es 2028-02-25

#### Scenario: Resolución en febrero corto no bisiesto
- **WHEN** se resuelve el último viernes de febrero de 2027 (28 días)
- **THEN** el resultado es 2027-02-26

#### Scenario: Cruzamiento de año al generar la sucesión
- **WHEN** se generan los pagos de la regla "último viernes de cada mes" desde diciembre de 2026
- **THEN** la sucesión incluye 2026-12-25 09:00 y luego 2027-01-29 09:00 sin discontinuidad

### Requirement: Día fijo del mes
La regla "día N de cada mes" (1 ≤ N ≤ 31) SHALL producir el momento de pago en el día
N de cada mes a la hora de referencia. Cuando N sea mayor que la cantidad de días del
mes (p. ej. día 31 en un mes de 30 días), el pago SHALL resolverse al mismo día N
del siguiente mes en que exista (regla R-SKIP del proposal).

#### Scenario: Día fijo normal
- **WHEN** la regla es "día 25 de cada mes" con hora de referencia 09:00 y se consulta el próximo pago después de 2026-09-01 00:00
- **THEN** el resultado es 2026-09-25 09:00

#### Scenario: Día 31 en mes de 30 días
- **WHEN** la regla es "día 31 de cada mes" y se genera la sucesión desde 2026-09-01
- **THEN** la sucesión salta septiembre (30 días) y produce 2026-10-31, 2026-12-31, 2027-01-31, etc., omitiendo los meses sin día 31

#### Scenario: Día 30 en febrero
- **WHEN** la regla es "día 30 de cada mes" y se genera la sucesión cruzando febrero de 2027 (28 días)
- **THEN** la sucesión omite febrero de 2027 y continúa con 2027-03-30

#### Scenario: Día 29 en año no bisiesto
- **WHEN** la regla es "día 29 de cada mes" y se genera la sucesión cruzando febrero de 2027
- **THEN** la sucesión omite febrero de 2027 y lo incluye correctamente en febrero de 2028 (2028-02-29)

### Requirement: Fecha específica de pago
La regla "fecha específica" SHALL aceptar una fecha de pago única definida por el
usuario (a la hora de referencia, como el resto de reglas). Delimita el período que
comienza en el inicio del contrato y termina en esa fecha. Tras ese momento la regla
no genera más pagos (período abierto, regido por el estado `OPEN_ENDED` del motor).

#### Scenario: Período hasta la fecha específica
- **WHEN** la regla es "fecha específica" 2026-10-15 09:00, el inicio del contrato es 2026-09-25 09:00 y el instante de evaluación es 2026-10-01 09:00
- **THEN** el período actual es `[2026-09-25 09:00, 2026-10-15 09:00)` y el próximo pago reportado es 2026-10-15 09:00

#### Scenario: Evaluación después de la fecha específica
- **WHEN** la regla es "fecha específica" 2026-10-15 09:00 y el instante de evaluación es 2026-11-01 09:00
- **THEN** el motor declara período abierto (estado `OPEN_ENDED`) con el sueldo completo ganado

#### Scenario: Fecha específica anterior al inicio del contrato
- **WHEN** la fecha específica (2026-09-10 09:00) es anterior al inicio del contrato (2026-09-25 09:00)
- **THEN** la configuración es inválida para el cálculo del período inicial y la UI debe reportar el error; el motor no produce un período con pago anterior a su inicio

### Requirement: Extensibilidad de reglas
La arquitectura de reglas SHALL permitir registrar nuevas implementaciones (p. ej.
semanal, quincenal, personalizada) sin modificar el motor de cálculo ni las reglas
existentes. Cada nueva regla SHALL poder expresar su descripción legible para la UI
(p. ej. "Último viernes de cada mes").

#### Scenario: Descripción legible para la UI
- **WHEN** la regla activa es "último viernes de cada mes"
- **THEN** la UI puede mostrar la etiqueta "Último viernes de cada mes" obtenida de la propia regla

#### Scenario: Nueva regla sin tocar el motor
- **WHEN** se agrega una regla "quincenal" (días 1 y 15) al conjunto de reglas
- **THEN** el motor de cálculo y las demás reglas permanecen sin modificaciones y la nueva regla es seleccionable desde la configuración
