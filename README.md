# Cura

Cura helps families care for a loved one living with dementia, even from another city or country.

- **Find care near them.** Enter your loved one's address and Cura shows caregivers who signed up on Cura and work within travelling distance, plus real care providers nearby (home-care agencies, nursing homes, assisted living) from OpenStreetMap, with their phone numbers, websites and directions.
- **One care circle.** The caregiver and any number of relatives share the same notes, daily check-ins and messages. Each person reads messages in their own language.
- **Notice changes early.** A deterministic pattern engine learns the person's own usual days from the caregiver's check-ins and flags sustained changes, slow drifts, sudden drops and combinations (for example, drinking less while eating less). Every alert shows the check-ins behind it. Cura never diagnoses.

## Built with

TypeScript, React Native, Expo (iOS, Android and web), Supabase (Postgres with row-level security, auth and realtime), Google Gemini for translation and summaries, OpenStreetMap (Nominatim and Overpass) for places.

## Run it

See [SETUP.md](SETUP.md). Demo mode works with no setup: open the app and tap "Look around first".

## Where things are

| Path | What it is |
| --- | --- |
| `expo-app/app/` | Screens (Expo Router) |
| `expo-app/src/engine/patterns.ts` | Pattern engine: baselines, robust z-scores, CUSUM drift, sudden-change and cluster rules |
| `expo-app/src/backend/remote.ts` | Every database call |
| `expo-app/src/state/AppContext.tsx` | App state, writes to the database, live updates |
| `expo-app/src/lib/careProviders.ts` | Real local care providers from OpenStreetMap |
| `supabase/schema.sql` | Tables, security rules and database functions |
| `Cura/` | Earlier native SwiftUI prototype |
