# Git y Vercel – dejar todo alineado

Para tener el repo Everfit en GitHub y la app desplegada en Vercel (con redeploy automático en cada push a `main`), seguí estos pasos.

---

## 1. Git: crear repo y conectar

### Si todavía no inicializaste Git en el proyecto

En la terminal, desde la **raíz de Everfit**:

```bash
cd "/Users/lucasb/Escritorio - MacBook Air de Lucas/Everfit"
git init
```

### Crear el repositorio en GitHub

1. Entrá a [github.com](https://github.com) y creá un **nuevo repositorio** (New repository).
2. Nombre sugerido: `everfit`.
3. No marques “Add a README” si ya tenés archivos locales (para no tener que hacer merge).
4. Anotá la URL del repo (ej. `https://github.com/TU_USUARIO/everfit.git`).

### Conectar el repo local con GitHub

```bash
cd "/Users/lucasb/Escritorio - MacBook Air de Lucas/Everfit"
git remote add origin https://github.com/TU_USUARIO/everfit.git
```

(Reemplazá `TU_USUARIO` por tu usuario de GitHub y el nombre del repo si es distinto.)

### Primer commit y push

```bash
git add .
git status
git commit -m "Setup: estructura, reglas, bitácora, volcado Excel, tipos de cambio"
git branch -M main
git push -u origin main
```

Si te pide usuario/contraseña o token, usá tus credenciales de GitHub (o un Personal Access Token si tenés 2FA).

---

## 2. Actualizar la bitácora con la URL real

Cuando tengas la URL del repo y (más adelante) la de Vercel:

1. Abrí `scripts/crear-bitacora-excel.js`.
2. En el array `refGitVercel`, reemplazá:
   - `https://github.com/TU_USUARIO/everfit` por la URL real de tu repo.
   - `https://everfit.vercel.app/` por la URL que te dé Vercel (ej. `https://everfit-xxx.vercel.app` o tu dominio).
3. Ejecutá `node scripts/crear-bitacora-excel.js` para regenerar `Bitacora_tareas.xlsx`.
4. Hacé commit de los cambios:  
   `git add scripts/crear-bitacora-excel.js Bitacora_tareas.xlsx && git commit -m "Bitácora: URLs repo y Vercel" && git push origin main`

---

## 3. Vercel: conectar el repo y desplegar

### Conectar el proyecto Everfit a Vercel

1. Entrá a [vercel.com](https://vercel.com) e iniciá sesión (con GitHub si es posible).
2. **Add New** → **Project**.
3. **Import** el repositorio `everfit` desde GitHub (si no aparece, autorizá a Vercel para ver tus repos).
4. Configuración del proyecto:
   - **Framework Preset:** Other (o el que uses si tenés frontend).
   - **Root Directory:** dejar por defecto (`.`).
   - **Build Command:** vacío si solo tenés HTML/estáticos; si tenés build, poné `npm run build` o el que corresponda.
   - **Output Directory:** si es estático, `dist` o `.` según cómo esté armado el proyecto.
5. **Deploy**.

### Después del primer deploy

- Vercel te da una URL (ej. `https://everfit-xxx.vercel.app`). Actualizá la solapa **Ref Git y Vercel** de la bitácora con esa URL (paso 2 arriba).
- Cada **push a `main`** en GitHub va a disparar un **redeploy automático** en Vercel. No hace falta hacer nada más para que esté alineado.

### Deploy manual desde la terminal (opcional)

Si instalás la CLI de Vercel (`npm i -g vercel`) y vinculás el proyecto (`vercel link`), podés desplegar a producción con:

```bash
vercel --prod
```

---

## 4. Resumen rápido

| Qué hacer | Dónde |
|-----------|--------|
| Crear repo en GitHub | github.com → New repository → everfit |
| Conectar local con GitHub | `git remote add origin https://github.com/TU_USUARIO/everfit.git` |
| Subir código | `git add .` → `git commit -m "mensaje"` → `git push origin main` |
| Conectar Vercel | vercel.com → Add New → Project → Import everfit desde GitHub |
| Actualizar bitácora con URLs reales | Editar `refGitVercel` en `scripts/crear-bitacora-excel.js` y correr `node scripts/crear-bitacora-excel.js` |

Con eso tenés Git y Vercel alineados: cada push a `main` actualiza la app en Vercel.
