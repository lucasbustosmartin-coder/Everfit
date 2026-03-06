# Tipo de cambio: sincronizar desde Sistema-Contable-Nuevo

Para tener montos en **ARS y USD** en Everfit, se usan los tipos de cambio (MEP, CCL, oficial). La **fuente de verdad** es el proyecto **Sistema-Contable-Nuevo**, tabla **`tipos_cambio_global`**.

El script de sync lee esa tabla por API y escribe en la tabla **`tipo_de_cambio`** del proyecto Everfit (misma estructura: `fecha`, `usd_mep`, `usd_ccl`, `usd_oficial`).

---

## Opción 1 – Sincronización a Everfit (recomendada)

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

## Opción 2 – Consumo en vivo por API (siempre actualizado)

En lugar de copiar datos, la app de Everfit **consume directo** la API del proyecto Sistema-Contable-Nuevo. Cada vez que necesitás tipos de cambio, hacés un `select` al origen. No hace falta correr el script de sync: los datos son siempre los del origen.

**Ventaja:** un registro nuevo en el origen se ve en Everfit en la siguiente carga o refetch.  
**Desventaja:** Everfit depende de que Sistema-Contable-Nuevo esté arriba; además hay que usar una key con acceso (ver abajo).

Ejemplo en la app (dos clientes Supabase):

```javascript
import { createClient } from '@supabase/supabase-js';

// Cliente Everfit (base_everfit, etc.)
const supabaseEverfit = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

// Cliente origen (solo para tipos de cambio)
const supabaseOrigen = createClient(
  import.meta.env.VITE_ORIGEN_TC_URL,
  import.meta.env.VITE_ORIGEN_TC_ANON_KEY   // ver nota sobre RLS abajo
);

// Cuando necesitás tipos de cambio (siempre frescos del origen)
const { data: tiposCambio } = await supabaseOrigen
  .from('tipos_cambio_global')
  .select('fecha, usd_mep, usd_ccl, usd_oficial')
  .order('fecha', { ascending: true });
```

**RLS en el origen:** en Sistema-Contable-Nuevo la tabla `tipos_cambio_global` tiene RLS solo para **authenticated**. Para leer desde el frontend de Everfit con **anon** tenés que: (1) agregar en el origen una política que permita `SELECT` para `anon` en esa tabla (si te parece bien que sea lectura pública), o (2) tener un backend en Everfit que use la **service_role** del origen y exponga un endpoint; el frontend llama a ese endpoint en lugar de al Supabase del origen.

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
