# To-Do – bandeja de tareas (Everfit)

Menú **To-Do** en el dashboard: alta de tareas, bandeja con estados, filtros, exportación Excel y perfiles **Recepcionista** / **Profesor**.

## Activación (Supabase)

Ejecutar en este orden (si el proyecto ya tenía seguridad):

1. `sql/helpers_fecha_argentina.sql` — `fecha_hoy_argentina()`
2. `sql/supabase_todo.sql` — roles, permisos, tablas, RLS y RPCs

En entornos ya migrados vía MCP/agente, estos scripts reflejan el estado aplicado. Incremental: `sql/supabase_todo_inbox_estado_abiertas.sql` (`p_estado = 'abiertas'`), `sql/supabase_todo_primer_vencimiento.sql` (primer due date de la serie), `sql/supabase_todo_en_curso_sin_domingo.sql` (en curso vs vencida; sin domingos), `sql/supabase_todo_diaria_hecha_mismo_dia.sql` (diaria: Hecha el mismo día de vencimiento, sin exigir la hora; el anterior `supabase_todo_diaria_hecha_al_vencer.sql` queda histórico), `sql/supabase_todo_hechas_hoy.sql` (card Hechas hoy por día calendario AR, independiente del filtro Abiertas), `sql/supabase_todo_estado_modificado_por.sql` (columna **Estado por** en bandeja y Excel), `sql/supabase_user_profiles_nombre_usuario.sql` (**nombre para mostrar** en Responsable/Usuario en bandeja; modal **Mi perfil**), `sql/supabase_set_user_nombre_usuario_admin.sql` (Admin edita nombre en Seguridad → Usuarios).

## Roles nuevos

| Rol | Label |
|-----|--------|
| `recepcionista` | Recepcionista |
| `profesor` | Profesor |

Se asignan desde **Seguridad** (Admin), igual que Admin / Encargado / Visor.

## Permisos

| Permiso | Default | Efecto |
|---------|---------|--------|
| `ver_todo` | Todos los roles | Ver menú To-Do y bandeja (solo lo atribuible; quien tiene `crear_todo` ve todo) |
| `crear_todo` | **Admin y Encargado** | Alta de tareas / plantillas recurrentes |
| `editar_todo` | **Admin y Encargado** (configurable por rol) | Editar ocurrencia (título, descripción, prioridad, vencimiento, sede) |
| `eliminar_todo` | **Admin y Encargado** (configurable por rol) | Eliminar ocurrencia; opcional cortar serie recurrente |
| `completar_todo` | Todos con bandeja | Cambiar estado (pendiente, en curso, hecha, cancelada) |

Configurable en Seguridad (toggles por rol).

Defaults adicionales: Recepcionista y Profesor también reciben `ver_asistencia` (ajustable).

## Modelo

- **`todo_tarea`**: plantilla (título, prioridad, responsable obligatorio usuario **o** perfil, recurrencia, hora, días, vigencia, **sede**).
- **`todo_instancia`**: ocurrencias en la bandeja (`pendiente` \| `en_curso` \| `hecha` \| `cancelada`). “Vencida” es estado efectivo si está abierta y `vencimiento_at` &lt; ahora. Cada instancia lleva **`sede`**.

### Sede

- **Todas las sedes:** al crear se replica 1 instancia por cada sede activa del catálogo (`sedes`).
- **Una sede:** una sola línea de réplica para esa sede.
- **Empresa:** una sola tarea a nivel empresa (`sede` NULL, sin réplica por sucursal). En la bandeja se muestra como «Empresa».
- La bandeja respeta `sucursales_permitidas` del usuario (si tiene restricción, ve instancias de esas sedes y también las de nivel Empresa).

### Recurrencia y “N” registros

Antes, sin fecha fin, el sistema materializaba una ventana fija de **~45 días** (por eso una diaria generaba muchas filas).  
Ahora:

- En recurrentes es **obligatorio** indicar **Replicar hasta** (`fecha_fin`).
- Tope de seguridad: **366 días** desde el inicio.
- Fórmula aproximada: `N ≈ días_en_rango × cantidad_de_sedes` (si elegís “Todas”).
- Ejemplo: diaria, 14 días, 3 sedes → hasta **42** instancias.
- **Domingo (Argentina):** no se registran vencimientos; en diarias se omite el domingo; si una mensual/trimestral cae domingo, pasa al lunes.

