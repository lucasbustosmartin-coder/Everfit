# Exclusiones del dashboard Everfit

En todo el dashboard se **incluyen** reales, pendientes y **proyectados** (ya no se excluye por `real_pendiente = "proyectado"`). Una fila de `base_everfit` puede quedar fuera del agregado según la vista.

## 1. Saldo Inicial por centro de costos (casi todas las vistas)

- **Campo:** `centro_de_costos`
- **Condición:** valor igual (ignorando mayúsculas/minúsculas y espacios) a **`Saldo Inicial`**
- **Dónde:** tarjetas resumen, tabla Flujo por mes, gráfico G/P mensual, ratios derivados del flujo, etc.
- **Motivo:** no sumar el saldo de apertura como movimiento del período.

## 2. Concepto Inversiones o Saldo Inicial (solo Flujo y gráfico G/P)

- **Campo:** `concepto`
- **Condición:** valor igual (ignorando mayúsculas/minúsculas) a **`Inversiones`** o **`Saldo Inicial`**
- **Dónde:** **únicamente** el agregado `porMesFlujo`: **tabla Flujo por mes**, **gráfico G/P mensual** y los **ratios** (p. ej. Sueldos/ingresos, Alquileres/ingresos) que se calculan con los mismos datos filtrados que esa tabla.
- **No aplica a:** **tarjetas** (totales de ingresos/egresos/G-P del resumen) ni al **modal Detalle** por concepto/beneficiario.
- **Motivo:** ver un flujo más alineado a operación; las tarjetas y el detalle siguen mostrando el universo completo salvo el punto 1.

> **Nota:** Una fila puede tener `centro_de_costos` = Saldo Inicial (excluida en todas partes por §1) o solo `concepto` = Saldo Inicial sin ese centro: en ese caso **entra en tarjetas** pero **no** en tabla Flujo ni gráfico G/P.

---

## Resumen por vista

| Vista | Exclusión centro Saldo Inicial | Exclusión concepto Inversiones / Saldo Inicial |
|--------|-------------------------------|-----------------------------------------------|
| Tarjetas resumen | Sí | No |
| Tabla Flujo por mes y gráfico G/P | Sí | Sí |
| Modal Detalle | Sí (solo centro) | No |

---

En el código (`dashboard.html`):

- `excluirSaldoInicial(r)` / `debeExcluirse(r)` → `centro_de_costos === 'saldo inicial'`
- `excluirConceptoFlujoYGraficoGP(r)` → `concepto` es `inversiones` o `saldo inicial`; se usa junto con `debeExcluirse` al armar `porMesFlujo` y los egresos por mes para ratios que comparten ese filtro.

Los íconos **(?)** junto a tarjetas, gráfico y tabla Flujo resumen estas reglas.

---

## Proyección estadística (columnas Proy.)

Las reglas anteriores definen **qué filas** entran en los agregados por mes. La **proyección** del Flujo (método configurable, ventana de N meses) está documentada en **`docs/PROYECCION_FLUJO.md`**. En particular: el cálculo **no incorpora** como base los importes del **mes en curso** ni de **meses posteriores**, aunque esos meses tengan datos y columnas en la tabla.
