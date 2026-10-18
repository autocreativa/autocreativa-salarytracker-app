# Spec: widgets (delta — new capability)

## ADDED Requirements

### Requirement: Dos widgets con contenido salarial

La app SHALL incluir una extensión WidgetKit con **dos kinds**:
«SalaryTracker · Barra de menús» (`SalaryTrackerMenuBar`) y «SalaryTracker ·
Centro de Notificaciones» (`SalaryTrackerNotificationCenter`), colocables por
el usuario desde la galería de widgets de macOS. Ambos SHALL mostrar el
dinero ganado en el período vigente (estilo LCD de la app), el progreso y el
próximo pago (familia *medium*), y SHALL soportar los estados de mensaje
«contrato aún no comienza», «sin configurar», «configuración inválida» y
«widget desactivado».

#### Scenario: Widget activo muestra el dinero ganado

- **WHEN** la configuración es válida, el contrato ya comenzó y el toggle de
  la superficie del widget está ON
- **THEN** el widget muestra el dinero ganado actual, el progreso del
  período y (en *medium*) la fecha del próximo pago, re-derivados con el
  motor del core

#### Scenario: Timeline con movimiento en vivo

- **WHEN** WidgetKit solicita el timeline del widget
- **THEN** la extensión genera 60 entradas de 1 minuto cada una (1 h),
  evaluando el motor del core para cada una, con recarga programada al fin
  de la última entrada

#### Scenario: Estados de mensaje

- **WHEN** la configuración es inválida, no existe configuración, el contrato
  aún no comienza o el toggle de la superficie está OFF
- **THEN** el widget muestra el mensaje correspondiente en su idioma
  vigente (en el caso de OFF: «Widget desactivado», en gris)

### Requirement: Interruptores por superficie en Configuración

La ventana de configuración SHALL incluir una sección «Widgets» con un
**toggle por superficie** (barra de menús y Centro de Notificaciones). El
toggle es un interruptor maestro de contenido, no de colocación: la app
SHALL no colocar ni quitar widgets.

#### Scenario: Desactivar la superficie

- **WHEN** el usuario apaga el toggle de una superficie con su widget
  ya colocado
- **THEN** el widget colocado muestra el estado «Widget desactivado»
  (no es removido de su lugar) y al volver a activarlo recupera los datos

#### Scenario: Guion de colocación e instalación

- **WHEN** la superficie no tiene widgets colocados
- **THEN** bajo el toggle se muestra el guion inline (Control Center →
  editar → galería → añadir «SalaryTracker …»)
- **WHEN** la detección (`WidgetCenter.getCurrentConfigurations`) ve el kind
  instalado
- **THEN** el guion se reemplaza por un indicador «Instalado»

### Requirement: Sincronización de estado app → widgets

El estado de los widgets (toggles + idioma) SHALL persistir en
`widget-state.json` junto a `config.json` (escritura atómica; ausente o
corrupto → valores por defecto, nunca un error). La app SHALL recargar los
timelines de ambos kinds al guardar la configuración, al cambiar el idioma y
al arrancar.

#### Scenario: Guardar configuración actualiza los widgets

- **WHEN** el usuario guarda una nueva configuración válida
- **THEN** la app persiste el estado y llama a
  `WidgetCenter.reloadTimelines(ofKind:)` para ambos kinds, y los widgets
  muestran el nuevo valor en su próxima recarga

#### Scenario: Widget sin estado

- **WHEN** la extensión arranca sin `widget-state.json` (o corrupto)
- **THEN** ambos toggles se tratan como ON y el idioma como el del sistema

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
