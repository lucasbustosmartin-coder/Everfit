// Copiar a config.js y pegar la anon key de Everfit (Supabase → proyecto Everfit → Settings → API → anon public).
// config.js está en .gitignore para no subir la clave.

window.SUPABASE_ANON_KEY = '';

// Opcional: solo para poder usar "Actualizar base" desde el dashboard (truncar y volver a cargar Excel).
// Usar SOLO en entorno de confianza (ej. local). No subir a repositorio.
// window.SUPABASE_SERVICE_ROLE_KEY = '';
