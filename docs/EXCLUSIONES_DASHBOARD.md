# Exclusiones del dashboard Everfit

En todo el dashboard se **incluyen** reales, pendientes y **proyectados** (ya no se excluye por `real_pendiente = "proyectado"`). Una fila de `base_everfit` **no se incluye** solo si cumple las condiciones siguientes según la vista.

## 1. Saldo Inicial (todas las vistas)

- **Campo:** `centro_de_costos`
- **Condición:** valor igual (ignorando mayúsculas/minúsculas) a **`Saldo Inicial`**
- **Motivo:** no es un movimiento del período; es un saldo de apertura y no debe sumarse como ingreso ni egreso.

## 2. Beneficiario Dividendos (tabla Flujo por mes y gráfico G/P mensual)

- **Campo:** `beneficiario`
- **Condición:** valor igual (ignorando mayúsculas/minúsculas) a **`Dividendos`**
- **Dónde:** **tabla Flujo por mes** y **gráfico G/P mensual**. **No** se aplica en **tarjetas** resumen ni en el modal Detalle.
- **Motivo:** ver el flujo operativo sin dividendos en esas vistas; las tarjetas muestran totales completos (incluyen Dividendos).

---

## Dónde se aplica

- **Tarjetas (Total ingresos, Total egresos, G/P Total):** solo exclusión 1 (Saldo Inicial). Incluyen Dividendos y la suma de todos los movimientos reales/pendientes/proyectados; **no** suman columnas de proyección “Proy.” de la tabla.
- **Gráfico G/P mensual** y **tabla Flujo por mes** (celdas y filas): exclusiones 1 y 2. La columna Total de la tabla puede sumar además meses proyectados si el usuario tiene permiso de proyección.
- **Modal Detalle** (por concepto / por beneficiario): solo exclusión 1. Incluyen reales, pendientes y proyectados (incluye Dividendos en el desglose).

Cada sección (tarjetas, gráfico, flujo por mes) tiene un icono de ayuda (?) que muestra sus reglas de exclusión.

En el código (`dashboard.html`):

- `excluirSaldoInicial(r)` → excluye por `centro_de_costos === 'saldo inicial'`
- `debeExcluirse(r)` → `excluirSaldoInicial(r)` (usado en todas las vistas; ya no se excluye proyectado)
- `excluirBeneficiarioDividendosFlujo(r)` → excluye por `beneficiario === 'dividendos'`; se usa para `porMesFlujo` (tabla Flujo por mes y gráfico G/P mensual). Las tarjetas usan `porMes` (incluyen Dividendos).
