#!/bin/bash
# Configura SUPABASE_ANON_KEY en Vercel y redeploya.
# Ejecutar desde la raíz del proyecto. Antes: vercel login (si hace falta).
set -e
cd "$(dirname "$0")/.."
if [ ! -f config.js ]; then
  echo "No existe config.js. Crealo desde config.example.js con tu SUPABASE_ANON_KEY."
  exit 1
fi
ANON_KEY=$(node -e "
const fs = require('fs');
const c = fs.readFileSync('config.js', 'utf8');
const m = c.match(/SUPABASE_ANON_KEY\s*=\s*['\"]([^'\"]*)['\"]/);
if (!m || !m[1]) { process.exit(1); }
console.log(m[1]);
")
if [ -z "$ANON_KEY" ]; then
  echo "No se pudo leer SUPABASE_ANON_KEY de config.js."
  exit 1
fi
echo "Vinculando proyecto (vercel link)..."
vercel link --yes
echo "Añadiendo SUPABASE_ANON_KEY a Production..."
echo "$ANON_KEY" | vercel env add SUPABASE_ANON_KEY production --force
echo "Desplegando a producción (vercel --prod)..."
vercel --prod
echo "Listo. La URL de producción ya tiene la anon key."
