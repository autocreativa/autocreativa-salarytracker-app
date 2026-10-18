# Estado: 13/13 ítems completos. 104/104 tests en verde (91 core + 13 app). Build app `BUILD SUCCEEDED` y `TEST SUCCEEDED`.

## 1. Núcleo puro con claves estables

- [x] 1.1 `Validation.swift`: `ValidationIssue` (6 casos) y `ConfigValidator.Result.issues` (reemplaza `errors: [String]`)
- [x] 1.2 `Models/TrackerState.swift`: `TrackerState.InvalidReason` (enum anidado: `.validation(ValidationIssue)`, `.configStore`); `case invalid(reason: InvalidReason)`
- [x] 1.3 `SalaryCalculator.swift`: devuelve claves en vez de textos (`salaryNotPositive`, `specificDateBeforeStart`)
- [x] 1.4 `Currency/CurrencyFormatter.swift`: `formatProgress(_:locale:)` y `formatRemaining(_:daysSuffix:)` (parámetros de presentación, core sigue puro)
- [x] 1.5 Tests core actualizados a claves (`TestSupport.invalidReason`, `CurrencyTests`); `testFormatProgress` resistente al espaciado CLDR (macOS 27: "67,42%" sin espacio) — 91/91 en verde

## 2. Capa de localización (app)

- [x] 2.1 `Localization.swift`: `L10n.str(key)` / `L10n.str(key, args…)` + extensiones `ValidationIssue.localizedMessage`, `InvalidReason.localizedMessage`, `ConfigStore.StoreError.localizedMessage`
- [x] 2.2 `LanguageManager.swift`: `AppLanguage` (system/spanish/english/portuguese; locales es_CL/en_US/pt_BR; BCP-47), `LanguageManager` con persistencia (`appLanguage`), override `AppleLanguages` y `didChangeNotification`
- [x] 2.3 `AppModel.swift`: `@Published var language: LanguageManager` (inyectable en init), estado inválido `.invalid(reason: .configStore)` + `loadIssue` localizada, observador de `didChangeNotification` → `objectWillChange` (cambio inmediato)

## 3. Vistas localizadas

- [x] 3.1 `PopoverView.swift`: factory `DateFmt` por locale (el `medium` sin "de" hardcodeado, `dateStyle = .medium`), textos vía `L10n`, locale inyectado, `.id(model.language.selection)`
- [x] 3.2 `SettingsView.swift`: `RuleType` con rawValue-clave + `displayName` vía `L10n`, sección «Idioma» (picker `$model.language.selection`), `parseSalary`/`groupedString` por locale, `.environment(\.locale, …)` en pickers nativos, `SectionCard` restaurado
- [x] 3.3 `MenuBarLabel.swift` (accessibility L10n), `LoginItemService.swift` (errores L10n), `SettingsWindowController.swift` (título L10n + inyección de locale)

## 4. Recursos y proyecto

- [x] 4.1 `Localizable.strings` (es, fuente), `en.lproj/Localizable.strings`, `pt-BR.lproj/Localizable.strings` — mismo conjunto de claves en los tres
- [x] 4.2 `project.pbxproj`: file refs + `PBXVariantGroup` + build files en Resources del target app, `LanguageManager`/`Localization` en Sources (app y tests), `developmentRegion = es`, `knownRegions += es, pt-BR`
- [x] 4.3 `Info.plist`: `CFBundleDevelopmentRegion = es` + `CFBundleLocalizations` (es, en, pt-BR)
- [x] 4.4 Verificación: `swift test` (91/91) y `xcodebuild test` (13/13) en verde; bundle con `Localizable.strings` + `en.lproj` + `pt-BR.lproj`

## 5. Documentación

- [x] 5.1 README: sección «Multilenguaje» (idiomas, mecanismo, cómo añadir uno) + conteos de tests (91 core + 13 app) + estado 2026-10-18
- [x] 5.2 Este change de openspec (proposal, design, spec, tasks)

## 6. Ampliación a 6 idiomas + fix de «Idioma del sistema» (2026-10-18)

- [x] 6.1 Fix del modo «sistema»: `L10n` resolvía contra `Locale.current` (congelado en el idioma de arranque del proceso); ahora lee `AppleLanguages` real de `UserDefaults` (dominio global, sin caché) y resuelve el `.lproj` explícito (macOS no re-resuelve `Bundle.main` en caliente)
- [x] 6.2 Nuevas localizaciones: `it.lproj/`, `de.lproj/`, `fr.lproj/` — mismo conjunto de claves (paridad verificada por diff)
- [x] 6.3 `AppLanguage`: casos `italian`/`german`/`french` (locales it_IT/de_DE/fr_FR, BCP-47 it/de/fr, etiquetas nativas); `L10n.bundle(for:)` mapea los 6 idiomas
- [x] 6.4 `project.pbxproj` (refs + variant group + build files + `knownRegions += it, de, fr`) e `Info.plist` (`CFBundleLocalizations`)
- [x] 6.5 Verificación: `xcodebuild test` en verde; bundle Release con los 6 locales; DMG 1.1.0 regenerado (`5b5dea26…`) y redeplo a `/Applications`
- [x] 6.6 Docs: README (sección Multilenguaje + estado) y este change actualizados
