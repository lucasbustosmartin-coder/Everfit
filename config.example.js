// Copiar a config.js y pegar la anon key de Everfit (Supabase → proyecto Everfit → Settings → API → anon public).
// config.js está en .gitignore para no subir la clave.

window.SUPABASE_ANON_KEY = '';

// Opción 2 – Tipos de cambio por API desde Sistema-Contable-Nuevo (si están definidos, el dashboard lee tipos_cambio_global del origen).
// En el proyecto origen hay que permitir SELECT anon en tipos_cambio_global (ver docs/TIPO_DE_CAMBIO_DESDE_OTRO_PROYECTO.md).
// window.ORIGEN_TC_URL = 'https://TU_PROYECTO_ORIGEN.supabase.co';
// window.ORIGEN_TC_ANON_KEY = 'eyJ...';

// Opcional: solo para poder usar "Actualizar base" desde el dashboard (truncar y volver a cargar Excel).
// Usar SOLO en entorno de confianza (ej. local). No subir a repositorio.
// window.SUPABASE_SERVICE_ROLE_KEY = '';
