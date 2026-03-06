# Módulo de Seguridad – Everfit

La app usa **login por email y contraseña** (Supabase Auth). Los permisos se controlan por **rol** (Admin, Encargado, Visor). Solo el **Admin** puede asignar perfiles a otros usuarios.

## Roles y permisos

| Rol        | Ver dashboard | Actualizar base (upload) | Asignar perfiles | Proyección |
|-----------|----------------|---------------------------|-------------------|------------|
| **Admin** | Sí             | Sí                        | Sí                | Sí (ver y configurar) |
| **Encargado** | Sí         | Sí                        | No                | Sí (ver y configurar) |
| **Visor** | Sí             | No                        | No                | No                    |

- **Actualizar base:** truncar la tabla `base_everfit` y cargar un Excel (botón "Actualizar base" en el dashboard).
- **Asignar perfiles:** acceder al módulo Seguridad y cambiar el rol de cualquier usuario.
- **Ver proyección:** ver en la tabla Flujo por mes los meses proyectados (método, meses de historia, meses a proyectar, recorte) y el botón "Proyección" para configurarlos. Solo Admin y Encargado; Visor no ve la proyección ni el botón.

## Cómo activar el módulo

### 1. Habilitar Auth con email en Supabase

1. En el proyecto Everfit: **Authentication** → **Providers**.
2. Dejá **Email** habilitado (por defecto ya está).
3. Opcional: en **Authentication** → **URL Configuration** configurá **Site URL** (ej. `https://tu-dominio.com`) y **Redirect URLs** si usás redirección después del login.

### 2. Ejecutar el SQL de seguridad

1. **SQL Editor** en Supabase.
2. Abrí `sql/supabase_seguridad.sql` y copiá todo el contenido.
3. Ejecutá el script (Run).

Para habilitar también la **proyección** (solo Admin y Encargado), ejecutá además **`sql/supabase_proyeccion_permiso_y_config.sql`**. Eso agrega el permiso `ver_proyeccion` y la tabla `config_dashboard` para guardar método, meses de historia y meses a proyectar.

Eso crea:

- `user_profiles`: id y email de cada usuario (se llena con un trigger al registrarse).
- `app_role` y `app_role_permission`: roles (admin, encargado, visor) y qué permiso tiene cada uno.
- `app_user_profile`: rol asignado a cada usuario.
- Funciones: `get_my_role()`, `has_permission(perm)`, `get_my_permissions()`, `get_users_for_admin()`.
- RLS en `base_everfit`: solo usuarios autenticados pueden leer; solo quienes tienen permiso `upload_base` pueden insertar/borrar.
- RLS en `app_user_profile` y `user_profiles` para que solo Admin vea y asigne perfiles.

### 3. Crear tu usuario y asignarte Admin (bootstrap)

Como al principio nadie es Admin, el primer admin se define con SQL:

1. Registrate en la app (dashboard): entrá a la URL del dashboard, usá "Iniciar sesión" y creá una cuenta con **tu email** y una contraseña.
2. En Supabase: **Authentication** → **Users** y comprobá que tu usuario aparezca.
3. En **SQL Editor** ejecutá (reemplazá `tu@email.com` por tu email):

```sql
-- Reemplazá tu@email.com por tu email de registro
INSERT INTO public.app_user_profile (user_id, role)
SELECT id, 'admin' FROM auth.users WHERE email = 'tu@email.com' LIMIT 1
ON CONFLICT (user_id) DO UPDATE SET role = 'admin';
```

4. Volvé a cargar el dashboard y entrá con tu usuario: ya tenés rol Admin y podés usar "Actualizar base" y el módulo **Seguridad** para asignar roles a otros.

### 4. Usuarios nuevos (Visor por defecto)

- Si el trigger de `auth.users` está activo, al registrarse se crea la fila en `user_profiles`.
- La primera vez que un usuario entra, si no tiene fila en `app_user_profile`, la app puede asignarle automáticamente el rol **Visor** (solo lectura). Si preferís que los nuevos no tengan acceso hasta que un Admin les asigne rol, podés desactivar esa auto-asignación en la app y dejar que solo Admin cree el perfil.

En el SQL actual, un usuario **puede** asignarse a sí mismo el rol `visor` una sola vez si aún no tiene perfil. Así los nuevos pueden ver el dashboard sin que un Admin les asigne nada; el Admin después puede cambiarlos a Encargado si hace falta.

## Uso en la app

- **Login:** en el dashboard se muestra pantalla de inicio de sesión (email + contraseña). Tras iniciar sesión se cargan los datos.
- **Actualizar base:** el botón solo se muestra si tu rol tiene permiso `upload_base` (Admin y Encargado).
- **Seguridad:** en el menú lateral hay un ítem "Seguridad" (solo visible para Admin). Ahí podés: **Permisos por rol:** cada rol (Admin, Encargado, Visor) se muestra con su icono y debajo cada permiso con un botón on/off editable (Actualizar base, Asignar perfiles, Proyección). Los cambios se guardan al instante. **Usuarios:** lista de usuarios con email, rol asignado y botón Guardar.

Para que los permisos por rol sean editables desde el dashboard, ejecutá además **`sql/supabase_seguridad_permisos_editable.sql`** en el SQL Editor (después de `supabase_seguridad.sql` y, si usás proyección, de `supabase_proyeccion_permiso_y_config.sql`).

## Resumen rápido

1. Habilitar Email en **Authentication** → **Providers**.
2. Ejecutar `sql/supabase_seguridad.sql` en el SQL Editor.
3. (Opcional) Ejecutar `sql/supabase_seguridad_permisos_editable.sql` para poder editar permisos por rol desde Seguridad.
4. Registrarte en la app y luego en SQL asignarte rol admin con el `INSERT` de arriba.
5. A partir de ahí, asignar perfiles y (si aplica) configurar permisos por rol desde el dashboard (módulo Seguridad).

## Notas

- La **anon key** sigue usándose en el front para las llamadas a Supabase; tras el login, el cliente envía el **token de sesión** (JWT) y Supabase aplica RLS según el usuario autenticado.
- No pongas la **service_role** en el frontend. Para "Actualizar base" desde el navegador, con el módulo de seguridad ya no hace falta: el usuario Admin o Encargado usa su sesión y RLS permite INSERT/DELETE en `base_everfit` si tiene el permiso.
