## Purpose

Define el modelo de configuración que el usuario edita, las reglas de validación antes
de persistir, el almacenamiento local duradero y la reconstrucción consistente del
estado de la aplicación al iniciarla, garantizando funcionamiento sin conexión.

## ADDED Requirements

### Requirement: Modelo de configuración
La configuración SHALL constar de: (1) monto del sueldo (valor numérico positivo),
(2) código de moneda ISO 4217, (3) fecha de inicio del contrato (componentes de
fecha local: año, mes, día), (4) hora de inicio del contrato (componentes de hora
local: hora, minuto) y (5) regla de pago con sus parámetros (tipo y datos de la
regla). La fecha y la hora de inicio SHALL almacenarse como fecha/hora completa
local y resolverse siempre en la zona horaria actual del sistema al calcular.

#### Scenario: Configuración completa y válida
- **WHEN** el usuario configura sueldo 1 500 000, moneda CLP, inicio 2026-09-01 09:00 y regla "último viernes de cada mes"
- **THEN** la configuración persiste con los cinco elementos y el motor puede evaluarla

#### Scenario: Almacenamiento de fecha y hora completa
- **WHEN** el usuario guarda inicio de contrato 2026-09-01 a las 09:00
- **THEN** el almacenamiento conserva tanto la fecha (2026-09-01) como la hora (09:00) y la hora se usa como hora de referencia de los momentos de pago

### Requirement: Validación antes de guardar
El sistema SHALL validar la configuración antes de persistirla y SHALL rechazar el
guardado con mensajes de error específicos cuando: el monto no es numérico o no es
positivo; falta moneda, fecha o hora de inicio; la regla de pago es incompleta (p. ej.
"fecha específica" sin fecha, o "día N" con N fuera de 1-31); o la fecha de pago
específica es anterior al inicio del contrato. La configuración previa válida SHALL
conservarse mientras la nueva no sea válida.

#### Scenario: Monto no positivo
- **WHEN** el usuario intenta guardar con monto 0
- **THEN** el guardado se rechaza con un mensaje indicando que el sueldo debe ser mayor que cero y la configuración anterior sigue vigente

#### Scenario: Día de pago fuera de rango
- **WHEN** el usuario elige la regla "día N de cada mes" con N = 32
- **THEN** el guardado se rechaza indicando que el día debe estar entre 1 y 31

#### Scenario: Fecha específica anterior al inicio
- **WHEN** el usuario configura inicio 2026-09-25 y fecha de pago específica 2026-09-10
- **THEN** el guardado se rechaza indicando que la fecha de pago debe ser posterior al inicio del contrato

#### Scenario: Moneda sin cambios no invalida la configuración
- **WHEN** el usuario solo cambia la moneda de CLP a USD y guarda
- **THEN** el guardado se acepta y el motor recalcula con el mismo monto numérico; la diferencia es únicamente de presentación

### Requirement: Persistencia local y funcionamiento offline
La configuración SHALL persistirse localmente en el dispositivo (archivo en el
contenedor de datos de la aplicación, formato legible por máquina) al guardarse, sin
ninguna dependencia de red. La aplicación SHALL ser completamente funcional offline.
La persistencia SHALL ocurrir de forma atómica (no se deben perder datos ni
corromper el archivo por un cierre abrupto durante la escritura).

#### Scenario: Persistencia entre ejecuciones
- **WHEN** el usuario guarda la configuración y cierra la aplicación
- **THEN** al reabrir la aplicación, la configuración se recupera idéntica sin intervención del usuario

#### Scenario: Persistencia entre reinicios del sistema
- **WHEN** el Mac se reinicia con una configuración guardada
- **THEN** la aplicación inicia con la misma configuración

#### Scenario: Escritura atómica
- **WHEN** el sistema se apaga durante la escritura de la configuración
- **THEN** al reabrir, la configuración presente es o bien la versión completa anterior o bien la nueva completa, nunca un archivo corrupto parcial

### Requirement: Reconstrucción del estado al iniciar
Al iniciar (o al cambiar de zona horaria o al guardarse nueva configuración), la
aplicación SHALL derivar el estado actual directamente de la configuración
persistida y el instante actual, sin dependencias de estado acumulado en memoria ni
en disco. El estado derivado SHALL ser uno de: `NOT_CONFIGURED` (sin configuración),
`INVALID_CONFIGURATION` (configuración inválida), `FUTURE_START`, `ACTIVE` o
`OPEN_ENDED`.

#### Scenario: Primera ejecución sin configuración
- **WHEN** la aplicación se inicia por primera vez y no existe configuración persistida
- **THEN** el estado es `NOT_CONFIGURED` y la UI invita a configurar (sin valores de dinero en la barra)

#### Scenario: Inicio después de varios pagos transcurridos
- **WHEN** la aplicación se inicia en 2026-11-10 con configuración de inicio 2026-09-01 09:00 y regla "último viernes de cada mes"
- **THEN** el estado derivado es `ACTIVE` con período `[2026-10-30 09:00, 2026-11-27 09:00)` y dinero ganado igual al transcurrido desde 2026-10-30 09:00

#### Scenario: Cambio de zona horaria
- **WHEN** la zona horaria del sistema cambia de GMT-4 a GMT+2 con configuración vigente
- **THEN** el período se re-deriva inmediatamente con la nueva zona horaria y los valores mostrados se recalculan sin intervención del usuario

#### Scenario: Guardado de nueva configuración
- **WHEN** el usuario guarda una nueva configuración durante un período activo
- **THEN** el período y el dinero ganado se recalculan inmediatamente con la nueva configuración (regla R-LIVE del proposal), sin conservar valores del período anterior

### Requirement: Invariantes de estado
El sistema SHALL evitar estados inconsistentes: no existe simultáneamente un
período activo y un aviso de "sin configurar"; un estado `ACTIVE` siempre implica un
período con `inicio < próximoPago` y un dinero ganado en `[0, sueldo]`; el rollover
nunca produce un período vacío (inicio igual a fin) salvo la configuración que el
usuario explícitamente validó.

#### Scenario: Transición de estados por tiempo
- **WHEN** el estado pasa de `FUTURE_START` a `ACTIVE` al llegar la hora de inicio del contrato
- **THEN** la transición ocurre automáticamente en la siguiente evaluación (≤ 1 segundo) sin reinicio de la aplicación

#### Scenario: Transición ACTIVE → OPEN_ENDED
- **WHEN** la regla es "fecha específica" y transcurre ese momento
- **THEN** el estado pasa a `OPEN_ENDED` con dinero ganado igual al sueldo, sin reinicio ni intervención
