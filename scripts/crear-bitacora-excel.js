const XLSX = require('xlsx');
const path = require('path');
const {
  preservarFechasHistoricasLog,
  preservarFechasHistoricasVersiones,
} = require('../../scripts/lib/lyp-bitacora-fechas');

const outPath = path.join(__dirname, '..', 'Bitacora_tareas.xlsx');
const projectRoot = path.join(__dirname, '..');

// --- Hoja Log
const datosLog = [
  ['Fecha', 'Hora', 'titulo_tarea', 'desc_tarea', 'etapa'],
  ['__HOY__', '__AHORA__', 'Bitácora Everfit', 'Regla bitácora (Log, Resumen, Ref Git y Vercel, Versiones, Tecnología) y script crear-bitacora-excel.js sin solapa Presupuesto.', 'Setup'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.1', 'Dashboard con login, Seguridad (roles), Actualizar base, flujo por mes, gráfico G/P. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.2', 'Config desde env en Vercel, outputDirectory, favicon EF, script vercel-setup-env, docs. Push a main.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.3', 'Proyección en Flujo por mes (config, ventana móvil), total tabla con proyectados, tarjetas solo reales, encabezado con fondo en columnas proyectadas.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.4', 'Seguridad: permisos por rol configurables (Admin, Encargado, Visor) con icono y toggles on/off. SQL supabase_seguridad_permisos_editable.sql.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.5', 'Botón refresh en barra (actualizar permisos y vista sin cerrar sesión). Auto-refresh al cambiar permisos en Seguridad.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.6', 'Incluir proyectado en tarjetas, gráfico y flujo. Help (?) con reglas de exclusión en los tres. Tarjetas en una card con help dentro. Config proyección por usuario (config_dashboard). Exclusión Dividendos solo tabla.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.7', 'Gráfico G/P Mensual: ocultar leyenda (barras verdes/rojas sin leyenda engañosa).', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.8', 'Gráfico G/P: barras con G/P=0 visibles (minBarLength, color gris, tooltip "ingresos = egresos").', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.9', 'Tipos de cambio por API desde Sistema-Contable-Nuevo (Opción 2). Fix upload Excel: fechas como ISO. ORIGEN_TC_* en config y build.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.10', 'Modal gráfico por ítem en detalle (concepto/beneficiario) e icono en totales (Ingresos, Egresos, G/P). Icono sin contorno. Botones sucursal seleccionado en turquesa (#0d9488).', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.11', 'Log actualización base (tabla, RPC, leyenda Última actualización con reloj y hora Argentina). Progreso eliminación en upload (Eliminando X / N). Fix RPC sin .catch.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.12', 'Dashboard responsive para móviles (breakpoints 768px y 480px, touch 44px, safe-area, tablas y modales adaptados). Regla responsive en reglas-everfit.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.13', 'Filtro multi-sucursal (varias sucursales a la vez). Seguridad: sucursales permitidas por usuario (Admin configura qué ve cada uno). Total respeta sucursales asignadas. SQL supabase_sucursales_por_usuario.sql.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.14', 'Modales: no cerrar al elegir opción de select (mousedown+click en backdrop). Helper setupBackdropCloseOnlyOnRealClick en todos los modales.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.15', 'Tipos de cambio cargados con paginación (límite PostgREST ~1000 filas por consulta). Constante SUPABASE_PAGE_SIZE alineada con base_everfit. Regla reglas-everfit actualizada. Despliegue a producción.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Dashboard fechas Argentina', 'Gráfico G/P mensual y proyección: mes actual con calendario Argentina (no zona del navegador). fecha_pago ISO/timestamptz: agrupar por día en Argentina (evita slice UTC).', 'Corrección'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.16', 'Fechas Argentina en gráfico G/P (rango 13 meses y mes en curso/proyección) y agrupación por día calendario en fecha_pago con hora desde Supabase. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.17', 'Gráfico G/P Mensual usa porMesFlujo: mismos totales por mes que la tabla Flujo (excluye Dividendos). Ayuda (?), pie de tabla y docs/EXCLUSIONES_DASHBOARD.md.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Dashboard local: mensaje si falta config', 'Mensaje visible fuera de app-content cuando falta SUPABASE_ANON_KEY (config.js en .gitignore). Errores RPC/sesión muestran panel en la app en lugar de pantalla en blanco.', 'Corrección'],
  ['__HOY__', '__AHORA__', 'Tarjetas: otra vez con Dividendos', 'Cards vuelven a porMes (incluyen Dividendos); tabla y gráfico siguen con porMesFlujo. Criterio documentado en EXCLUSIONES_DASHBOARD.md.', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.18', 'Fechas Argentina en fecha_pago y rango G/P; gráfico alineado con tabla Flujo (porMesFlujo); tarjetas con porMes (incluye Dividendos); mensaje si falta config local; manejo errores RPC/sesión; docs EXCLUSIONES. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Transacciones asistencia → Supabase', 'Tabla transacciones_asistencia (sql/), import Excel Sheet1 desde dashboard (Importar asistencia, permiso upload_base). Normaliza Cramer/Cabildo/Migueletes. Docs TRANSACCIONES_ASISTENCIA.md.', 'Feature'],
  ['__HOY__', '__AHORA__', 'Menú Asistencia en dashboard', 'Vista Asistencia: heatmap concurrencia por día y hora (1 h por ingreso), año y mes o todos los meses, franja horaria, filtro multi-sucursal y permisos; clientes en más de una sede; carga paginada; índice (fecha, sucursal); invalidación de caché al importar.', 'Feature'],
  ['__HOY__', '__AHORA__', 'Combo año Asistencia desde datos', 'RPC get_anios_transacciones_asistencia: el select de año solo lista años con registros en transacciones_asistencia; fallback año actual si tabla vacía o RPC no ejecutada.', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'Tabla multi-sede Asistencia', 'Visitas por sede con conteo por cliente; resaltado ámbar la(s) sede(s) con más visitas (empate).', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'Permiso ver_asistencia', 'Menú Asistencia y SELECT transacciones_asistencia condicionados a ver_asistencia; toggles en Seguridad; sql/supabase_asistencia_ver_permiso.sql y DDL transacciones actualizado.', 'Feature'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.19', 'Vista Asistencia: heatmap verde-rojo, franja horaria, filas calendario o Lun–Dom, combo años RPC, carga y mapa por fecha optimizado, multi-sede con visitas por sede y filtro una sucursal; ver_asistencia; mensajes al filtrar. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Asistencia: frecuencia de uso', 'Distribución por rangos: días distintos con visita ÷ semanas (lun–dom) con ≥1 ingreso (no diluye meses sin asistir). Sin tramo «menos de 1 día/sem» (mínimo 1 con semanas activas). Multi-sede: prom. ingr./sem. activas.', 'Feature'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.20', 'Asistencia: frecuencia por semanas activas (lun–dom con ingreso); distribución por rangos desde 1 día/sem.; multi-sede con prom. ingr./sem. activas; textos de ayuda. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Asistencia: permanencia', 'Distribución por meses entre primera y última visita; tramos mensuales 0–12 y cola dinámica hasta 60 meses; promedio global; ayuda (?).', 'Feature'],
  ['__HOY__', '__AHORA__', 'Asistencia: permanencia aclaración', 'Texto y subtítulo: permanencia solo dentro del rango Año/Mes cargado (techo = duración del período); wrap sin max-height para ver tramo 0–1 mes; ayuda (?).', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'Asistencia: filtros y rendimiento', 'Clic sucursales con delegación única y detección de vista activa por menú (no display:none). Doble rAF en carga; mapa primero y métricas en siguiente frame. Rango «Todos los años» (min–max años con datos). Al entrar Asistencia o abrir Importar: mes Todos y año Todos si existe opción; modal dispara carga de años si faltan. invalidateAsistenciaCache limpia asistenciaAniosDisponibles. Tras import, refresco si el menú Asistencia está activo.', 'Corrección'],
  ['__HOY__', '__AHORA__', 'Asistencia: UX carga y SQL índice', 'Bajo filtros: bloque de contenido oculto hasta tener datos; modal con spinner y barra (conteo exact PostgREST + progreso por páginas; indeterminada si falla el count). Fase «Armando mapa» con doble rAF. Aviso si >250k filas. sql/supabase_transacciones_asistencia_index_covering.sql (INCLUDE). Docs TRANSACCIONES.', 'Feature'],
  ['__HOY__', '__AHORA__', 'Nueva versión Everfit (como Pandi)', 'everfit-release.json en raíz + modal al detectar despliegue (fetch no-store); reglas bitacora-tareas y reglas-everfit; docs GIT_Y_VERCEL; estructura-proyecto. Criterio lines comerciales solo lo visible.', 'Feature'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.21', 'Asistencia: carga con modal de progreso, bloque bajo filtros en blanco hasta tener datos, conteo y paginación; modal «Nueva versión» con everfit-release.json; script índice covering opcional; reglas y docs. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Asistencia: detalle permanencia por cliente', 'Tabla detalle con acción (ojo): modal con meses de carrera, días distintos, ingresos, tiempo estimado en club (1 h por ingreso); segundo ojito muestra u oculta asistencias ordenadas por fecha y hora.', 'Feature'],
  ['__HOY__', '__AHORA__', 'Asistencia: permanencia ojo por rango', 'Ojo en cada fila de la tabla de rangos (columna Acción a la derecha del %): modal con clientes solo de ese bucket; ojo por cliente con «Volver al listado del rango»; delegación document para clics dentro del modal. Eliminada la tabla global «Detalle por cliente». Ayuda (?), card Permanencia y help-asistencia.', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.22', 'Permanencia por rango en Asistencia, everfit-release.json y sidebar v1.22. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.23', 'Se incorpora el apellido y nombre del cliente en el detalle de permanencia por cliente. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Asistencia: huella RPC y cache', 'RPC get_asistencia_dataset_version(desde,hasta) + comparación antes de re-paginar; invalidación al importar. sql/supabase_asistencia_dataset_version.sql y docs TRANSACCIONES.', 'Feature'],
  ['__HOY__', '__AHORA__', 'Asistencia: refresh barra sin invalidar cache', 'refreshPermisosYVista ya no llama invalidateAsistenciaCache; tras cargarDatos repinta Asistencia si está activa para respetar huella y evitar re-descarga completa.', 'Corrección'],
  ['__HOY__', '__AHORA__', 'Asistencia: nombre en modal por rango', 'asistenciaPersonaHtmlLabelPerm muestra ID — Apellido, Nombre cuando hay empleado_id y datos de nombre (tabla Clientes del modal por bucket).', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'Asistencia: sub-rango en memoria', 'Si el combo Año/Mes pide un rango contenido en el ya descargado (p. ej. 2026 dentro de «todos los años»), no se re-pagina Supabase; filtro por fecha en getAsistenciaRowsFiltered. Huella RPC solo si UI = rango del cache.', 'Feature'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.24', 'Asistencia: huella RPC, cache/refresh, sub-rango en memoria, modal permanencia por rango (layout + nombres). sql supabase_asistencia_dataset_version.sql y docs. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Asistencia: gráfico activos + paginación 5000', 'Card «Clientes activos por mes» (Chart.js líneas): mismos filtros que el mapa; activos = personas únicas con ingreso por mes calendario; MA3; Total+suavizado; varias sedes = línea por sede + tendencia total deduplicada; una sede = serie+suavizado. SUPABASE_PAGE_SIZE 5000 (alinear con Max rows en Supabase API).', 'Feature'],
  ['__HOY__', '__AHORA__', 'Paginación PostgREST: lotes reales + gráfico asistencia', 'Asistencia: avanzar offset por filas devueltas y terminar con count exacto (evita cortar si Max rows < pageSz; contador del modal = lotes reales). base_everfit y tipos de cambio: misma lógica hasta lote vacío. SUPABASE_PAGE_SIZE junto a createClient. Gráfico activos: resize doble rAF, min-height contenedor, iterar meses con guarda NaN.', 'Corrección'],
  ['__HOY__', '__AHORA__', 'SUPABASE_PAGE_SIZE 15000', 'Constante en dashboard.html alineada con Max rows 15000 (Supabase Data API) para menos requests en base_everfit, tipos de cambio y transacciones_asistencia.', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'Gráfico activos: hasta último mes cerrado', 'Serie mensual cortada al último mes calendario completo en Argentina (excluye mes en curso); textos card y ayuda (?).', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.25', 'Asistencia: gráfico clientes activos/mes, paginación por lote real y SUPABASE_PAGE_SIZE 15000, eje hasta último mes cerrado AR; everfit-release.json y sidebar v1.25. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Gráfico activos: líneas multi-sede desde primer mes', 'Con varias sucursales, cada serie usa null antes del primer mes con ≥1 activo en esa sede (evita tramo en cero antes de apertura). Textos card y ayuda (?).', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.26', 'everfit-release.json: mensaje de nueva versión genérico (mejora tiempos de respuesta del servidor). Sidebar v1.26. Gráfico activos multi-sede desde primer mes con datos. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Gráfico activos: inicio por fecha mínima', 'Null antes del primer mes con datos en total, una sede y cada línea multi-sede; MA3 sin tratar null como 0; tendencia total multi-sede recortada igual. Textos card y (?).', 'Corrección'],
  ['__HOY__', '__AHORA__', 'Asistencia: fila Promedio total en heatmap', 'Última fila del mapa de concurrencia = promedio aritmético por columna (hora) de las filas anteriores; maxVal incluye esa fila para misma escala de color; borde superior; leyenda.', 'Feature'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.27', 'everfit-release.json: mensaje genérico (tiempos de respuesta del servidor). Sidebar v1.27. Gráfico activos: inicio por fecha mínima por sucursal/total y fix MA3 con null. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.28', 'Asistencia heatmap: fila «Promedio total» por hora (misma escala de color). everfit-release.json genérico. Sidebar v1.28. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Flujo/GP: filtro por concepto', 'Tabla Flujo y gráfico G/P excluyen filas con concepto Inversiones o Saldo Inicial (ya no por beneficiario Dividendos). Tarjetas y modal Detalle sin ese filtro por concepto. Ayudas (?) y docs/EXCLUSIONES_DASHBOARD.md actualizados.', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'Proyección: ventana calendario', 'Base = N meses calendario anteriores al mes en curso (no últimos N con datos); relleno 0; ventana móvil Proy. 2+ con proyecciones previas. Modal y pie de tabla aclarados.', 'Corrección'],
  ['__HOY__', '__AHORA__', 'Proyección: documentación y blindaje', 'docs/PROYECCION_FLUJO.md; EXCLUSIONES y DASHBOARD actualizados. Código: filtro y lectura de montos solo para claves estrictamente anteriores al mes en curso (nunca mezclar mes en curso o futuros en la base).', 'Documentación'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.29', 'Flujo/G-P: exclusión por concepto Inversiones y Saldo Inicial; proyección con meses calendario previos al mes en curso y sin mes en curso/futuros en la base; docs PROYECCION_FLUJO, EXCLUSIONES, DASHBOARD; everfit-release.json v1.29. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'To-Do: módulo bandeja y roles', 'Roles Recepcionista y Profesor; permisos ver_todo/crear_todo/completar_todo (alta por defecto Admin+Encargado); tablas todo_tarea/todo_instancia, RLS y RPCs; bandeja responsiva con filtros, estados, responsable obligatorio (usuario o perfil), recurrencias y export Excel. SQL helpers_fecha_argentina + supabase_todo; docs TODO/SEGURIDAD/DASHBOARD. Migración aplicada en Supabase Everfit.', 'Feature'],
  ['__HOY__', '__AHORA__', 'Sedes ABM + To-Do sede/fecha fin', 'Menú Sedes (catálogo ABM) alimenta permisos por usuario y To-Do. Tareas: una sede o todas (réplica). Recurrentes exigen «hasta qué fecha» (máx. 366 días); se elimina la ventana fija de ~45 días. SQL supabase_sedes + supabase_todo_sede_y_fecha_fin; docs SEDES/TODO.', 'Feature'],
  ['__HOY__', '__AHORA__', 'To-Do: fix read-only INSERT', 'todo_list_inbox ya no materializa instancias (STABLE/read-only en PostgREST). La generación va por todo_generar_instancias_todas antes del listado en el dashboard.', 'Corrección'],
  ['__HOY__', '__AHORA__', 'To-Do: bandeja no bloquea en generar', 'cargarTodoBandeja lista de inmediato; todo_generar_instancias_todas corre en background y refresca solo si creó instancias (evita quedar en «Cargando bandeja…»).', 'Corrección'],
  ['__HOY__', '__AHORA__', 'To-Do: editar/eliminar + vaciar prueba', 'Permisos editar_todo y eliminar_todo (default Admin/Encargado, toggles en Seguridad). Modal editar y botón eliminar en bandeja. Tablas todo_tarea/todo_instancia vaciadas para prueba. SQL supabase_todo_editar_eliminar.sql.', 'Feature'],
  ['__HOY__', '__AHORA__', 'To-Do: recurrencias bimestral/trimestral', 'Se elimina hora_fija (igual que diaria con hora). Se agregan bimestral y trimestral. SQL constraints + todo_next_dates + UI.', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'To-Do: cards según filtros + Hoy default', 'Las cards de resumen se calculan sobre el listado filtrado (estado/prioridad/vencimiento/sede/búsqueda). Filtro de vencimiento por defecto: Hoy.', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'To-Do: celdas centradas verticalmente', 'Tabla de bandeja: vertical-align middle en td para alinear texto/badges con la fila de acciones (select + editar/eliminar).', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'To-Do: solapas Tareas + Por responsable', 'Bandeja en solapa Tareas. Nueva solapa Por responsable (solo Admin/Encargado): matriz responsable×estado con los mismos filtros; clic en cantidad abre modal con el detalle de tareas.', 'Feature'],
  ['__HOY__', '__AHORA__', 'To-Do: fix eliminar + mensajes + Empresa', 'Eliminar ya no regenera la instancia (cancelada / desactiva plantilla). Mensajería estilo Pandi (toast + confirm). Alta con opción Empresa (una sola tarea sin sede). SQL supabase_todo_empresa_y_eliminar.sql.', 'Corrección'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.30', 'To-Do: bandeja, solapas Tareas/Por responsable, sede Empresa, eliminar sin regenerar, mensajería interna, alineación Tarea/Sede/Responsable. Menú Sedes. everfit-release.json v1.30. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'Configuración: reasignar To-Do', 'Menú Configuración (permiso ver_configuracion, Admin/Encargado). Reasignar una, varias o todas las tareas abiertas de un usuario a otro o de un perfil a otro. SQL supabase_todo_reasignar.sql; docs CONFIGURACION.', 'Feature'],
  ['__HOY__', '__AHORA__', 'To-Do: filtro estado Abiertas por defecto', 'El filtro de estado inicia en Abiertas (pendiente, en curso y vencida). Hechas y canceladas no se listan hasta que se elijan. Al filtrar Hecha/Cancelada con vencimiento Hoy, el vencimiento pasa a Todas para poder reabrir. SQL supabase_todo_inbox_estado_abiertas.sql.', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'To-Do: resaltar filtros activos', 'Los filtros que recortan la bandeja (estado distinto de Todos, vencimiento distinto de Todas, prioridad, sede o búsqueda) se marcan con estilo activo y leyenda «activo».', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.31', 'Menú Configuración (reasignar To-Do por usuario o perfil). To-Do: estado Abiertas por defecto y resalte de filtros activos. everfit-release.json v1.31. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'To-Do: primer vencimiento de la serie', 'En recurrentes se elige el primer due date (p. ej. el lunes próximo) y desde ahí se replica: diario +1, semanal +7, trimestral +3 meses, etc. Se ocultan día de semana / día del mes. SQL supabase_todo_primer_vencimiento.sql.', 'Ajuste'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.32', 'To-Do recurrente: primer vencimiento a elección y réplica de la serie desde esa fecha. everfit-release.json v1.32. Push a main y vercel --prod.', 'Despliegue'],
  ['__HOY__', '__AHORA__', 'To-Do: en curso + sin domingo', 'En curso se cuenta en cards y Por responsable aunque esté vencida la fecha. No se registran tareas en domingo (AR): diaria omite el día; mensual/trimestral pasa al lunes. SQL supabase_todo_en_curso_sin_domingo.sql.', 'Corrección'],
  ['__HOY__', '__AHORA__', 'Despliegue v1.33', 'To-Do: en curso se cuenta aunque esté vencida la fecha; sin vencimientos en domingo. everfit-release.json v1.33. Push a main y vercel --prod.', 'Despliegue'],
];

const datosLogParaExcel = preservarFechasHistoricasLog(projectRoot, outPath, datosLog);
const wsLog = XLSX.utils.aoa_to_sheet(datosLogParaExcel);
wsLog['!cols'] = [{ wch: 12 }, { wch: 6 }, { wch: 45 }, { wch: 95 }, { wch: 14 }];

// --- Hoja Resumen
const funcionalidades = [
  ['Funcionalidad', 'Descripción'],
  ['Base de datos Everfit', 'Tabla base_everfit en Supabase con datos migrados desde Base/Base_Everfit.xlsx (hoja Base).'],
  ['Volcado Excel → Supabase', 'Script scripts/volcar_excel_a_supabase.py lee el Excel e inserta en base_everfit. Requiere .env con SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY.'],
  ['Tipos de cambio (ARS/USD)', 'Consumo por API desde proyecto Sistema-Contable-Nuevo (tabla tipos_cambio_global). Opcional: sync local con scripts/sync_tipo_de_cambio_desde_origen.py.'],
  ['Estructura del repo', 'Carpetas sql/, scripts/, docs/, Base/. Reglas en .cursor/rules (estructura-proyecto, reglas-everfit, bitácora, preguntas-solo-respuesta).'],
  ['Dashboard Everfit', 'Una página (dashboard.html): flujo por mes y gráfico G/P excluyen además concepto Inversiones y Saldo Inicial (porMesFlujo; no aplica a tarjetas ni Detalle); tarjetas totales incluyen todo salvo centro Saldo Inicial (porMes). Importar asistencia (Excel → transacciones_asistencia, upload_base). Menú Asistencia (permiso ver_asistencia): heatmap por concurrencia (colores, franja horaria), filas calendario o Lun–Dom, **fila final «Promedio total»** por hora (promedio de las filas superiores, misma escala de color), años con datos (RPC) y opción «Todos los años», mes «Todos los meses» por defecto al entrar o al abrir importar; filtro sucursal con delegación de clic; vista activa por ítem de menú; mapa y métricas escalonados (rAF). **Gráfico clientes activos por mes** (personas únicas con ingreso por mes calendario, eje hasta último mes cerrado AR, MA3; cada serie desde el primer mes con datos de su contexto—total, una sede o cada sede—sin ceros previos; total / varias sedes / una sede según filtro). Carga de transacciones: área bajo filtros en blanco, modal con spinner y barra de progreso (count + páginas), fase de armado del mapa; **RPC opcional get_asistencia_dataset_version**; **sub-rango del combo filtrado en memoria** si el rectángulo ya está descargado; **Actualizar permisos (barra) no invalida** el cache de asistencia; índice covering opcional en sql/. Paginación PostgREST **SUPABASE_PAGE_SIZE 15000** (coherente con Max rows del proyecto en Supabase Data API). Frecuencia (días distintos ÷ semanas activas), **permanencia**: ojo por rango, **modal listado clientes** ancho según contenido e **ID — apellido y nombre** en tabla; modal detalle con título apellido/nombre; multi-sede. Tras un despliegue: modal «Nueva versión» (**everfit-release.json**). Fechas America/Argentina/Buenos_Aires. Login; Seguridad; actualizar base; carga paginada base_everfit, tipos de cambio y asistencia por rango.'],
  ['Proyección Flujo por mes', 'Meses proyectados en tabla (permiso ver_proyeccion). Config: método (promedio/mediana/promedio recortado), meses de historia (N meses calendario estrictamente anteriores al mes en curso; nunca usa mes en curso ni futuros como base, aunque tengan datos), meses a proyectar, recorte %. Cada Proy. k usa los últimos (N−k) valores de esa ventana inicial más las k−1 proyecciones ya calculadas. Doc: docs/PROYECCION_FLUJO.md. Total columna incluye proyectados; tarjetas siempre reales. Encabezado y celdas proyectadas con fondo distintivo.'],
  ['Seguridad – Permisos por rol', 'En Seguridad (Admin): cada rol (Admin, Encargado, Recepcionista, Profesor, Visor) con icono y lista de permisos con toggle on/off editable (incluye ver_asistencia y permisos To-Do). RPC get_roles_permissions_for_admin y set_role_permission. Ejecutar sql/supabase_seguridad_permisos_editable.sql, sql/supabase_asistencia_ver_permiso.sql y sql/supabase_todo.sql si aplica.'],
  ['Transacciones de asistencia', 'Excel export Transacciones por sucursal (docs de referencia). Tabla transacciones_asistencia; botón Importar asistencia en dashboard (reemplazo por sucursal). Ver docs/TRANSACCIONES_ASISTENCIA.md y sql/supabase_transacciones_asistencia.sql.'],
  ['To-Do – bandeja de tareas', 'Menú To-Do: solapas Tareas y Por responsable (Admin/Encargado: matriz perfil/usuario × estado con clic a modal de detalle). Resumen (cards según filtros; estado por defecto Abiertas = pendiente/en curso/vencida; vencimiento por defecto Hoy), filtros resaltados cuando recortan el listado, badges, cambio de estado, alta con responsable obligatorio (usuario o perfil), sede (una / todas / Empresa), recurrencia con primer vencimiento + «hasta» (máx. 366 días; la serie se replica desde ese due date), editar/eliminar (sin regenerar), mensajería interna toast/confirm, export Excel. Permisos ver_todo/crear_todo/completar_todo/editar_todo/eliminar_todo. Roles Recepcionista y Profesor. Docs: docs/TODO.md; SQL: sql/supabase_todo.sql + supabase_todo_sede_y_fecha_fin.sql + supabase_todo_editar_eliminar.sql + supabase_todo_empresa_y_eliminar.sql + supabase_todo_inbox_estado_abiertas.sql + supabase_todo_primer_vencimiento.sql.'],
  ['Sedes – catálogo ABM', 'Menú Sedes (Admin): alta/edición/activar-desactivar. Alimenta asignación de sedes en Seguridad y opciones de sede del To-Do. SQL: sql/supabase_sedes.sql. Docs: docs/SEDES.md.'],
  ['Configuración – reasignar To-Do', 'Menú Configuración (permiso ver_configuracion, default Admin/Encargado). Reasignar una, varias o todas las tareas abiertas de un usuario a otro, o de un perfil a otro (p. ej. Recepcionista → Profesor). SQL: sql/supabase_todo_reasignar.sql. Docs: docs/CONFIGURACION.md.'],
];

const wsResumen = XLSX.utils.aoa_to_sheet(funcionalidades);
wsResumen['!cols'] = [{ wch: 32 }, { wch: 85 }];

// --- Hoja Ref Git y Vercel (actualizar cuando tengas repo y Vercel)
const refGitVercel = [
  ['Concepto', 'Valor'],
  ['Repositorio GitHub', 'https://github.com/TU_USUARIO/everfit'],
  ['URL app en vivo (Vercel)', 'https://everfit.vercel.app/'],
  ['Rama principal', 'main'],
  ['Actualizar y subir cambios', 'git add .  →  git commit -m "descripción"  →  git push origin main'],
  ['Vercel redeploy', 'Automático al hacer push a main (cuando esté conectado)'],
];

const wsRef = XLSX.utils.aoa_to_sheet(refGitVercel);
wsRef['!cols'] = [{ wch: 28 }, { wch: 70 }];

// --- Hoja Versiones
const versiones = [
  ['Versión', 'Fecha', 'Descripción'],
  ['1.0', '06/03/2026', 'Setup: estructura repo, reglas, script bitácora, volcado Excel a Supabase, tipos de cambio por API.'],
  ['1.1', '06/03/2026', 'Dashboard completo: login por email, módulo Seguridad (roles Admin/Encargado/Visor), Actualizar base (upload Excel), flujo por mes, gráfico G/P, filtros. Despliegue Vercel.'],
  ['1.2', '06/03/2026', 'Config build para Vercel (config.js desde env), outputDirectory, favicon EF (logo reducido), script vercel-setup-env, docs URL y dominio.'],
  ['1.3', '06/03/2026', 'Proyección en Flujo por mes: config (método, meses historia, meses a proyectar, recorte %), ventana móvil. Total tabla con proyectados; tarjetas solo reales. Fondo distintivo en encabezado y celdas proyectadas.'],
  ['1.4', '06/03/2026', 'Seguridad: permisos por rol editables (iconos y toggles on/off para Admin, Encargado, Visor). SQL supabase_seguridad_permisos_editable.sql.'],
  ['1.5', '06/03/2026', 'Botón refresh en barra (actualizar permisos y vista sin cerrar sesión). Auto-refresh al cambiar permisos en Seguridad.'],
  ['1.6', '06/03/2026', 'Incluir real_pendiente=proyectado en todo. Help (?) con reglas de exclusión en tarjetas, gráfico y flujo. Tarjetas en una card con help dentro. Config proyección por usuario (config_dashboard). Dividendos solo excluido en tabla.'],
  ['1.7', '06/03/2026', 'Gráfico G/P Mensual: leyenda oculta (barras verdes/rojas sin leyenda).'],
  ['1.8', '06/03/2026', 'Gráfico G/P: barras con G/P=0 visibles (minBarLength, color gris, tooltip ingresos=egresos).'],
  ['1.9', '06/03/2026', 'Tipos de cambio por API desde Sistema-Contable-Nuevo (Opción 2). Fix upload Excel fechas→ISO. ORIGEN_TC_* en config y build.'],
  ['1.10', '07/03/2026', 'Modal gráfico por ítem en detalle (concepto/beneficiario) e icono en totales. Icono sin contorno. Botones sucursal seleccionado en turquesa.'],
  ['1.11', '07/03/2026', 'Log actualización base y leyenda Última actualización. Progreso eliminación en upload. Fix RPC log.'],
  ['1.12', '07/03/2026', 'Dashboard responsive móviles. Regla: tener en cuenta responsive a partir de ahora.'],
  ['1.13', '__HOY__', 'Filtro multi-sucursal. Sucursales permitidas por usuario en Seguridad. Total respeta asignación. SQL supabase_sucursales_por_usuario.sql.'],
  ['1.14', '__HOY__', 'Modales: no cerrar al elegir opción de select (mousedown+click en backdrop). Helper setupBackdropCloseOnlyOnRealClick en todos los modales.'],
  ['1.15', '__HOY__', 'Tipos de cambio con paginación al cargar (tipos_cambio_global / tipo_de_cambio). Regla proyecto: documentar límite PostgREST y paginación en reglas-everfit.'],
  ['1.16', '__HOY__', 'Fechas America/Argentina/Buenos_Aires: gráfico G/P y clave mes en curso; fecha_pago ISO/timestamptz agrupada por día local (no slice UTC).'],
  ['1.17', '__HOY__', 'Gráfico G/P Mensual alineado con tabla Flujo por mes (porMesFlujo; excluye Dividendos). Documentación EXCLUSIONES_DASHBOARD.md actualizada.'],
  ['1.18', '__HOY__', 'Consolidado: fechas AR en agrupación y mes actual; gráfico=tabla Flujo; tarjetas con Dividendos; UX local sin anon key y errores sesión/RPC visibles. EXCLUSIONES_DASHBOARD.md.'],
  ['1.19', '__HOY__', 'Asistencia: menú y permiso ver_asistencia (RLS, sql migración); heatmap por franja horaria, modo filas calendario o Lun–Dom, años vía RPC, optimización índice por fecha y caché; multi-sede con conteos por sede y lógica filtro una sede; UX carga filtros; índice (fecha,sucursal) en DDL.'],
  ['1.20', '__HOY__', 'Asistencia frecuencia: distribución por rangos con días distintos ÷ semanas activas (lun–dom con ingreso); sin tramo <1 día/sem.; prom. ingr./sem. activas en multi-sede; textos de ayuda.'],
  ['1.21', '__HOY__', 'Asistencia: UX de carga (modal spinner y barra, área bajo filtros oculta hasta listo, progreso por descarga); aviso de muchos registros; modal «Nueva versión» con everfit-release.json (criterio Pandi); sql índice covering opcional; reglas bitácora y GIT_Y_VERCEL.'],
  ['1.22', '__HOY__', 'Asistencia permanencia: columna Acción (ojo) por fila de rango abre modal con clientes de ese bucket; volver al rango desde el detalle; delegación de clics en document; sin tabla global detalle. everfit-release.json v1.22.'],
  ['1.23', '__HOY__', 'Se incorpora el apellido y nombre del cliente en el detalle de permanencia por cliente.'],
  ['1.24', '__HOY__', 'Asistencia: RPC huella opcional (sql), cache sin re-fetch en sub-rango ni en refresh barra; modal rango ancho fit-content; ID+nombre en tabla clientes por bucket. everfit-release.json v1.24.'],
  ['1.25', '__HOY__', 'Asistencia: gráfico clientes activos por mes (MA3, filtros); paginación PostgREST por filas devueltas en base_everfit, tipos de cambio y asistencia; SUPABASE_PAGE_SIZE 15000; eje gráfico hasta último mes cerrado Argentina; everfit-release.json v1.25.'],
  ['1.26', '__HOY__', 'Modal nueva versión: texto genérico orientado a tiempos de respuesta del servidor. Asistencia: líneas por sede en gráfico activos desde el primer mes con datos (sin ceros previos a la apertura). everfit-release.json v1.26.'],
  ['1.27', '__HOY__', 'everfit-release.json: aviso genérico de tiempos de respuesta. Gráfico activos: serie desde primer mes con datos (total, una o varias sedes); media móvil sin tratar null como cero.'],
  ['1.28', '__HOY__', 'Asistencia: fila final «Promedio total» en mapa de concurrencia (promedio por columna, misma escala de color). everfit-release.json v1.28 (mensaje genérico rendimiento).'],
  ['1.29', '__HOY__', 'Flujo/G-P exclusión concepto Inversiones y Saldo Inicial; proyección N meses calendario anteriores al mes en curso, blindaje mes en curso/futuros; docs PROYECCION_FLUJO.md y actualización EXCLUSIONES/DASHBOARD; everfit-release.json v1.29.'],
  ['1.30', '__HOY__', 'To-Do (bandeja, filtros Hoy, solapas Tareas y Por responsable, alta Empresa/sede, eliminar sin regenerar, toast/confirm). Catálogo Sedes. Roles Recepcionista/Profesor. everfit-release.json v1.30.'],
  ['1.31', '__HOY__', 'Menú Configuración: reasignar tareas To-Do de un usuario a otro o de un perfil a otro. To-Do: filtro estado Abiertas por defecto y resalte de filtros activos. everfit-release.json v1.31.'],
  ['1.32', '__HOY__', 'To-Do recurrente: se indica el primer vencimiento y desde ahí se replica la serie (diario, semanal, trimestral, etc.). everfit-release.json v1.32.'],
  ['1.33', '__HOY__', 'To-Do: en curso se cuenta en cards y Por responsable aunque esté vencida la fecha; no se registran vencimientos en domingo. everfit-release.json v1.33.'],
];
const versionesParaExcel = preservarFechasHistoricasVersiones(projectRoot, outPath, versiones);
const wsVersiones = XLSX.utils.aoa_to_sheet(versionesParaExcel);
wsVersiones['!cols'] = [{ wch: 8 }, { wch: 12 }, { wch: 75 }];

// --- Hoja Tecnología
const tecnologia = [
  ['Componente', 'Detalle'],
  ['Datos', 'Supabase (PostgreSQL). Tablas: base_everfit, tipo_de_cambio (opcional local). Scripts SQL en sql/.'],
  ['Tipos de cambio', 'Consumo por API desde Sistema-Contable-Nuevo (tipos_cambio_global). Ver docs/TIPO_DE_CAMBIO_DESDE_OTRO_PROYECTO.md.'],
  ['Hosting', 'Vercel. Despliegue con vercel --prod tras push a main.'],
  ['Repositorio', 'Git/GitHub, rama main.'],
  ['Bitácora', 'Node.js + SheetJS (xlsx). Script scripts/crear-bitacora-excel.js genera Bitacora_tareas.xlsx con Log, Resumen, Ref Git y Vercel, Versiones, Tecnología.'],
];
const wsTecnologia = XLSX.utils.aoa_to_sheet(tecnologia);
wsTecnologia['!cols'] = [{ wch: 18 }, { wch: 95 }];

const wb = XLSX.utils.book_new();
XLSX.utils.book_append_sheet(wb, wsLog, 'Log');
XLSX.utils.book_append_sheet(wb, wsResumen, 'Resumen');
XLSX.utils.book_append_sheet(wb, wsRef, 'Ref Git y Vercel');
XLSX.utils.book_append_sheet(wb, wsVersiones, 'Versiones');
XLSX.utils.book_append_sheet(wb, wsTecnologia, 'Tecnología');

XLSX.writeFile(wb, outPath);
console.log('Creado:', outPath);
