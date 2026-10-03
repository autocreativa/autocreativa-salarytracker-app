## Purpose

Define la experiencia de la Menu Bar: el indicador compacto permanente, el popover
con el detalle en tiempo real, el ciclo de actualización eficiente, el comportamiento
en los distintos estados de la aplicación y las microinteracciones visuales.

## ADDED Requirements

### Requirement: Indicador de Menu Bar
La aplicación SHALL ejecutarse como aplicación de Menu Bar (sin presencia en el Dock)
mostrando un indicador compacto con un glifo de moneda (ícono) seguido del dinero
ganado renderizado como **dígitos de 7 segmentos** (estilo reloj digital antiguo),
SIN el símbolo de moneda (el símbolo visual lo aporta el glifo; el texto del popover
conserva el símbolo completo). El display SHALL usar un **verde dinero** adaptativo
(verde oscuro en barra clara, verde legible en barra oscura) y los segmentos
"apagados" SHALL mantenerse visibles de forma tenue como en un display real. El
indicador SHALL actualizarse automáticamente al menos una vez por segundo sin
interacción del usuario. En estado `NOT_CONFIGURED` el indicador SHALL mostrar un
glifo o etiqueta estática (sin valor monetario). En estado `INVALID_CONFIGURATION`
el indicador SHALL mostrar un estado de error reconocible.

#### Scenario: Indicador activo
- **WHEN** la configuración es válida y el período está activo con dinero ganado 843 291 CLP
- **THEN** la barra de menú muestra un glifo de moneda seguido del número sin símbolo renderizado en dígitos de 7 segmentos en verde dinero (p. ej. glifo + `843.291` en segments, no `$843.291` en texto plano)

#### Scenario: Indicador sin configurar
- **WHEN** el estado es `NOT_CONFIGURED`
- **THEN** la barra de menú muestra un indicador estático (glifo 💰 o etiqueta) sin valor monetario y el popover invita a configurar

#### Scenario: Crecimiento visible segundo a segundo
- **WHEN** el período está activo durante 10 segundos
- **THEN** el valor interno se recalcula en cada tick (10 recalculaciones) y el valor mostrado crece al ritmo de la precisión de presentación de la moneda (con CLP, 0 decimales, el dígito mostrado avanza aproximadamente cada 1.7 s para 1 500 000 en 24 días; con 2 decimales, cada segundo)

### Requirement: Popover de detalle
Al hacer clic en el indicador, la aplicación SHALL abrir un popover con: el dinero
ganado como elemento visualmente dominante, la etiqueta del período actual (inicio →
fin), el próximo pago con fecha legible, el tiempo restante hasta el pago en formato
`Dd HH:MM:SS`, el sueldo del período, un indicador de progreso del período
(porcentaje y barra) y un acceso a la vista de configuración. En `FUTURE_START` el
popover SHALL mostrar la fecha de inicio y "0" de dinero ganado. En `OPEN_ENDED`
SHALL mostrar el sueldo completo como dinero ganado y "sin próximo pago". En
`INVALID_CONFIGURATION` SHALL mostrar el error y un acceso directo a configurar.

#### Scenario: Contenido del popover en estado activo
- **WHEN** el período es `[2026-09-01, 2026-09-25)`, el dinero ganado es 843 291 CLP, el sueldo es 1 500 000 CLP y el tiempo restante es 4 días 8 horas 31 minutos 22 segundos
- **THEN** el popover muestra el valor dominante `$843.291`, el período "01 Sep → 25 Sep", próximo pago "25 Sep", tiempo restante "4d 08:31:22", sueldo `$1.500.000` y el botón de configuración

#### Scenario: Indicador de progreso
- **WHEN** el 67.42 % del período ha transcurrido
- **THEN** el popover muestra el porcentaje 67.42 % y una barra de progreso llena proporcionalmente, con marcas de inicio y fin de período

#### Scenario: Popover en inicio futuro
- **WHEN** el estado es `FUTURE_START` con inicio en 2026-10-01 09:00
- **THEN** el popover muestra el inicio próximo, dinero ganado 0, progreso 0 % y no muestra tiempo restante negativo

