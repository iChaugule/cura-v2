# Running Cura

Cura has two modes:

- **Demo**: "Open demo" on the welcome screen. A sample family and caregiver on one phone, with three weeks of history. Needs no setup.
- **Live**: real accounts on real phones. A family member finds caregivers who work near their loved one, sends a request, and the caregiver accepts on their own phone. Everyone in the care circle (the caregiver and any number of relatives, anywhere in the world) sees the same notes, daily check-ins and messages, each translated into the language they read.

## One-time setup for live mode (about 5 minutes)

1. Create a free project at https://supabase.com (call it `cura`).
2. In the Supabase dashboard, open **SQL Editor**, click **New query**, paste the whole of `supabase/schema.sql`, and click **Run**.
3. Open **Authentication → Sign In / Providers → Email** and turn **off** "Confirm email". (Otherwise every new account has to click an email link before it can sign in.)
4. Open **Project Settings → API**. Copy the **Project URL** and the **anon public** key into `expo-app/.env`:

   ```
   EXPO_PUBLIC_SUPABASE_URL=https://xxxx.supabase.co
   EXPO_PUBLIC_SUPABASE_ANON_KEY=eyJ...
   EXPO_PUBLIC_GEMINI_API_KEY=...
   ```

   `.env` is in `.gitignore`, so the keys never go to GitHub. The anon key is designed to be public; the database's Row Level Security rules are what protect the data.

5. In Terminal:

   ```
   cd ~/Documents/cura/expo-app
   npm install
   npx expo start
   ```

   Open it on two phones with Expo Go (or one phone plus the web version with `w`). Sign up as a caregiver on one and as a family member on the other.

## Trying the full flow

1. **Caregiver phone**: Get started → Caregiver → fill in your details and the area you work in.
2. **Family phone**: Get started → Family member → enter the loved one's address. The caregiver appears in "Caregivers nearby" if they work within travelling distance.
3. Family taps the caregiver → Request. The request appears on the caregiver's phone straight away.
4. Caregiver taps Accept. Both phones are now in the same care circle.
5. Send a message from either side. It arrives live and is translated into the reader's language.
6. Family → Info tab → "Bring in another relative" shows a 6-character code. On a third phone: welcome screen → "Join their circle" → type the code.
7. The caregiver fills in the daily check-in. After about 8 check-ins, the "What changed" section on Home starts comparing new days to the person's usual pattern.

## How the code is organised

```
expo-app/
  app/                 screens (Expo Router: one file per screen)
  src/backend/remote.ts   every database call, in one place
  src/state/AppContext.tsx  app state; sends writes to the database and listens for live updates
  src/engine/patterns.ts  the pattern engine (baselines, trend and change detection, alerts)
  src/ai/                 Gemini calls: translation, summaries, the Ask tab
supabase/schema.sql    tables, security rules and the functions the app calls
```
