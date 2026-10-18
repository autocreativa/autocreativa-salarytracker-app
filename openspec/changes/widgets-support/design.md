# Diseño: Widgets de SalaryTracker

## Contexto

macOS 13+ expone dos superficies de widgets distintas para una misma app:
Control Center / barra de menús y Centro de Notificaciones. WidgetKit **no
permite a la app colocar ni quitar widgets** de un lugar (eso lo hace el
usuario desde la galería). El estado de la app (sueldo, regla, inicio) vive
en `config.json`; la extensión no puede correr código de la app, así que la
comunicación app → extensión es **solo por archivos** (no hay
`AppGroup` compartido en este diseño).

## Decisiones

### D1 — Dos kinds, un mismo contenido
`SalaryTrackerMenuBar` y `SalaryTrackerNotificationCenter` comparten
provider, timeline y vista; difieren solo en `id`/`displayName` y en su
toggle independiente. Razón: los interruptores son **por superficie** (diseño
A confirmado por el usuario) y WidgetKit requiere un kind distinto por
superficie para permitir colocaciones independientes.

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
(`~/Library/Application Support/SalaryTracker/widget-state.json`):

```json
{ "v": 1, "state": { "menuBar": true, "notificationCenter": true, "language": "en" } }
```

- **Solo la app escribe**; la extensión es de solo-lectura.
- `language`: `nil` (clave omitida) = idioma del sistema; resto = código
  corto (`es`/`en`/`pt-BR`/`it`/`de`/`fr`).
- Ausente o corrupto → `.default` (ambos toggles ON), nunca un error.
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
El toggle OFF no puede quitar el widget del lugar (restricción de la
plataforma). Con OFF, el widget colocado muestra un estado explícito «Widget
desactivado» en gris; con ON vuelve a pintar datos. Es un **interruptor
maestro de superficie**, no de colocación.

### D7 — Detección de instalación (advisoria)
`WidgetService.refreshDetection()` usa `WidgetCenter.getCurrentConfigurations`
(macro macOS 13+) para marcar «Instalado» bajo cada toggle cuando el kind ya
está colocado. Es solo informativo: la app nunca muta la colocación.

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

- **Un solo kind**: no permitiría toggles por superficie independientes.
- **`NSUbiquitousContainer`/AppGroup**: sobreingeniería para 2 toggles + 1
  idioma; el patrón existente de la app ya es archivos sueltos + swap atómico.
- **`TimelineReloadPolicy.atEnd` con 1 entrada**: el widget se congelaría
  entre recargas; 60 entradas de 1 min da sensación de movimiento
  «en vivo».