Recurrencias: `ninguna`, `diaria` (con hora), `semanal`, `mensual`, `bimestral`, `trimestral`, `anual`. En recurrentes se indica el **primer vencimiento** (due date inicial) y **Replicar hasta**; el resto de la serie se calcula desde esa fecha (diario +1 día lun–sáb, semanal +7, trimestral +3 meses, etc.). Fechas/horas en **America/Argentina/Buenos_Aires**. Incremental: `sql/supabase_todo_primer_vencimiento.sql`, `sql/supabase_todo_en_curso_sin_domingo.sql`.

“Vencida” (estado efectivo) aplica solo a **pendiente** con fecha pasada. **En curso** se cuenta y se muestra como en curso aunque el vencimiento ya haya pasado.

## RPCs principales

| RPC | Uso |
|-----|-----|
| `todo_crear_tarea(...)` | Alta (requiere `crear_todo`) |
| `todo_list_hechas_hoy(prioridad, sede)` | Filas hechas con `completada_at` en el día calendario Argentina (card Hechas hoy) |
| `todo_resumen_bandeja()` | Contadores globales (legado; la UI calcula cards sobre el listado filtrado) |
| `todo_cambiar_estado(id, estado)` | Cambio de estado. Una **diaria** no se puede marcar Hecha si el **día** de vencimiento (Argentina) es posterior a hoy; el mismo día se puede a cualquier hora |
| `todo_editar_instancia(...)` | Editar ocurrencia (`editar_todo`) |
| `todo_eliminar_instancia(...)` | Eliminar ocurrencia / cortar serie (`eliminar_todo`) |
| `todo_list_usuarios()` / `todo_list_roles()` | Combos del formulario de alta y de Configuración |
| `todo_list_para_reasignar(...)` / `todo_reasignar(...)` | Configuración: listar y mover tareas de un usuario o perfil a otro (`ver_configuracion`) |

## UI

- Solapas: **Tareas** (bandeja) y **Por responsable** (solo Admin / Encargado).
- Cards resumen: Pendientes / En curso / Vencidas según el listado filtrado; **Hechas hoy** cuenta completadas en el **día calendario Argentina** (cualquier hora), con los mismos filtros de sede/prioridad/búsqueda, **sin** exigir Estado=Hecha ni ventana de vencimiento (con Abiertas la card igual sube al marcar Hecha). Filtros compartidos (estado por defecto **Abiertas**; vencimiento por defecto **Hoy**; prioridad, sede, búsqueda). Los filtros que recortan el listado se resaltan. Para reabrir una tarea cerrada, filtrar **Hecha** (si el vencimiento estaba en Hoy, pasa a Todas).
- Tabla sticky, badges, columnas **Responsable** y **Usuario** (nombre para mostrar; sin email en bandeja). Al pasar el mouse o tocar el nombre se muestra el email con botón **Copiar**. Configuración del nombre en **Mi perfil** o **Seguridad → Usuarios** (Admin). Una tarea **diaria** se puede dar por hecha **durante el día de vencimiento** (calendario Argentina), sin esperar la hora.
- Modales **Nueva tarea**, **Editar** y **Mi perfil**: cuerpo con scroll vertical; botones Guardar/Cancelar fijos abajo (visible en PC y móvil).
- **Por responsable:** matriz responsable (perfil o usuario) × estado; clic en la cantidad abre modal con esas tareas.
- **Nueva tarea** (solo `crear_todo`): responsable obligatorio.
- **Editar / Eliminar** en cada fila si el rol tiene `editar_todo` / `eliminar_todo` (toggles en Seguridad). Eliminar no regenera la tarea: única desactiva la plantilla; recurrente puede ser solo esta ocurrencia o toda la serie.
- Mensajería interna (toast + modal confirmar), sin `alert`/`confirm` del navegador.
- **Excel**: exporta el listado filtrado (`todo_YYYY-MM-DD.xlsx`); prioridad como número.
- Responsive 768 / 480 (touch ≥ 44px, inputs 16px en móvil).

## Visibilidad

- Sin `crear_todo`: solo tareas donde el usuario es responsable o su rol es el responsable.
- Con `crear_todo`: ve y gestiona todas.
