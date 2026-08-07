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
```

`NEXT_PUBLIC_GOOGLE_CLIENT_ID` must be a Web OAuth client ID. The existing iOS
client ID is not enough for browser Google Sign-In.

## Current MVP Scope

- Google Sign-In via `/auth/google`
- Developer token sign-in for local API checks
- Coach sessions via `/coach` and `/sessions`
- Tasks via `/tasks`
- Journal entries stored in browser `localStorage`

Journal sync needs a future `/journals` API before it can share data with iOS.