#### Scenario: Popover en período abierto
- **WHEN** el estado es `OPEN_ENDED`
- **THEN** el popover muestra el sueldo completo como dinero ganado, 100 % de progreso y el texto "sin próximo pago"

### Requirement: Actualización en tiempo real eficiente
La aplicación SHALL actualizar el valor mostrado al menos una vez por segundo usando
un mecanismo de temporización nativo de macOS eficiente (p. e. un timer que se
reprograma a los segundos), sin polling innecesario a alta frecuencia y sin
consumo sostenido de CPU relevante en reposo. La precisión interna del cálculo SHALL
ser mayor que la frecuencia visual: el valor se calcula a partir del instante exacto
de cada tick, no acumulando incremento fijo. El valor mostrado nunca SHALL parpadear
ni saltar hacia atrás dentro de un período activo, salvo cuando la re-derivación sea
causada por un cambio de zona horaria del sistema o por un guardado de nueva
configuración (casos en que un salto discreto está permitido y se comunica
re-renderizando la UI).

#### Scenario: Cálculo por instante, no por acumulación
- **WHEN** transcurrieron 3 segundos entre dos ticks consecutivos
- **THEN** el valor mostrado en el segundo tick es el calculado desde el instante real (no el valor anterior más 3 incrementos fijos)

#### Scenario: Bajo consumo en reposo
- **WHEN** la aplicación permanece abierta sin interacción del usuario durante 1 hora
- **THEN** el consumo de CPU sostenido es despreciable (sin loops de alta frecuencia)

#### Scenario: Despertar de suspensión
- **WHEN** el Mac despierta de una suspensión
- **THEN** la siguiente actualización (≤ 1 segundo) muestra el valor correspondiente al instante actual, sin demora adicional

### Requirement: Estabilidad visual y animación
El cambio del valor SHALL presentarse con una transición sutil (p. ej. breve
elevación o cambio de tinte) que comunique crecimiento, sin parpadeo, sin
redimensionamiento brusco del popover ni saltos de layout. La aplicación SHALL
respetar Dark Mode y Light Mode del sistema (paleta adaptada a ambos) y el diseño
SHALL seguir una estética digital, minimalista y premium: tipografía limpia con
números grandes para el valor, jerarquía clara, espaciado consistente, bordes suaves
y transparencias apropiadas.

#### Scenario: Adaptación a modo oscuro y claro
- **WHEN** el sistema cambia de Light Mode a Dark Mode
- **THEN** el popover y la vista de configuración se renderizan con la paleta del modo oscuro sin reinicio de la aplicación

#### Scenario: Sin parpadeo
- **WHEN** el valor se actualiza cada segundo durante un minuto
- **THEN** el popover permanece estable (sin flashes, sin re-layout completo) y solo el número cambia con transición sutil

#### Scenario: Transición de dígitos en el display de 7 segmentos
- **WHEN** el valor de la barra de menú cambia de 843.290 a 843.291
- **THEN** el display se re-renderiza en el siguiente tick como un cambio discreto (como un reloj digital real), sin parpadeo del resto de la barra ni saltos de layout; los segmentos apagados siguen visibles de forma tenue

### Requirement: Comportamiento ante cambios de contexto
La aplicación SHALL re-derivar el período tras cambios de zona horaria del sistema,
cruce de medianoche, cambio de mes o de año, y tras guardarse nueva configuración,
sin intervención del usuario y sin reinicio.

#### Scenario: Cruce de medianoche dentro del período
- **WHEN** la aplicación está abierta y se cruza la medianoche
- **THEN** el valor continúa creciendo sin interrupción ni reinicio del período

#### Scenario: Cruce de mes dentro del período
- **WHEN** el período vigente abarca el cambio de mes (p. ej. 25 Sep → 30 Oct)
- **THEN** la duración y el porcentaje se calculan con los días reales de ambos meses

#### Scenario: Cambio de zona horaria del sistema
- **WHEN** el sistema cambia de zona horaria
- **THEN** la próxima evaluación re-deriva el período con la nueva zona horaria y los valores se actualizan consistentemente
