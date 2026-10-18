# Diseño: Multilenguaje (es / en / pt-BR / it / de / fr)

## Decisiones clave

### D1 — Idioma fuente: español
El español es la región de desarrollo (`developmentRegion = es` en
`project.pbxproj` y `CFBundleDevelopmentRegion = es` en `Info.plist`). El archivo
fuente `Localizable.strings` (sin `.lproj`) contiene el español; Xcode lo coloca en
la raíz de `Contents/Resources/` (comportamiento estándar para la región de
desarrollo) y el lookup cae a él como fallback. Las variantes explícitas viven en
`en.lproj/`, `pt-BR.lproj/`, `it.lproj/`, `de.lproj/` y `fr.lproj/`.

### D2 — Claves estables en el core (separación presentación/lógica)
`SalaryTrackerCore` es una librería pura sin dependencias de UI. En vez de devolver
mensajes en español (como antes), devuelve **claves de máquina**:

- `ValidationIssue` (enum): `salaryNotPositive`, `salaryTooLarge`,
  `invalidCurrencyCode`, `invalidWeekday`, `invalidMonthDay`,
  `specificDateBeforeStart`.
- `TrackerState.InvalidReason` (enum anidado): `.validation(ValidationIssue)`,
  `.configStore`.

La app las traduce con extensiones en `Localization.swift`
(`ValidationIssue.localizedMessage`, `InvalidReason.localizedMessage`,
`ConfigStore.StoreError.localizedMessage`). Ventaja: el core queda testeable e
independiente de idioma; la UI es el único lugar con textos.

### D3 — `L10n` como único punto de lookup (resolución explícita por bundle)
`L10n.str(_ key:)` resuelve la clave contra el **bundle `.lproj` del idioma
vigente** (`L10n.language`): si la clave no existe devuelve la **clave** (visible
en pantalla → detectar fallos de localización a simple vista).
`L10n.str(_ key:, _ args: CVarArg...)` aplica `String(format:locale:arguments:)`
para los `%@` con el locale del idioma.

**Por qué no `Bundle.main.localizedString` directo:** en macOS, cambiar
`AppleLanguages` en `UserDefaults` no hace que un proceso ya corriendo re-resuelva
`Bundle.main` (el idioma del proceso queda congelado al arrancar; a diferencia de
iOS). Por eso `L10n` carga `it.lproj`/`de.lproj`/… directamente. El caso
`.system` lee el idioma real del sistema desde `AppleLanguages` en
`UserDefaults` (dominio global, tras borrar el override de la app) y **no usa
caché**, para reflejar cambios en caliente. Español (región de desarrollo)
resuelve contra `Bundle.main` (sin directorio `.lproj`).

### D4 — Selección de idioma y aplicación inmediata
`AppLanguage` (enum `system`/`spanish`/`english`/`portuguese`/`italian`/`german`/`french`)
define:

- `locale`: `Locale.current` / `es_CL` / `en_US` / `pt_BR` / `it_IT` / `de_DE` /
  `fr_FR` (la identidad original de la app es chilena; se mantiene `es_CL`).
- `languageIdentifiers` (BCP-47): `[]` / `["es"]` / `["en"]` / `["pt-BR"]` /
  `["it"]` / `["de"]` / `["fr"]`.

`LanguageManager` (`ObservableObject`, `@MainActor`):

- `selection` (`@Published`): al cambiar, persiste en `UserDefaults` (clave
  `appLanguage`) y publica `didChangeNotification`.
- `applySystemOverride(_:)`: escribe/borra `AppleLanguages` en
  `UserDefaults.standard` (afecta el arranque futuro del proceso y los
  controles nativos; los textos en caliente los resuelve `L10n` explícitamente,
  ver D3).
- `effectiveLocale`: el locale que inyectan las vistas.
- Al inicializar y en cada cambio sincroniza `L10n.language = selection`.

Propagación del cambio al resto de la UI (sin relanzar):

1. Las vistas leen `model.language.selection` en un modificador `.id(…)` → se
   re-crean al cambiar.
2. `AppModel` (que contiene `LanguageManager` como `@Published var language`) observa
   `didChangeNotification` y manda `objectWillChange.send()` → refresca al instante
   las vistas que observan `AppModel` (`language` es un `ObservableObject` anidado:
   su `@Published` no publica en el modelo padre).
3. Los `DatePicker`/`Picker` nativos reciben
   `.environment(\.locale, model.language.effectiveLocale)` para renderizarse en el
   idioma elegido (no solo los `Text` vía `L10n`).

### D5 — Formateo por locale (core con parámetro, no con estado)
- `CurrencyFormatter.formatProgress(_ ratio:, locale:)`: porcentaje con 2 decimales;
  por defecto `Locale.current`.
- `CurrencyFormatter.formatRemaining(_ seconds:, daysSuffix:)`: el sufijo de días ya
  no está hardcodeado; la UI inyecta `L10n.str("time.daysSuffix")`.
- Las vistas construyen `DateFormatter`/`NumberFormatter` por locale (factory
  `DateFmt` en `PopoverView`, `groupedString`/`parseSalary` en `SettingsView`).

Esto mantiene al core **determinista y puro**: el locale es un parámetro de
presentación, nunca un estado global oculto.

### D6 — Reglas de pago: rawValue-clave, no texto visible
`SettingsView.RuleType` usa `rawValue` = clave estable (`lastFriday`/`monthDay`/
`specificDate`) y expone `displayName` vía `L10n`. Antes el `rawValue` era el texto
español visible, lo que rompería en otros idiomas.

### D7 — Localización de errores de login item
`LoginItemService.lastError` se formatea con
`L10n.str("loginItem.errorEnable"/"loginItem.errorDisable", error.localizedDescription)`:
la plantilla está localizada, el detalle del sistema se interpola.

## Riesgos / mitigaciones

- **Espaciado CLDR variable:** el espacio antes de `%` (p. ej. es_CL "67,42 %" vs
  "67,42 %") cambia entre versiones de macOS/ICU. El test `testFormatProgress`
  normaliza espacios antes de comparar para no depender de ese detalle del sistema.
- **Override `AppleLanguages`:** afecta al proceso de la app (su `UserDefaults`), no
  a otras apps. Al elegir "Idioma del sistema" se **borra** el override para no dejar
  residuo.
- **Añadir idioma futuro:** crear `<lang>.lproj/Localizable.strings` (todas las
  claves), registrarlo en el target, sumarlo a `AppLanguage`, `CFBundleLocalizations`
  y `knownRegions`. Documentado en el README.
