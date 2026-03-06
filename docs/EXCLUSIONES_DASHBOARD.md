# Exclusiones del dashboard Everfit

En **todo** el dashboard (resumen, flujo por mes, detalle por concepto y detalle por beneficiario) se aplican las mismas exclusiones. Una fila de `base_everfit` **no se incluye en ningún cálculo** si cumple alguna de las siguientes condiciones.

## 1. Saldo Inicial

- **Campo:** `centro_de_costos`
- **Condición:** valor igual (ignorando mayúsculas/minúsculas) a **`Saldo Inicial`**
- **Motivo:** no es un movimiento del período; es un saldo de apertura y no debe sumarse como ingreso ni egreso en los totales.

## 2. Proyectado

- **Campo:** `real_pendiente`
- **Condición:** valor igual (ignorando mayúsculas/minúsculas) a **`proyectado`**
- **Motivo:** solo se contabilizan movimientos **reales** o **pendientes reales**. Los registros marcados como "proyectado" se excluyen de ingresos, egresos, G/P y de todas las vistas (flujo por mes, detalle por concepto, detalle por beneficiario).

---

## Dónde se aplica

- Resumen (Total ingresos, Total egresos, G/P)
- Tabla **Flujo por mes**
- Modal **Detalle** → solapas **Detalle por Concepto** y **Detalle por Beneficiario**

En el código (`dashboard.html`) las exclusiones están centralizadas en:

- `excluirSaldoInicial(r)` → excluye por `centro_de_costos === 'saldo inicial'`
- `excluirProyectado(r)` → excluye por `real_pendiente === 'proyectado'`
- `debeExcluirse(r)` → `excluirSaldoInicial(r) || excluirProyectado(r)`

Cualquier nuevo cálculo o vista que use datos de `base_everfit` debe usar `debeExcluirse(r)` para mantener coherencia.
