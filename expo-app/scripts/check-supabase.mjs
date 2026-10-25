// Checks that your Supabase project is set up for Cura.
//   cd expo-app && node scripts/check-supabase.mjs
// Reads EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY from .env.
import { readFileSync } from 'node:fs';
import { createClient } from '@supabase/supabase-js';

const env = {};
try {
  for (const line of readFileSync(new URL('../.env', import.meta.url), 'utf8').split('\n')) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m) env[m[1]] = m[2].trim();
  }
} catch { /* fall through to the message below */ }

const url = process.env.EXPO_PUBLIC_SUPABASE_URL || env.EXPO_PUBLIC_SUPABASE_URL;
const key = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
if (!url || !key) {
  console.log('FAIL  .env is missing EXPO_PUBLIC_SUPABASE_URL or EXPO_PUBLIC_SUPABASE_ANON_KEY.');
  process.exit(1);
}
if (!/^https:\/\/[a-z0-9]+\.supabase\.co\/?$/.test(url) && !url.startsWith('http://localhost')) {
  console.log(`WARN  ${url} does not look like a Supabase project URL (https://xxxx.supabase.co).`);
}

const db = createClient(url, key, { auth: { persistSession: false } });
let bad = 0;
const ok = (m) => console.log(`ok    ${m}`);
const fail = (m, hint) => { bad++; console.log(`FAIL  ${m}${hint ? `\n      ${hint}` : ''}`); };

// Tables exist and Row Level Security answers (signed out, you should see zero rows, not an error).
for (const t of ['profiles', 'circles', 'circle_members', 'entries', 'invites', 'caregiver_profiles']) {
  const { error } = await db.from(t).select('*', { count: 'exact', head: true });
  if (error && /fetch failed|failed to fetch|network/i.test(error.message)) {
    console.log(`FAIL  Cannot reach ${url}. Check the URL in .env and your internet connection.`);
    process.exit(1);
  }
  if (error) fail(`table ${t}`, `${error.message}. Run the whole of supabase/schema.sql in the SQL Editor.`);
  else ok(`table ${t}`);
}

// The newest join function (the one that takes a role) is installed.
const { error: rpcErr } = await db.rpc('join_circle', { code: 'ZZZZZZ', as_role: 'caregiver' });
if (rpcErr && /no care circle has that code/i.test(rpcErr.message)) ok('join_circle(code, as_role) is installed');
else if (rpcErr && /not authenticated|jwt|sign in/i.test(rpcErr.message)) ok('join_circle exists (needs sign-in, as expected)');
else fail('join_circle(code, as_role)', `${rpcErr?.message ?? 'no error returned'}. Re-run supabase/schema.sql; it replaces the older version.`);

console.log(bad ? `\n${bad} problem${bad > 1 ? 's' : ''} found.` : '\nAll good. Sign up in the app and you are live.');
process.exit(bad ? 1 : 0);
