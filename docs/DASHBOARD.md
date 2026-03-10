# Dashboard Everfit

El **Dashboard** es una única página HTML (`dashboard.html`) con:

- **Flujo por mes:** tabla con columnas Mes-Año, Ingresos, Egresos, G/P, más resumen con totales. **Hacé clic en una fila** para abrir el modal de detalle.
- **Modal Detalle:** se abre al hacer clic en cualquier fila del Flujo por mes. Tiene dos pestañas: **Detalle por Concepto** y **Detalle por Beneficiario**. La tabla está **invertida**: **periodos en columnas**, **Item** (Ingresos, Egresos, G/P) **en filas**. La primera columna (Item) queda anclada al desplazar en horizontal; la fila de periodos (encabezado) queda anclada al desplazar en vertical.

Los datos se leen de la tabla `base_everfit` en Supabase (Everfit). **Exclusiones:** no se incluyen en ningún cálculo las filas con `centro_de_costos = 'Saldo Inicial'` ni con `real_pendiente = 'proyectado'`. Detalle en **`docs/EXCLUSIONES_DASHBOARD.md`**.

## Requisitos

1. **Clave anon de Everfit**  
   En Supabase → Project Settings → API copiá la **anon** key (public). En `config.js` definí `window.SUPABASE_ANON_KEY` con esa clave.

2. **Auth y permisos (recomendado)**  
   Para que la app pida **login por email** y controle permisos por rol (Admin, Encargado, Visor), seguí **`docs/SEGURIDAD.md`**: ejecutá `sql/supabase_seguridad.sql`. Eso habilita lectura solo para usuarios autenticados y restringe "Actualizar base" y "Asignar perfiles" por rol.

   Si **no** usás el módulo de seguridad, ejecutá solo **`sql/supabase_rls_base_everfit_anon_read.sql`** para permitir lectura anónima de `base_everfit`.

3. **Logo (opcional)**  
   El título de cada vista muestra **Logo.png** a la izquierda. Colocá el archivo **`Logo.png`** en la misma carpeta que `dashboard.html` (raíz del proyecto). Si no existe, solo se muestra el título. Al agregar nuevos componentes al menú, usá el mismo bloque `<header class="page-header">` con `<img class="page-logo">` y `<h1 id="page-title">` para el nombre del componente.

4. **Logo reducido (favicon)**  
   **`favicon.png`** es el icono de la solapa del navegador (y donde el sistema use el favicon): solo las letras **E** y **F** con el mismo estilo del logo (E en gris oscuro, F en cyan). Ya está referenciado en `dashboard.html` con `<link rel="icon" href="favicon.png">`. Para usar este icono en otro lugar en el futuro (“aplicar logo reducido”), usá el archivo **`favicon.png`** en la raíz del proyecto.

## Cómo usar

- **Local:** abrí `dashboard.html` en el navegador (doble clic o `open dashboard.html`). Si abrís desde `file://`, algunos navegadores pueden bloquear las peticiones a Supabase; en ese caso serví la carpeta con un servidor local (ej. `npx serve .` en la raíz del proyecto).
- **Vercel:** al desplegar el repo, la URL de la app sirve `dashboard.html` si configuraste un rewrite de la raíz a `dashboard.html` (ver `vercel.json` o la doc de Git/Vercel).

## Estructura

- **Resumen:** tres tarjetas con Total ingresos, Total egresos y G/P (ganancia/pérdida).
- **Flujo por mes:** tabla con una fila por mes (ordenada cronológicamente), totales en el pie.

Los montos se obtienen de `base_everfit`: se agrupa por mes usando `fecha_pago` y se suman `importe` según `ingresos_egresos` (Ingresos / Egresos). Podés elegir moneda ARS/USD y tipo de dólar (MEP, CCL, Oficial); en USD se convierte con la tasa de `fecha_pago` (o la anterior disponible) desde la tabla `tipo_de_cambio`. Las exclusiones (Saldo Inicial, proyectado) se aplican en resumen, flujo por mes y en el modal Detalle.

### Actualizar base (upload)

En la barra de filtros, a la derecha, hay un botón **Actualizar base** (icono de subida). Abre un modal que permite:

1. Seleccionar un archivo Excel (`.xlsx`) con la hoja **"Base"** (mismo formato que `Base/Base_Everfit.xlsx`).
2. Confirmar: se **vacía** la tabla `base_everfit` y se **vuelven a cargar** todas las filas del Excel.

**Requisito:** para usar esta función desde el navegador hay que definir en `config.js` la clave **`SUPABASE_SERVICE_ROLE_KEY`** (Supabase → Project Settings → API → service_role). **Solo usala en entorno de confianza** (ej. local); no subas esa clave al repositorio. Si no está configurada, el modal indica que podés usar en su lugar el script **`python scripts/volcar_excel_a_supabase.py`** para actualizar la base desde la terminal.

Debajo de las tarjetas de resumen (Total ingresos, Total egresos, G/P) se muestra **Última actualización** con ícono de reloj, fecha y hora en Argentina y el email de quien ejecutó "Actualizar base". Para que esto funcione, ejecutá en Supabase SQL Editor el script **`sql/supabase_log_actualizacion_base.sql`** (crea la tabla `log_actualizacion_base` y la RPC `log_actualizacion_base()`). Si no ejecutaste ese script, la leyenda no se muestra y el upload sigue funcionando igual.
