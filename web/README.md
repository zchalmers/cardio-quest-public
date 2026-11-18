# Cardio Quest Web Dashboard

A responsive React dashboard for Cardio Quest player statistics, workout history, achievements, analytics, and community leaderboards.

## Stack

- React 18 + TypeScript
- Vite
- Tailwind CSS 3
- Recharts
- React Router
- Lucide icons

## Run locally

Requirements: Node.js 20.19+ or 22.12+ for the locked Vite dependencies.

```bash
cd web
npm ci
npm run dev
```

Vite prints the local development URL, usually `http://localhost:5173`.

## Production build

```bash
npm run build
npm run preview
```

The optimized site is written to `web/dist`.

## Data source

The dashboard works out of the box with realistic generated data from
`src/data/sampleData.ts`. To connect a JSON export endpoint from the Flutter app,
create a `.env.local` file:

```bash
VITE_CARDIO_API_URL=https://example.test/api/cardio-quest/export
```

The endpoint should return the `CardioQuestExport` shape declared in
`src/types.ts`. The `GameSummary` and `PlayerProfile` fields mirror the Flutter
models, with Dart `Duration` values serialized as seconds and `DateTime` values
serialized as ISO 8601 strings.

## Routes

- `/` — dashboard overview
- `/history` — workout history with time filters and sorting
- `/achievements` — achievement collection and progress
- `/analytics` — heart-rate, speed, distance, frequency, and records
- `/leaderboard` — weekly, all-time, speed, and challenge rankings
