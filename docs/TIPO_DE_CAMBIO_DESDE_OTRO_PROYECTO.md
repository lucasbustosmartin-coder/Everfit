# Tipo de cambio: sincronizar desde Sistema-Contable-Nuevo

Para tener montos en **ARS y USD** en Everfit, se usan los tipos de cambio (MEP, CCL, oficial). La **fuente de verdad** es el proyecto **Sistema-Contable-Nuevo**, tabla **`tipos_cambio_global`**.

- **Opción 2 (implementada):** el dashboard lee **directo por API** desde `tipos_cambio_global` del origen. Si configurás `ORIGEN_TC_URL` y `ORIGEN_TC_ANON_KEY`, los datos se actualizan solos al cargar/refrescar.
- **Opción 1:** script de sync que copia a la tabla local `tipo_de_cambio` de Everfit (útil si no querés exponer lectura anon en el origen).

---

## Opción 2 – Consumo por API desde el dashboard (implementada)

El dashboard puede leer tipos de cambio **directamente** del proyecto Sistema-Contable-Nuevo. No hace falta correr el script de sync: cada vez que cargás o refrescás, trae los datos del origen.

**Pasos:**

1. **En Sistema-Contable-Nuevo:** permitir lectura anon en `tipos_cambio_global`. En Supabase SQL Editor del **proyecto origen** ejecutá el contenido de **`docs/ORIGEN_RLS_TIPOS_CAMBIO_ANON.sql`** (crea política `SELECT TO anon`).
2. **En Everfit (local):** en `config.js` definí:
   ```js
   window.ORIGEN_TC_URL = 'https://XXXX.supabase.co';   // URL del proyecto Sistema-Contable-Nuevo
   window.ORIGEN_TC_ANON_KEY = 'eyJ...';               // anon key de ese proyecto (Settings → API)
   ```
3. **En Vercel (producción):** en Environment Variables agregá `ORIGEN_TC_URL` y `ORIGEN_TC_ANON_KEY` (mismos valores). Redeploy para que el build genere `config.js` con esas claves.

Si **no** configurás origen, el dashboard sigue leyendo de la tabla local **`tipo_de_cambio`** de Everfit (y podés seguir usando el script de sync cuando quieras).

---

## Opción 1 – Sincronización a Everfit (script manual)

Everfit tiene su **propia tabla** `tipo_de_cambio`. Un script lee desde **Sistema-Contable-Nuevo** (`tipos_cambio_global`) y actualiza Everfit.

**Ventajas:** Everfit no depende del otro proyecto en cada request; todo se consulta en tu Supabase. Podés correr el script cuando quieras (manual o cron).

**Pasos:**

1. En el **proyecto Everfit** (Supabase): ejecutá `sql/supabase_tipo_de_cambio.sql` para crear la tabla.
2. En el **.env** de Everfit agregá las variables del proyecto **Sistema-Contable-Nuevo**:
   ```env
   SUPABASE_ORIGEN_TC_URL=https://XXXX.supabase.co
   SUPABASE_ORIGEN_TC_SERVICE_ROLE_KEY=eyJ...
   ```
   En Sistema-Contable-Nuevo la tabla `tipos_cambio_global` tiene RLS solo para **authenticated**; por eso el script usa la **service_role** del ese proyecto para leer (nunca en frontend, solo en el script en tu máquina).
3. Ejecutá el script:
   ```bash
   cd "/Users/lucasb/Escritorio - MacBook Air de Lucas/Everfit"
   python scripts/sync_tipo_de_cambio_desde_origen.py
   ```
   El script trae todas las filas de `tipos_cambio_global` y las inserta/actualiza en `tipo_de_cambio` de Everfit (por fecha, sin duplicar).

En tu app o dashboard de Everfit consultás siempre **el Supabase de Everfit**:  
`client.from('tipo_de_cambio').select('fecha, usd_mep, usd_ccl, usd_oficial')`.

---

## Detalle técnico Opción 2 (referencia)

El dashboard usa un segundo cliente Supabase cuando `ORIGEN_TC_URL` y `ORIGEN_TC_ANON_KEY` están definidos, y hace:

```javascript
clientOrigen.from('tipos_cambio_global').select('fecha, usd_mep, usd_ccl, usd_oficial').order('fecha')
```

**RLS en el origen:** si en Sistema-Contable-Nuevo la tabla solo permitía `authenticated`, hay que ejecutar `docs/ORIGEN_RLS_TIPOS_CAMBIO_ANON.sql` en ese proyecto para permitir `SELECT TO anon` (solo lectura; no expone datos sensibles).

---

## Opción 3 – API + Realtime (refresco automático cuando cambia el origen)

Podés **combinar** consumo por API con **Supabase Realtime**: te suscribís a cambios en `tipos_cambio_global` del proyecto origen y, cuando haya INSERT/UPDATE/DELETE, refrescás los datos (por ejemplo volvéndolos a pedir por API o actualizando el estado local).

Así, cuando en Sistema-Contable-Nuevo alguien carga un nuevo tipo de cambio, la app de Everfit puede actualizar sola sin recargar la página.

Ejemplo (mismo cliente `supabaseOrigen` de arriba):

```javascript
// Suscripción a cambios en la tabla del origen
const channel = supabaseOrigen
  .channel('tipos_cambio_global')
  .on(
    'postgres_changes',
    { event: '*', schema: 'public', table: 'tipos_cambio_global' },
    () => {
      // Cuando cambia algo en el origen, volvé a traer la lista
      refetchTiposCambio();
    }
  )
  .subscribe();

// refetchTiposCambio() hace el select a tipos_cambio_global y actualiza el estado
```

Realtime también respeta RLS del origen: si solo `authenticated` puede leer, la suscripción tiene que usar una key que tenga ese acceso (o la política que permita anon si la agregaste).

---

## Resumen

| | Opción 1 (sync) | Opción 2 (API) | Opción 3 (API + Realtime) |
|---|----------------|----------------|---------------------------|
| Dónde se lee en Everfit | Tabla `tipo_de_cambio` de Everfit | API del origen | API del origen |
| ¿Se ve un registro nuevo del origen al toque? | No (hay que correr el script o cron) | Sí (en la siguiente carga/refetch) | Sí (al recibir el evento Realtime) |
| Dependencia del origen | Solo al hacer sync | En cada request | En cada request + suscripción |
| Recomendación | Si preferís no depender del origen en lectura | Si querés datos siempre frescos sin sync | Si querés datos frescos y actualización en vivo en la UI |

Para **Opción 2 u Opción 3** desde el frontend necesitás que el origen permita lectura con **anon** en `tipos_cambio_global`, o un backend en Everfit que use la service_role del origen.

---

## Estructura

- **Origen (Sistema-Contable-Nuevo):** tabla `tipos_cambio_global` → columnas `fecha`, `usd_mep`, `usd_ccl`, `usd_oficial`.
- **Everfit:** tabla `tipo_de_cambio` → mismas columnas (más `id`, `creado_en`).

En la app: con `fecha` en formato `YYYY-MM-DD`, buscás la fila y usás `usd_mep`, `usd_ccl` o `usd_oficial` para convertir entre ARS y USD.
