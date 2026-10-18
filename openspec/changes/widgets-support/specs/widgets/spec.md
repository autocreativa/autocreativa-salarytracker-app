# Spec: widgets (delta — new capability)

## ADDED Requirements

### Requirement: Dos widgets con contenido diferenciado

La app SHALL incluir una extensión WidgetKit con **dos kinds**:
«SalaryTracker» (`SalaryTrackerMenuBar`, variante *main*) y
«SalaryTracker · Avance» (`SalaryTrackerNotificationCenter`, variante
*progress*), colocables por el usuario desde la galería de widgets de macOS.
En macOS 26 ambos se colocan juntos en el **mismo panel** (Control Center /
Centro de Notificaciones unificados), por lo que se diferencian por
**contenido**, no por superficie:

- *main*: dinero ganado en el período vigente (estilo LCD de la app),
  progreso y próximo pago (familia *medium*).
- *progress*: porcentaje de avance del período, barra de progreso, próximo
  pago y cuenta atrás al mismo (familia *medium*).

Ambos SHALL soportar las familias *small* y *medium* y los estados de
mensaje «contrato aún no comienza», «sin configurar», «configuración
inválida» y «widget desactivado». Los **IDs de kind se conservan** de la
primera versión (son la identidad de la colocación; renombrarlos huérfanos
los widgets ya colocados).

#### Scenario: Widget principal muestra el dinero ganado

- **WHEN** la configuración es válida, el contrato ya comenzó y el switch
  maestro está ON
- **THEN** el widget «SalaryTracker» muestra el dinero ganado actual (LCD),
  el progreso del período y (en *medium*) la fecha del próximo pago,
  re-derivados con el motor del core

#### Scenario: Widget de avance muestra progreso y cuenta atrás

- **WHEN** la configuración es válida, el contrato ya comenzó y el switch
  maestro está ON
- **THEN** el widget «SalaryTracker · Avance» muestra el porcentaje de
  avance, la barra de progreso, la fecha del próximo pago y la cuenta atrás
  en días/horas (o horas/minutos si faltan menos de 24 h); en período
  abierto no muestra fecha ni cuenta atrás

#### Scenario: Timeline con movimiento en vivo

- **WHEN** WidgetKit solicita el timeline de un widget
- **THEN** la extensión genera 60 entradas de 1 minuto cada una (1 h),
  evaluando el motor del core para cada una, con recarga programada al fin
  de la última entrada

#### Scenario: Estados de mensaje

- **WHEN** la configuración es inválida, no existe configuración, el contrato
  aún no comienza o el switch maestro está OFF
- **THEN** ambos widgets muestran el mismo mensaje correspondiente en su
  idioma vigente (en el caso de OFF: «Widget desactivado», en gris)

### Requirement: Switch maestro en Configuración

La ventana de configuración SHALL incluir una sección «Widgets» con un
**switch maestro único** («Mostrar widgets») que activa/desactiva el
contenido de **ambos** kinds a la vez (los toggles por superficie de la
primera versión quedan obsoletos: los dos widgets viven en el mismo panel).
El switch es de contenido, no de colocación: la app SHALL no colocar ni
quitar widgets.

#### Scenario: Desactivar los widgets

- **WHEN** el usuario apaga el switch maestro con widgets ya colocados
- **THEN** los widgets colocados muestran el estado «Widget desactivado»
  (no son removidos de su lugar) y al volver a activarlo recuperan los
  datos

#### Scenario: Guion de colocación e instalación

- **WHEN** no hay widgets colocados
- **THEN** bajo el switch se muestra el guion inline (Control Center →
  editar → galería → añadir «SalaryTracker» y «SalaryTracker · Avance»)
- **WHEN** la detección (`WidgetCenter.getCurrentConfigurations`) ve un kind
  instalado
- **THEN** junto al switch se muestra un indicador «Instalado» por cada
  widget colocado

### Requirement: Sincronización de estado app → widgets

El estado de los widgets (switch maestro + idioma) SHALL persistir en
`widget-state.json` (esquema **v2**) junto a `config.json` (escritura
atómica; ausente o corrupto → valores por defecto, nunca un error). El
estado en disco de la versión anterior (esquema v1, toggles por superficie)
SHALL migrarse automáticamente al cargar: `enabled = menuBar ||
notificationCenter` y se conserva `language`. La app SHALL recargar los
timelines de ambos kinds al guardar la configuración, al cambiar el idioma
y al arrancar.

#### Scenario: Guardar configuración actualiza los widgets

- **WHEN** el usuario guarda una nueva configuración válida
- **THEN** la app persiste el estado (esquema v2) y llama a
  `WidgetCenter.reloadTimelines(ofKind:)` para ambos kinds, y los widgets
  muestran el nuevo valor en su próxima recarga

#### Scenario: Migración del estado v1

- **WHEN** la app o la extensión cargan un `widget-state.json` de esquema v1
- **THEN** el estado resultante tiene `enabled` verdadero si al menos un
  toggle v1 era verdadero, y conserva el idioma guardado

#### Scenario: Widget sin estado

- **WHEN** la extensión arranca sin `widget-state.json` (o corrupto, o de
  esquema desconocido)
- **THEN** el switch maestro se trata como ON y el idioma como el del
  sistema

### Requirement: Idioma de los widgets

La extensión SHALL mostrar sus textos en el idioma guardado en el estado
(`nil` → idioma del sistema) resolviendo su propio `Localizable.strings`
(es base + en/pt-BR/it/de/fr), sin heredar el override `AppleLanguages` de
la app.

#### Scenario: Widget sigue el idioma fijado en la app

- **WHEN** el usuario fija «English» en Configuración y un widget está
  colocado
- **THEN** los textos del widget (etiquetas, estados de mensaje) aparecen en
  inglés tras la recarga de timelines
