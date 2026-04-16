# Importación: transacciones de asistencia (por sucursal)

Los Excel exportados del sistema de control de asistencia (título **Transacciones** en la hoja) tienen el mismo patrón en las tres sucursales:

| Archivo de referencia | Sucursal |
|----------------------|----------|
| `docs/TransaccionesCramer.xlsx` | Cramer |
| `docs/TransaccionesCabildo.xlsx` | Cabildo |
| `docs/TransaccionesMigueletes.xlsx` | Migueletes |

## Estructura del Excel

- **Hoja:** `Sheet1` (primera hoja).
- **Metadatos** (filas previas): texto “Transacciones”, “Hora de exportación…”, “Operador…”, “Periodo…”.
- **Fila de encabezados:** contiene **Nombre**, **Apellido** en las dos primeras columnas; a partir de ahí se detecta automáticamente la fila.
- **Cramer y Migueletes:** columnas `Nombre`, `Apellido`, `ID`, `Fecha`, `Tiempo`.
- **Cabildo:** las mismas más `Departamento`, `Semana`, temperatura, tipo de pase, método de verificación, punto de control, etc. (16 columnas en total).

Los textos se **normalizan** (trim, sin acentos para matchear cabeceras) y se guardan en columnas nullable donde la sucursal no aporta dato.

## Tabla en Supabase

1. En **SQL Editor**, ejecutá `sql/supabase_transacciones_asistencia.sql` (o reaplicá el archivo si ya existía la tabla) para tener la función **`get_anios_transacciones_asistencia`** (combo **Año** = años con datos) y el permiso **`ver_asistencia`** (menú Asistencia y lectura de la tabla; configurable por rol en **Seguridad**).
2. RLS: **SELECT** solo con permiso **`ver_asistencia`**; **INSERT** y **DELETE** solo con **`upload_base`** (mismo criterio que “Actualizar base” / Importar asistencia).
3. Si la tabla ya estaba creada con política de lectura abierta a todos, ejecutá **`sql/supabase_asistencia_ver_permiso.sql`** para registrar el permiso, los grants por rol y actualizar la política **SELECT**.

## Carga desde el dashboard

1. Iniciá sesión con un usuario que tenga permiso **Actualizar base** (`upload_base`).
2. Botón **Importar asistencia** (barra de filtros, junto a “Actualizar base”).
3. Elegí **sucursal** si el nombre del archivo no contiene *Cramer*, *Cabildo* o *Migueletes*.
4. Seleccioná el `.xlsx` y confirmá **Importar**.

**Comportamiento:** se borran **todas** las filas de `transacciones_asistencia` con esa sucursal y se insertan las del archivo. No modifica `base_everfit` ni el log de “Última actualización” de la base contable.

## Archivos de ejemplo en el repo

Los tres Excel en `docs/` sirven como referencia de formato; podés volver a exportarlos desde el sistema origen cuando actualices datos.
