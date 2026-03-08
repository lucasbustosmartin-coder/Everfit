const XLSX = require('xlsx');
const path = require('path');

const ZONA_ARGENTINA = 'America/Argentina/Buenos_Aires';
function ahoraFecha() {
  return new Date().toLocaleDateString('es-AR', { timeZone: ZONA_ARGENTINA, day: '2-digit', month: '2-digit', year: 'numeric' });
}
function ahoraHora() {
  return new Date().toLocaleTimeString('es-AR', { timeZone: ZONA_ARGENTINA, hour: '2-digit', minute: '2-digit', hour12: false });
}
function aplicarHoyAhora(rows) {
  return rows.map(row => Array.isArray(row)
    ? row.map(cell => {
        if (cell === '__HOY__') return ahoraFecha();
        if (cell === '__AHORA__') return ahoraHora();
        return cell;
      })
    : row);
}

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
];

const datosLogParaExcel = aplicarHoyAhora(datosLog);
const wsLog = XLSX.utils.aoa_to_sheet(datosLogParaExcel);
wsLog['!cols'] = [{ wch: 12 }, { wch: 6 }, { wch: 45 }, { wch: 95 }, { wch: 14 }];

// --- Hoja Resumen
const funcionalidades = [
  ['Funcionalidad', 'Descripción'],
  ['Base de datos Everfit', 'Tabla base_everfit en Supabase con datos migrados desde Base/Base_Everfit.xlsx (hoja Base).'],
  ['Volcado Excel → Supabase', 'Script scripts/volcar_excel_a_supabase.py lee el Excel e inserta en base_everfit. Requiere .env con SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY.'],
  ['Tipos de cambio (ARS/USD)', 'Consumo por API desde proyecto Sistema-Contable-Nuevo (tabla tipos_cambio_global). Opcional: sync local con scripts/sync_tipo_de_cambio_desde_origen.py.'],
  ['Estructura del repo', 'Carpetas sql/, scripts/, docs/, Base/. Reglas en .cursor/rules (estructura-proyecto, reglas-everfit, bitácora, preguntas-solo-respuesta).'],
  ['Dashboard Everfit', 'Una página (dashboard.html): flujo por mes, resumen, gráfico G/P, filtros moneda/sucursal. Login por email; módulo Seguridad (Admin asigna roles). Actualizar base: truncar y cargar Excel desde el navegador.'],
  ['Proyección Flujo por mes', 'Meses proyectados en tabla (permiso ver_proyeccion). Config: método (promedio/mediana/promedio recortado), meses de historia, meses a proyectar, recorte %. Ventana móvil. Total columna incluye proyectados; tarjetas siempre reales. Encabezado y celdas proyectadas con fondo distintivo.'],
  ['Seguridad – Permisos por rol', 'En Seguridad (Admin): cada rol (Admin, Encargado, Visor) con icono y lista de permisos con toggle on/off editable. RPC get_roles_permissions_for_admin y set_role_permission. Ejecutar sql/supabase_seguridad_permisos_editable.sql.'],
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
];
const versionesParaExcel = aplicarHoyAhora(versiones);
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

const outPath = path.join(__dirname, '..', 'Bitacora_tareas.xlsx');
const wb = XLSX.utils.book_new();
XLSX.utils.book_append_sheet(wb, wsLog, 'Log');
XLSX.utils.book_append_sheet(wb, wsResumen, 'Resumen');
XLSX.utils.book_append_sheet(wb, wsRef, 'Ref Git y Vercel');
XLSX.utils.book_append_sheet(wb, wsVersiones, 'Versiones');
XLSX.utils.book_append_sheet(wb, wsTecnologia, 'Tecnología');

XLSX.writeFile(wb, outPath);
console.log('Creado:', outPath);
