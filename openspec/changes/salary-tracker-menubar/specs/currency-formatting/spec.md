## Purpose

Proporciona el catálogo de monedas disponibles, la representación simbólica de cada
moneda y el formato numérico correcto (decimales, separadores y símbolo) de los
valores, de modo que la moneda afecte únicamente la presentación y nunca el
cálculo.

## ADDED Requirements

### Requirement: Catálogo de monedas
El sistema SHALL ofrecer un catálogo de monedas identificado por su código ISO 4217
que incluya, como mínimo: CLP, USD, EUR, GBP, ARS, BRL, MXN, JPY, CAD, AUD, CHF, CNY,
KRW, PLN, CZK, SEK, NOK, DKK, AED, SGD, ZAR, COP, PEN. Cada moneda del catálogo
SHALL exponer su código ISO, su símbolo de presentación y su cantidad de decimales
menores estándar (p. ej. CLP: 0, USD: 2, JPY: 0, EUR: 2).

#### Scenario: Selección de moneda disponible
- **WHEN** el usuario abre la vista de configuración
- **THEN** el selector de moneda lista el catálogo completo con código ISO y símbolo, y CLP, USD, EUR, GBP, ARS, BRL, MXN y JPY están presentes

#### Scenario: Decimales por moneda
- **WHEN** se consultan los decimales menores de CLP, USD y JPY
- **THEN** los resultados son 0, 2 y 0 respectivamente

### Requirement: Formato numérico por moneda
El sistema SHALL formatear los valores numéricos según la moneda seleccionada usando
el formato nativo del sistema para esa moneda y locale: símbolo de moneda, separador
de miles y separador decimal acordes a la convención (p. ej. CLP `$1.500.000`, USD
`$1,500.00`, EUR `€1.500,00`). La cantidad de decimales mostrados SHALL ser la
estándar de la moneda. El formateo de presentación SHALL ser una función pura
separada del motor de cálculo: el motor opera exclusivamente con valores numéricos.

#### Scenario: Formato CLP
- **WHEN** se formatea el valor 1500000 con moneda CLP
- **THEN** la representación incluye el símbolo `$`, el separador de miles con punto y cero decimales (p. ej. `$1.500.000` en locale es_CL)

#### Scenario: Formato USD
- **WHEN** se formatea el valor 1500 con moneda USD
- **THEN** la representación incluye dos decimales y los separadores según el locale del sistema (p. ej. `$1,500.00` en locale en_US)

#### Scenario: Formato EUR
- **WHEN** se formatea el valor 1500 con moneda EUR
- **THEN** la representación usa el símbolo `€` y dos decimales con separadores según el locale del sistema (p. ej. `1.500,00 €` o `€1.500,00` según locale)

#### Scenario: Presentación independiente del cálculo
- **WHEN** el motor calcula 843291.3687 con sueldo en CLP y se cambia la moneda a USD
- **THEN** el valor numérico calculado permanece invariante y solo cambia su representación textual

#### Scenario: Indicador compacto sin símbolo (Menu Bar)
- **WHEN** el indicador de la barra de menú muestra 1500000 CLP (locale es_CL)
- **THEN** la representación usa los mismos decimales, redondeo y separadores que el formato completo pero SIN el símbolo de moneda (p. ej. `1.500.000` en lugar de `$1.500.000`), que visualmente lo sustituye un glifo de moneda

### Requirement: Redondeo de presentación
El valor mostrado en la UI SHALL redondearse a la cantidad de decimales estándar de
la moneda. El redondeo es exclusivamente de presentación: el motor conserva el valor
con precisión sub-segundo. El valor mostrado SHALL ser siempre menor o igual al
sueldo formateado del período.

#### Scenario: Redondeo a la unidad menor
- **WHEN** el valor calculado es 843291.48 con moneda CLP (0 decimales)
- **THEN** la UI muestra el valor redondeado a unidades (843.291 en formato CLP)

#### Scenario: Moneda con decimales
- **WHEN** el valor calculado es 1234.5678 con moneda USD (2 decimales)
- **THEN** la UI muestra 1234.57 (o `1,234.57` según locale)
