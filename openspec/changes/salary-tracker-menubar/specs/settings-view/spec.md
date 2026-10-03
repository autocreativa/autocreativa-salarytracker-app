## Purpose

Define la vista de configuración dedicada donde el usuario edita sueldo, moneda,
inicio del contrato y regla de pago, con validación, vista previa en vivo del
cálculo y guardado explícito.

## ADDED Requirements

### Requirement: Estructura de la vista de configuración
La vista de configuración SHALL ser una **ventana dedicada de primera clase** (no
una hoja anidada dentro de la ventana transitoria de la barra) accesible desde el
popover, con secciones separadas y etiquetadas: **Sueldo** (monto y moneda),
**Inicio del contrato** (fecha y hora), **Día de pago** (tipo de regla y parámetros)
y **Resumen** (resumen del cálculo resultante), con márgenes internos
consistentes entre los controles y el borde de la ventana. El acceso a la
configuración SHALL estar disponible tanto en estado activo como en estado no
configurado.

#### Scenario: Secciones presentes
- **WHEN** el usuario abre la vista de configuración
- **THEN** se muestran las secciones Sueldo, Inicio del contrato, Día de pago y Resumen con sus respectivos campos, separados del borde de la ventana por márgenes visibles

#### Scenario: Estabilidad al seleccionar valores
- **WHEN** el usuario abre un selector (moneda, regla de pago) o un date picker dentro de la vista de configuración y selecciona un valor
- **THEN** la vista permanece abierta y refleja la selección sin cerrarse ni perder el foco

#### Scenario: Acceso desde el estado no configurado
- **WHEN** la aplicación está en `NOT_CONFIGURED` y el usuario hace clic en "Configurar" del popover
- **THEN** se abre la vista de configuración con campos vacíos por defecto

### Requirement: Edición de sueldo
La sección Sueldo SHALL permitir editar el monto (campo numérico con separadores
visuales) y la moneda (selector del catálogo ISO). Al guardar, el monto SHALL
interpretarse como el total del período de pago, no como un valor mensual fijo de 30
días.

#### Scenario: Edición del monto
- **WHEN** el usuario cambia el monto de 1 500 000 a 2 000 000 y guarda
- **THEN** el dinero ganado mostrado se recalcula inmediatamente con el nuevo sueldo

#### Scenario: Cambio de moneda
- **WHEN** el usuario cambia la moneda de CLP a USD manteniendo el monto
- **THEN** el valor numérico permanece igual y el indicador de la barra y el popover
  muestran la nueva moneda (símbolo, decimales y separadores)

### Requirement: Edición del inicio del contrato
La sección Inicio del contrato SHALL permitir seleccionar fecha y hora de inicio
independientes (selector de fecha y selector de hora). La combinación resultante
SHALL almacenarse como fecha/hora completa local.

#### Scenario: Selección de fecha y hora
- **WHEN** el usuario selecciona 2026-09-01 y 09:00 y guarda
- **THEN** el inicio del contrato se almacena como 2026-09-01 09:00 local y el período se re-deriva

#### Scenario: Inicio en el futuro
- **WHEN** el usuario guarda un inicio de contrato posterior al instante actual
- **THEN** la aplicación entra en `FUTURE_START` mostrando 0 ganado y la fecha de inicio

### Requirement: Edición de la regla de pago
La sección Día de pago SHALL permitir elegir el tipo de regla: "Último viernes de
cada mes" (v1; extensible a último día-X), "Día N de cada mes" (con campo de día) y
"Fecha específica" (con selector de fecha). Para reglas recurrentes, la hora del
pago SHALL ser la hora de inicio del contrato. Debajo del selector SHALL mostrarse
el próximo pago resultante como texto legible (p. ej. "25 de septiembre de 2026,
09:00").

#### Scenario: Selección del último viernes
- **WHEN** el usuario selecciona "Último viernes de cada mes"
- **THEN** se muestra como próximo pago la fecha calculada (p. ej. "25 de septiembre de 2026, 09:00")

#### Scenario: Selección de día fijo
- **WHEN** el usuario selecciona "Día N de cada mes" y N = 25
- **THEN** el próximo pago mostrado corresponde al día 25 del mes vigente o siguiente según el instante actual

#### Scenario: Selección de fecha específica
- **WHEN** el usuario selecciona "Fecha específica" y elige 2026-10-15
- **THEN** el próximo pago mostrado es 2026-10-15 a la hora de inicio del contrato, y se advierte que tras esa fecha el período queda abierto

### Requirement: Vista previa y validación
La sección **Resumen** (antes "Vista previa") SHALL recalcular y mostrar en vivo
(antes de guardar) las filas **Sueldo base**, **Ganado este mes** (dinero ganado
proporcional del período en curso), **Total ganado** (sueldos de períodos completados
más ganado actual; 0 en inicio futuro), **Progreso** y **Próximo pago**, a partir de
los valores pendientes en los campos. El próximo pago en el resumen SHALL mostrarse
solo con día, mes y año en formato largo (p. ej. "30 de octubre de 2026"), sin hora.
Si la combinación pendiente es inválida, el resumen SHALL mostrar el error concreto
en lugar de valores, y el botón de guardar SHALL permanecer deshabilitado o, al
pulsarse, mostrar el error sin persistir nada.

#### Scenario: Vista previa en vivo
- **WHEN** el usuario modifica el monto a 2 000 000 sin guardar aún
- **THEN** la sección Resumen muestra "Sueldo base" 2 000 000, "Ganado este mes" y "Total ganado" recalculados y el próximo pago vigente

#### Scenario: Total ganado con períodos completados
- **WHEN** el inicio del contrato es 2026-08-10 09:00, la regla es "último viernes de cada mes", el sueldo es 1 800 000 y el instante actual es 2026-10-03
- **THEN** la fila "Total ganado" es la suma de los sueldos de los períodos completados (2026-08-28 y 2026-09-25) más el ganado proporcional del período en curso

#### Scenario: Próximo pago solo día, mes y año
- **WHEN** el resumen muestra el próximo pago
- **THEN** la fecha se presenta en formato largo sin hora (p. ej. "30 de octubre de 2026")

#### Scenario: Vista previa inválida
- **WHEN** el usuario deja el monto vacío o negativo
- **THEN** la vista previa muestra un mensaje de error (p. ej. "El sueldo debe ser mayor que cero") y no se muestran valores calculados

#### Scenario: Guardado explícito
- **WHEN** el usuario pulsa "Guardar cambios" con una configuración válida
- **THEN** la configuración se persiste, la vista se cierra o confirma el guardado, y el indicador de la barra refleja los nuevos valores inmediatamente

#### Scenario: Descartar cambios
- **WHEN** el usuario modifica campos y cancela sin guardar
- **THEN** la configuración persistida no cambia y la UI sigue mostrando los valores anteriores
