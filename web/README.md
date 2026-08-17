# Cycle Journal Web

Next.js frontend for the existing Cycle Journal API.

## Setup

```bash
cd web
npm install
cp .env.example .env.local
npm run dev
```

Open http://127.0.0.1:3000.

## Environment

```bash
NEXT_PUBLIC_API_BASE_URL=https://cycle-api-prod-1031235624127.asia-northeast1.run.app
NEXT_PUBLIC_GOOGLE_CLIENT_ID=
NEXT_PUBLIC_ENABLE_DEV_LOGIN=false
```

`NEXT_PUBLIC_GOOGLE_CLIENT_ID` must be a Web OAuth client ID. The existing iOS
client ID is not enough for browser Google Sign-In. Register the exact callback
URL (`<web-origin>/auth/google/callback`) as an Authorized redirect URI. The Web
app uses Google Identity Services redirect UX so sign-in does not depend on a
popup window.

The manual token form is hidden by default. To use it only during local
development, set `NEXT_PUBLIC_ENABLE_DEV_LOGIN=true`; production builds ignore
the flag.

## Current MVP Scope

- Google Sign-In via `/auth/google`
- Home schedule and daily timeline
- Journal sync, editing, tags, trash and restore via `/journals/sync`
- Coach streaming, session history/deletion and journal context
- 4-7-8 breathing timer and local meditation history
- Task CRUD, due dates, templates, local extended fields and reflections
- Profile, browser reminder preferences and account deletion
- Automatic access-token refresh
- Developer token sign-in for local API checks only

Schedule events, meditation logs, task templates and task extended fields are
stored in browser `localStorage`. Journal entries, coach sessions and core task
fields are shared with iOS through the API.

## Development deployment

- Web: <https://cycle-web-dev-1031235624127.asia-northeast1.run.app>
- API: <https://cycle-api-dev-1031235624127.asia-northeast1.run.app>

Pushes to `develop` run `.github/workflows/web-ci-cd.yml` and deploy
`cycle-web-dev` after the Web typecheck and production build pass.
