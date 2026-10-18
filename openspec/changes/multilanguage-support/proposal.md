# Propuesta: Multilenguaje (es / en / pt-BR / it / de / fr)

## Why

La UI de SalaryTracker tenía todos sus textos **hardcodeados en español** (popover,
barra, ventana de configuración, errores de validación y de archivo). El usuario no
podía usar la app en su idioma si macOS estaba en inglés u otro idioma, y las fechas,
números y porcentajes se formateaban siempre con el locale del sistema (independiente
del idioma que deseara ver la app).

## What Changes

- **Textos localizables:** todos los strings de la UI se extraen a
  `Localizable.strings` (idioma fuente español) + variantes `en.lproj/`,
  `pt-BR.lproj/`, `it.lproj/`, `de.lproj/` y `fr.lproj/`, con lookup centralizado
  vía `L10n` (`Localization.swift`).
- **Core puro, sin idiomas:** `SalaryTrackerCore` no conoce idiomas. Sus salidas
  de error/estado se convierten de *texto en español* a **claves estables**
  (`ValidationIssue`, `TrackerState.InvalidReason`); el mapeo clave → texto
  localizable vive **solo** en la app (`Localization.swift`).
- **Idioma seleccionable en Configuración:** sección «Idioma» con opciones
  *Idioma del sistema* (por defecto), *Español*, *English*, *Português*,
  *Italiano*, *Deutsch* y *Français*.
  El cambio es **inmediato** (re-render al instante) y **persistente**
  (`UserDefaults`, clave `appLanguage`).
- **Resolución explícita por bundle:** `L10n` carga el `.lproj` del idioma
  vigente (en macOS, `Bundle.main` no se re-resuelve al cambiar `AppleLanguages`
  en un proceso ya corriendo); «Idioma del sistema» lee el idioma real de
  `AppleLanguages` en `UserDefaults`.
- **Formateo por locale:** fechas (`DateFormatter`), números de sueldo
  (`NumberFormatter`), y porcentajes (`formatProgress`) usan el locale del idioma
  vigente; los `DatePicker`/`Picker` nativos reciben `.environment(\.locale, …)`.
- **Ajuste de tests:** los tests del core se actualizan para esperar *claves
  estables* en vez de textos; el test de `formatProgress` se vuelve resistente al
  espaciado CLDR del sistema.

## Capabilities

### New Capabilities

- `multilanguage`: Selección de idioma de la app (sistema/es/en/pt-BR/it/de/fr),
  persistencia, aplicación inmediata, y localización de textos + formateo por locale.

### Modified Capabilities

- `currency-formatting`: `formatProgress` acepta un `locale`; `formatRemaining`
  acepta un `daysSuffix` localizable. (El core sigue siendo puro: solo parámetros.)
- `configuration`: Las salidas de validación/estado son claves estables
  (`ValidationIssue`, `InvalidReason`), no textos; la traducción es responsabilidad
  de la UI.

## Impact

- **Código (app):** nuevos `LanguageManager.swift`, `Localization.swift`; reescritos
  `PopoverView`, `SettingsView`, `AppModel`, `MenuBarLabel`, `LoginItemService`,
  `SettingsWindowController`.
- **Código (core):** `Validation.swift`, `Models/TrackerState.swift`,
  `SalaryCalculator.swift`, `Currency/CurrencyFormatter.swift` (API, no comportamiento
  numérico).
- **Recursos:** `Localizable.strings` (es), `en.lproj/`, `pt-BR.lproj/`,
  `it.lproj/`, `de.lproj/`, `fr.lproj/`; `Info.plist` (`CFBundleDevelopmentRegion=es`,
  `CFBundleLocalizations`); `project.pbxproj` (variant group + regiones).
- **Tests:** 91 core + 13 app en verde.
- **Riesgo:** bajo. El cálculo numérico no cambia; solo la presentación. El override
  de `AppleLanguages` solo afecta a esta app (escrito en sus `UserDefaults`).
