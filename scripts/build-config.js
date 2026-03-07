#!/usr/bin/env node
/**
 * Genera config.js desde variables de entorno (para Vercel u otro deploy).
 * En Vercel: Settings → Environment Variables → SUPABASE_ANON_KEY (y opcional SUPABASE_URL).
 * Build Command: node scripts/build-config.js
 */
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const url = process.env.SUPABASE_URL || 'https://skhuplgurhlezobobqrx.supabase.co';
const anonKey = process.env.SUPABASE_ANON_KEY || '';
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const origenTcUrl = process.env.ORIGEN_TC_URL || '';
const origenTcAnonKey = process.env.ORIGEN_TC_ANON_KEY || '';

const content = `// Generado en build desde variables de entorno. No editar a mano en producción.
window.SUPABASE_ANON_KEY = ${JSON.stringify(anonKey)};
window.SUPABASE_URL = ${JSON.stringify(url)};
${serviceKey ? 'window.SUPABASE_SERVICE_ROLE_KEY = ' + JSON.stringify(serviceKey) + ';' : '// window.SUPABASE_SERVICE_ROLE_KEY no definida (solo para Actualizar base en entorno de confianza).'}
${origenTcUrl ? 'window.ORIGEN_TC_URL = ' + JSON.stringify(origenTcUrl) + ';' : '// window.ORIGEN_TC_URL no definida (tipos de cambio desde tabla local tipo_de_cambio).'}
${origenTcAnonKey ? 'window.ORIGEN_TC_ANON_KEY = ' + JSON.stringify(origenTcAnonKey) + ';' : '// window.ORIGEN_TC_ANON_KEY no definida.'}
`;

fs.writeFileSync(path.join(root, 'config.js'), content, 'utf8');
console.log('config.js generado en', path.join(root, 'config.js'));
