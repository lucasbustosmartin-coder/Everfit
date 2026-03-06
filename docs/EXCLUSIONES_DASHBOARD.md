# Exclusiones del dashboard Everfit

En todo el dashboard se **incluyen** reales, pendientes y **proyectados** (ya no se excluye por `real_pendiente = "proyectado"`). Una fila de `base_everfit` **no se incluye** solo si cumple las condiciones siguientes según la vista.

## 1. Saldo Inicial (todas las vistas)

- **Campo:** `centro_de_costos`
- **Condición:** valor igual (ignorando mayúsculas/minúsculas) a **`Saldo Inicial`**
- **Motivo:** no es un movimiento del período; es un saldo de apertura y no debe sumarse como ingreso ni egreso.

## 2. Beneficiario Dividendos (solo tabla Flujo por mes)

- **Campo:** `beneficiario`
- **Condición:** valor igual (ignorando mayúsculas/minúsculas) a **`Dividendos`**
- **Dónde:** únicamente en el **contenido de la tabla Flujo por mes** (columnas de meses reales, proyectadas y columna Total). **No** se aplica en tarjetas, gráfico G/P ni en el modal Detalle.
- **Motivo:** excluir este beneficiario solo de la tabla de flujo y de su proyección.

---

## Dónde se aplica

- **Tarjetas (Total ingresos, Total egresos, G/P Total)** y **Gráfico G/P mensual:** solo exclusión 1 (Saldo Inicial). Incluyen reales, pendientes, proyectados y Dividendos.
- **Tabla Flujo por mes** (celdas, proyección y Total de la tabla): exclusiones 1 y 2 (Saldo Inicial, beneficiario Dividendos). Incluyen reales, pendientes y proyectados.
- **Modal Detalle** (por concepto / por beneficiario): solo exclusión 1. Incluyen reales, pendientes y proyectados.

Cada sección (tarjetas, gráfico, flujo por mes) tiene un icono de ayuda (?) que muestra sus reglas de exclusión.

En el código (`dashboard.html`):

- `excluirSaldoInicial(r)` → excluye por `centro_de_costos === 'saldo inicial'`
- `debeExcluirse(r)` → `excluirSaldoInicial(r)` (usado en todas las vistas; ya no se excluye proyectado)
- `excluirBeneficiarioDividendosFlujo(r)` → excluye por `beneficiario === 'dividendos'`; se usa **solo** para `porMesFlujo` (tabla Flujo por mes).
