# Road Change

Road Change is a calm, cinematic personal transformation operating system for long-term goals, deep work, knowledge organization, health recovery, and measurable evolution.

The repository is intentionally split into two top-level work areas:

- `frontend/` - Next.js 15 App Router application.
- `backend/` - Supabase schema, RLS notes, and database documentation.

## Vercel Deployment

Deploy from the repository root. The root `vercel.json` installs with `npm ci`, builds with `npm run build`, and outputs `frontend/.next`.

Set these environment variables in Vercel before deploying:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

Recommended Vercel settings:

- Root Directory: repository root
- Install Command: `npm ci`
- Build Command: `npm run build`
- Output Directory: `frontend/.next`
- Node.js Version: `20.x`

Local commands from the repository root:

- `npm run dev`
- `npm run build`
- `npm run lint`
