# Diseño: Widgets de SalaryTracker

## Contexto

macOS 13+ expone superficies de widgets (Control Center / barra de menús y
Centro de Notificaciones); en **macOS 26 se unifican en un solo panel**, por
lo que widgets de kinds distintos se colocan juntos (verificado en logs de
chronod: todas las instancias de la app aparecen en el mismo panel).
WidgetKit **no permite a la app colocar ni quitar widgets** de un lugar (eso
lo hace el usuario desde la galería). El estado de la app (sueldo, regla,
inicio) vive en `config.json`; la extensión no puede correr código de la
app, así que la comunicación app → extensión es **solo por archivos** (no
hay `AppGroup` compartido en este diseño).

## Decisiones

### D1 — Dos kinds, contenido diferenciado (revisión)
`SalaryTrackerMenuBar` («SalaryTracker», variante *main*) y
`SalaryTrackerNotificationCenter` («SalaryTracker · Avance», variante
*progress*) comparten provider y estrategia de timeline; difieren en
`id`/`displayName` y en la vista. **Los IDs de kind se conservan** de la
primera versión: son la identidad de la colocación y renombrarlos huérfanos
los widgets ya colocados.

Revisión (la v1 usaba un toggle **por superficie** —barra de menús vs.
Centro de Notificaciones—): en macOS 26 ambos widgets se colocan juntos en
el **mismo panel** (Control Center / Centro de Notificaciones unificados),
por lo que el par de toggles no se correspondía con la realidad del sistema
y los nombres «… Barra de menús» / «… Centro de Notificaciones» no
describían la ubicación real. Se sustituye por un **switch maestro único**
(D6) y contenido diferenciado: *main* (dinero ganado LCD + progreso +
próximo pago) y *progress* (% + barra + próximo pago + cuenta atrás).

### D2 — Timeline de 60 entradas (1/min, 1 h)
El widget muestra dinero ganado **por segundo**. El
`TimelineProvider` genera 60 entradas (1 por minuto) re-derivadas con
`TrackerEngine.state(config:now:)` — el mismo motor puro del core que usa la
app — más entradas de frontera (inicio futuro del contrato / fin del período)
si caen dentro del horizonte.
`reloadAfter` = fin de la última entrada. Es la única forma de animación sin
mantener un proceso vivo; al cambiar el estado relevante la app llama
`WidgetCenter.reloadTimelines(ofKind:)` (guardar config, cambiar idioma,
arranque), lo cual hace el efecto «inmediato» en la práctica.

### D3 — Estado compartido por archivo: `widget-state.json`
`WidgetState` (struct) + `WidgetStateStore` (carga/escritura atómica) en el
core, junto a `config.json`
(`~/Library/Application Support/SalaryTracker/widget-state.json`), esquema
**v2**:

```json
{ "v": 2, "state": { "enabled": true, "language": "en" } }
```

- **Solo la app escribe**; la extensión es de solo-lectura.
- `language`: `nil` (clave omitida) = idioma del sistema; resto = código
  corto (`es`/`en`/`pt-BR`/`it`/`de`/`fr`).
- **Migración v1→v2** al cargar: el esquema v1
  (`{ "v": 1, "state": { "menuBar": bool, "notificationCenter": bool, "language": … } }`)
  migra a `enabled = menuBar || notificationCenter` conservando `language`.
- Ausente, corrupto o de esquema desconocido → `.default` (`enabled: true`),
  nunca un error.
- Se reescribe con swap atómico (mismo patrón que `config.json`).

### D4 — La extensión re-deriva, no recibe snapshots
La extensión carga `config.json` (`ConfigStore`) + `widget-state.json`
(`WidgetStateStore`) y ejecuta `TrackerEngine.state(config:now:)` por cada
entrada del timeline (config y engine se cargan una vez por timeline, no por
cada minuto). Ventaja: un solo código de cálculo (el del core) y consistencia
total con la app; la extensión nunca muestra un valor «de la app» stale.

### D5 — Idioma propio de la extensión
La extensión **no hereda** el override `AppleLanguages` que la app escribe en
`UserDefaults` (los procesos de extensión y app son distintos). Resuelve su
propio `.lproj` según `WidgetState.language` (misma estrategia de resolución
explícita por bundle que usa `L10n` en la app); sin idioma guardado usa el
sistema. Claves `widget.*` duplicadas en los 6 `Localizable.strings` de la
extensión (no comparten bundle con la app).

### D6 — «Desactivado» = pintar, no remover
El switch OFF no puede quitar el widget del lugar (restricción de la
plataforma). Con OFF, cada widget colocado muestra un estado explícito
«Widget desactivado» en gris; con ON vuelve a pintar datos. Es un
**interruptor maestro de contenido** (común a los dos kinds), no de
colocación.

### D7 — Detección de instalación (advisoria)
`WidgetService.refreshDetection()` usa `WidgetCenter.getCurrentConfigurations`
(macro macOS 13+) para marcar «Instalado» junto al switch maestro por cada
kind ya colocado. Es solo informativo: la app nunca muta la colocación.

### D8 — Embedding vía script phase
La fase de copy-file estándar (`CONTENTS_FOLDER_PATH/PlugIns`) produce
destino anidado incorrecto (`…app/Contents/PlugIns/…app/Contents/PlugIns/
SalaryTrackerWidget.appex`) con este proyecto. Se usa una
`PBXShellScriptBuildPhase` «Embed Widget Extension» que hace `cp -R` explícito
del `.appex` a `${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}/Contents/PlugIns/`
(`alwaysOutOfDate = 1`, input = el appex). Consecuencia: el target de app
necesita `ENABLE_USER_SCRIPT_SANDBOXING = NO` (sandbox por defecto de Xcode
27) para permitir la escritura en el bundle; se desactiva **solo en el target
de app**, no en el proyecto.

## Alternativas descartadas

- **Un solo kind**: no permitiría dos variantes de contenido con
  colocaciones independientes (el usuario puede colocar solo una de las dos).
- **Conservar los toggles por superficie (v1)**: en macOS 26 ambos widgets
  viven en el mismo panel, así que los toggles no controlaban «dónde se ve»
  sino widgets con nombres que no correspondían a su ubicación (confusión
  reportada por el usuario). Se prefiere un switch maestro + contenido
  diferenciado.
- **Renombrar los IDs de kind** (`…MenuBar`/`…NotificationCenter` → p. ej.
  `…Main`/`…Progress`): huérfanos las colocaciones existentes; no aporta nada
  porque el ID es solo identidad interna.
- **`NSUbiquitousContainer`/AppGroup**: sobreingeniería para 1 switch + 1
  idioma; el patrón existente de la app ya es archivos sueltos + swap atómico.
- **`TimelineReloadPolicy.atEnd` con 1 entrada**: el widget se congelaría
  entre recargas; 60 entradas de 1 min da sensación de movimiento
  «en vivo».
