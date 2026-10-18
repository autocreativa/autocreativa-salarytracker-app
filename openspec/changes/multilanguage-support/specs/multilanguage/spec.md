## Purpose

Define la localización de la aplicación: selección de idioma por el usuario
(sistema / español / inglés / portugués / italiano / alemán / francés),
persistencia, aplicación inmediata sin relanzar, y localización de todos los
textos de UI y del formateo de fechas/números por locale.

## ADDED Requirements

### Requirement: Selección de idioma en la configuración
La vista de configuración SHALL incluir una sección «Idioma» con un selector de
idioma con, como mínimo, las opciones: **Idioma del sistema** (por defecto),
**Español**, **English** y **Português**. Cada etiqueta de idioma SHALL escribirse
en su propio idioma (no traducida al idioma vigente).

#### Scenario: Idioma por defecto
- **WHEN** la app arranca por primera vez (sin selección guardada)
- **THEN** la opción vigente es «Idioma del sistema» y la UI se muestra en el idioma del sistema macOS

#### Scenario: Fijar un idioma
- **WHEN** el usuario elige «English» en el selector de idioma
- **THEN** toda la UI (popover, barra, configuración, errores) se muestra en inglés sin relanzar la app

#### Scenario: Volver al idioma del sistema
- **WHEN** el usuario elige «Idioma del sistema» después de haber fijado otro idioma
- **THEN** la UI vuelve a seguir el idioma de macOS y se elimina el override de idioma de la app

### Requirement: Persistencia del idioma
La selección de idioma SHALL persistir entre lanzamientos de la app.

#### Scenario: Reinicio conserva el idioma
- **WHEN** el usuario fija «Português», cierra la app y la relanza
- **THEN** la UI se muestra en portugués (la selección se recupera de `UserDefaults`)

### Requirement: Aplicación inmediata
El cambio de idioma SHALL aplicar de inmediato (re-render de las vistas vigentes),
sin esperar al siguiente tick de actualización.

#### Scenario: Cambio en vivo
- **WHEN** el usuario cambia el idioma con el popover o la ventana de configuración abierta
- **THEN** los textos visibles y los controles nativos (date pickers) se actualizan al instante en el nuevo idioma

### Requirement: Localización de textos de UI
Todos los textos de la UI (popover, chip de la barra y sus etiquetas de
accesibilidad, ventana de configuración, errores de validación y errores del archivo
de configuración) SHALL provenir de recursos localizables
(`Localizable.strings`), nunca de literales hardcodeados en el código.

#### Scenario: Clave ausente visible
- **WHEN** un texto referencia una clave inexistente en los recursos
- **THEN** la UI muestra la clave misma (detectable a simple vista), no un texto vacío

#### Scenario: Errores localizados
- **WHEN** la configuración es inválida (p. ej. sueldo ≤ 0) o el archivo no puede leerse
- **THEN** el mensaje mostrado está en el idioma vigente (la clave estable del core se traduce en la app)

### Requirement: Formateo por locale del idioma vigente
Fechas, montos monetarios, separadores de miles/decimal y porcentajes SHALL
formatearse con el **locale del idioma seleccionado** (es_CL / en_US / pt_BR /
it_IT / de_DE / fr_FR, o el locale del sistema si la opción es «Idioma del
sistema»), de forma coherente en barra, popover y configuración.

#### Scenario: Monto por locale
- **WHEN** el sueldo es 1.500.000 CLP y el idioma vigente es inglés
- **THEN** el monto se muestra con separadores de inglés (p. ej. "1,500,000")

#### Scenario: Fecha por locale
- **WHEN** el próximo pago es 30 de octubre de 2026 y el idioma vigente es español
- **THEN** la fecha se muestra en el formato de fecha en español del locale es_CL

### Requirement: Núcleo de cálculo independiente del idioma
El paquete `SalaryTrackerCore` SHALL seguir siendo puro y sin dependencia de
idioma: sus resultados de validación y de estado inválido SHALL expresarse como
**claves estables** (enums), nunca como texto. La traducción a texto localizable es
exclusiva responsabilidad de la app.

#### Scenario: Claves estables
- **WHEN** la validación falla por sueldo no positivo
- **THEN** el core expone la clave `ValidationIssue.salaryNotPositive` (y no un mensaje en español)
