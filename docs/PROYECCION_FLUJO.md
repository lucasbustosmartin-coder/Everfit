# Proyección en la tabla Flujo por mes

Documentación de referencia para la **proyección** de ingresos, egresos y derivados (G/P, ratios Sueldos/ingresos y Alquileres/ingresos en columnas «Proy.»). Implementación en **`dashboard.html`** (funciones `nMesesCalendarioAnteriores`, `claveMesEstrictamenteAnterior`, `proyeccionDesdeSerie`, bloque `renderizar` con permiso `ver_proyeccion`). Configuración por usuario en **`config_dashboard`** (modal «Configuración de proyección»).

---

## 1. Qué es la proyección en pantalla

- Se agregan columnas **Proy.** después de los meses que ya tienen filas en la tabla (histórico desde datos).
- El **primer mes proyectado** es siempre el **mes en curso** en **Argentina** (`America/Argentina/Buenos_Aires`), misma lógica que `keyMesEnCurso()`.
- La cantidad de columnas proyectadas la define **«Meses a proyectar»** (1–12).
- El método estadístico y el tamaño de la ventana los define la config: **Método**, **Meses de historia** (N = 3, 6, 12 o 24), **Recorte %** (solo promedio recortado).

Las **tarjetas** de resumen (Total ingresos / egresos / G-P) **no** usan las columnas Proy.; siguen siendo totales sobre datos **reales/pendientes/proyectados** de `base_everfit` según las exclusiones generales (ver **`docs/EXCLUSIONES_DASHBOARD.md`**).

---

## 2. Regla crítica: qué meses entran en la base numérica

**Nunca** se usan, como insumo del cálculo de proyección:

- el **mes en curso** (aunque existan movimientos y una columna «real» en la tabla para ese mes), ni  
- **ningún mes posterior** (futuro respecto del mes en curso).

Es decir: solo participan claves de mes **`YYYY-MM` estrictamente anteriores** al primer mes proyectado (= mes en curso). La comparación es lexicográfica sobre strings `YYYY-MM`, coherente con el orden cronológico.

Esto **no borra** datos: si hay columnas para el mes en curso o futuros, **siguen mostrándose** como hasta ahora. Solo la **ventana de historia** que alimenta la proyección **ignora** esos meses por completo.

En código:

1. `nMesesCalendarioAnteriores(primerMesProy, N)` arma los **N** meses calendario inmediatamente **antes** de `primerMesProy` (que es `keyMesEnCurso()`).
2. Se filtra con `claveMesEstrictamenteAnterior(k, primerMesProy)` por si hubiera alguna inconsistencia.
3. Al mapear importes desde `porMesFlujo` / sueldos / alquileres, `montoMesSoloSiAnteriorAlProyectado` devuelve **0** si la clave no es estrictamente anterior al mes en curso (**doble blindaje**).

Si un mes de la ventana no tiene movimientos, el valor es **0** (no se completa con el mes en curso ni con futuros).

---

## 3. Ventana de «Meses de historia» (N)

- No es «los últimos N meses que aparezcan en la tabla con datos».
- Es **siempre N meses calendario consecutivos**, terminando en el mes **inmediatamente anterior** al mes en curso.

**Ejemplo:** mes en curso **marzo 2026**, N = **6**.  
Meses base (orden cronológico): **sep-2025, oct-2025, nov-2025, dic-2025, ene-2026, feb-2026**.  
**Mar-2026** no entra en la base; es donde empieza **Proy. 1**.

---

## 4. Cómo se encadenan Proy. 1, Proy. 2, …

Para cada serie (ingresos, egresos, sueldos, alquileres) se llama a **`proyeccionDesdeSerie(valores, N, agg, cantidad)`**:

- `valores`: array de **longitud N** con los importes de los N meses calendario anteriores al mes en curso (0 si no hay datos).
- **Proy. 1:** `agg` aplicado a esos **N** valores reales.
- **Proy. 2:** `agg` sobre los **últimos N−1** valores de esa base **más** el valor ya calculado de **Proy. 1** (en ese orden: primero los reales «viejos», luego la proyección inmediata anterior).
- **Proy. k:** análogo: **N−k+1** valores reales tomados del **final** de la ventana inicial **más** las **k−1** proyecciones previas de la misma serie.

Así se cumple el período configurado sin reutilizar el mes en curso ni meses futuros como «reales».

---

## 5. Permisos y persistencia

- Solo usuarios con permiso **`ver_proyeccion`** ven columnas Proy., ratios proyectados y el botón de configuración (ver **`docs/SEGURIDAD.md`**).
- Valores guardados: `proyeccion_metodo`, `proyeccion_meses`, `proyeccion_cantidad`, `proyeccion_recorte` en **`config_dashboard`** (script SQL `sql/supabase_proyeccion_permiso_y_config.sql`).

---

## 6. Relación con otras exclusiones del flujo

La tabla Flujo (y el gráfico G/P alineado) aplican además exclusiones por **centro** y **concepto** al armar `porMesFlujo` (ver **`docs/EXCLUSIONES_DASHBOARD.md`**). La proyección lee **solo** esos agregados mensuales ya filtrados; la regla «no usar mes en curso ni posteriores» se aplica **encima**, sobre las claves de mes.

---

## 7. Referencias en código (`dashboard.html`)

| Elemento | Rol |
|----------|-----|
| `keyMesEnCurso()` | Primer mes proyectado (Argentina). |
| `nMesesCalendarioAnteriores` | N meses calendario antes del mes en curso. |
| `claveMesEstrictamenteAnterior` | Asegura `key < mesEnCurso` en filtros y montos. |
| `proyeccionDesdeSerie` | Ventana móvil real + proyecciones previas. |
| `montoMesSoloSiAnteriorAlProyectado` | No suma importes de mes en curso/futuro en la base. |

---

## 8. Texto visible para el usuario

- Modal **Configuración de proyección**: resumen en lenguaje natural.
- Pie de tabla Flujo: fila «Proyección» con método, N meses y encadenamiento Proy. 2, 3…

Para el detalle normativo, esta página es la fuente de verdad.
