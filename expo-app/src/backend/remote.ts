/**
 * Everything that talks to the Cura database (Supabase).
 *
 * The rest of the app never imports supabase-js directly. It calls these
 * functions, which turn database rows into the same plain objects the screens
 * already use (Account, Pnc, CareNote, ChatMessage...).
 *
 * If EXPO_PUBLIC_SUPABASE_URL / EXPO_PUBLIC_SUPABASE_ANON_KEY are not set,
 * `isLive` is false and the app runs in demo mode only.
 */
import 'react-native-url-polyfill/auto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient, type RealtimeChannel, type SupabaseClient } from '@supabase/supabase-js';
import { Platform } from 'react-native';
import type {
  Account, CareInvite, CareNote, CaregiverProfile, ChatMessage, GeoPoint, NoteComment, Pnc,
  QuizResponse, Role, ScheduleItem, ScheduleLog,
} from '../models/types';
import { haversineKm } from '../lib/geo';

const URL = process.env.EXPO_PUBLIC_SUPABASE_URL ?? '';
const ANON = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? '';

export const isLive = /^https?:\/\//.test(URL) && ANON.length > 20;

export const supabase: SupabaseClient | null = isLive
  ? createClient(URL, ANON, {
      auth: {
        storage: AsyncStorage,
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: Platform.OS === 'web',
      },
    })
  : null;

function db(): SupabaseClient {
  if (!supabase) throw new Error('Cura is not connected to a database yet.');
  return supabase;
}

/** Turn a Supabase error into a sentence a person can act on. */
export function friendlyDbError(err: unknown): string {
  const msg = (err as { message?: string })?.message ?? String(err);
  if (/Invalid login credentials/i.test(msg)) return 'That email and password do not match an account.';
  if (/already registered|already exists/i.test(msg)) return 'There is already an account with that email. Sign in instead.';
  if (/Password should be/i.test(msg)) return 'Use a password of at least 6 characters.';
  if (/Email not confirmed/i.test(msg)) return 'Confirm your email first, using the link we sent you.';
  if (/Failed to fetch|Network request failed/i.test(msg)) return 'Could not reach Cura. Check your connection.';
  return msg;
}

// ── Row shapes ──────────────────────────────────────────────

interface ProfileRow {
  id: string; role: Role; name: string; phone: string; language: string; relationship: string | null;
}
interface ListingRow {
  user_id: string; display_name: string; headline: string; bio: string; hourly_rate: number;
  years_experience: number; specialties: string[]; languages: string[]; area_label: string;
  lat: number; lng: number; service_radius_km: number; available: boolean;
}
interface CircleRow { id: string; created_by: string; pnc: Pnc; join_code: string }
interface InviteRow {
  id: string; circle_id: string; family_id: string; caregiver_id: string;
  status: CareInvite['status']; data: Omit<CareInvite, 'id' | 'status'>; created_at: string;
  responded_at: string | null;
}
export type EntryKind = 'note' | 'comment' | 'quiz' | 'message' | 'schedule' | 'dose';
interface EntryRow { id: string; circle_id: string; author_id: string; kind: EntryKind; data: any; created_at: string }

export interface CaregiverListing {
  hourlyRate: number; yearsExperience: number; specialties: string[]; languages: string[];
  bio: string; headline: string; areaLabel: string; location: GeoPoint; serviceRadiusKm: number;
}

const toAccount = (p: ProfileRow, email = ''): Account => ({
  id: p.id, role: p.role, name: p.name, email, phone: p.phone, language: p.language,
  relationship: p.relationship ?? undefined,
});

const initialsOf = (name: string) =>
  name.split(/\s+/).filter(Boolean).slice(0, 2).map(w => w[0]?.toUpperCase()).join('');

function toCaregiver(r: ListingRow, origin?: GeoPoint): CaregiverProfile {
  const location = { lat: r.lat, lng: r.lng };
  return {
    id: r.user_id,
    name: r.display_name,
    photoInitials: initialsOf(r.display_name),
    headline: r.headline || 'Caregiver',
    bio: r.bio,
    // New caregivers have no reviews yet, and Cura does not invent them.
    rating: 0,
    reviewCount: 0,
    yearsExperience: r.years_experience,
    hourlyRate: Number(r.hourly_rate),
    specialties: r.specialties,
    languages: r.languages,
    certifications: [],
    location,
    neighborhood: r.area_label,
    distanceKm: origin ? haversineKm(origin, location) : undefined,
    availability: r.available ? 'Taking new families' : 'Not taking new families',
    respondsIn: `Travels up to ${Number(r.service_radius_km)} km`,
  };
}

/** Round to about 1 km so we never store where a caregiver actually lives. */
const coarse = (n: number) => Math.round(n * 100) / 100;

// ── Auth ────────────────────────────────────────────────────

export async function signUp(email: string, password: string, profile: Omit<Account, 'id' | 'email'>) {
  const { data, error } = await db().auth.signUp({ email: email.trim(), password });
  if (error) throw error;
  if (!data.session) {
    throw new Error('Check your email to confirm the account, then sign in. (Turn off "Confirm email" in Supabase to skip this.)');
  }
  const id = data.user!.id;
  const { error: pErr } = await db().from('profiles').insert({
    id, role: profile.role, name: profile.name, phone: profile.phone,
    language: profile.language, relationship: profile.relationship ?? null,
  });
  if (pErr) throw pErr;
  return toAccount({ id, ...profile, relationship: profile.relationship ?? null } as ProfileRow, email.trim());
}

export async function signIn(email: string, password: string) {
  const { error } = await db().auth.signInWithPassword({ email: email.trim(), password });
  if (error) throw error;
}

export async function signOut() {
  await supabase?.auth.signOut();
}

export async function updateProfile(patch: Partial<Account>) {
  const { data: { session } } = await db().auth.getSession();
  const row: Record<string, unknown> = {};
  if (patch.name !== undefined) row.name = patch.name;
  if (patch.phone !== undefined) row.phone = patch.phone;
  if (patch.language !== undefined) row.language = patch.language;
  if (patch.relationship !== undefined) row.relationship = patch.relationship;
  if (!Object.keys(row).length) return;
  const { error } = await db().from('profiles').update(row).eq('id', session?.user.id);
  if (error) throw error;
}

// ── Loading everything for the signed-in person ─────────────

export interface Snapshot {
  me: Account;
  circleId: string | null;
  joinCode: string | null;
  pnc: Pnc | null;
  members: Account[];
  invites: CareInvite[];
  notes: CareNote[];
  quizzes: QuizResponse[];
  messages: ChatMessage[];
  schedule: ScheduleItem[];
  scheduleLog: ScheduleLog[];
  listing: CaregiverListing | null;
}

export async function loadSnapshot(): Promise<Snapshot | null> {
  const { data: { session } } = await db().auth.getSession();
  if (!session) return null;
  const uid = session.user.id;

  const { data: prof, error } = await db().from('profiles').select('*').eq('id', uid).maybeSingle();
  if (error) throw error;
  if (!prof) return null; // signed up but profile not written; treat as signed out
  const me = toAccount(prof as ProfileRow, session.user.email ?? '');

  // A person is in at most one circle in this version: the one they created or
  // joined first.
  const { data: memberships } = await db()
    .from('circle_members').select('circle_id, joined_at').eq('user_id', uid).order('joined_at');
  const circleId = memberships?.[0]?.circle_id ?? null;

  const [circle, members, invites, entries, listing] = await Promise.all([
    circleId ? db().from('circles').select('*').eq('id', circleId).single() : Promise.resolve({ data: null }),
    circleId ? loadMembers(circleId) : Promise.resolve([] as Account[]),
    db().from('invites').select('*').order('created_at', { ascending: false }),
    circleId
      ? db().from('entries').select('*').eq('circle_id', circleId).order('created_at', { ascending: false }).limit(1000)
      : Promise.resolve({ data: [] as EntryRow[] }),
    me.role === 'caregiver'
      ? db().from('caregiver_profiles').select('*').eq('user_id', uid).maybeSingle()
      : Promise.resolve({ data: null }),
  ]);

  const rows = (entries.data ?? []) as EntryRow[];
  const l = listing.data as ListingRow | null;
  return {
    me,
    circleId,
    joinCode: (circle.data as CircleRow | null)?.join_code ?? null,
    pnc: (circle.data as CircleRow | null)?.pnc ?? null,
    members,
    invites: ((invites.data ?? []) as InviteRow[]).map(fromInviteRow),
    ...entriesToState(rows),
    listing: l ? {
      hourlyRate: Number(l.hourly_rate), yearsExperience: l.years_experience, specialties: l.specialties,
      languages: l.languages, bio: l.bio, headline: l.headline, areaLabel: l.area_label,
      location: { lat: l.lat, lng: l.lng }, serviceRadiusKm: Number(l.service_radius_km),
    } : null,
  };
}

export async function loadMembers(circleId: string): Promise<Account[]> {
  const { data: rows } = await db().from('circle_members').select('user_id, role').eq('circle_id', circleId);
  const ids = (rows ?? []).map(r => r.user_id);
  if (!ids.length) return [];
  const { data: profs } = await db().from('profiles').select('*').in('id', ids);
  return ((profs ?? []) as ProfileRow[]).map(p => toAccount(p));
}

/** Profiles of people on the other side of an invite (before they share a circle). */
export async function loadProfiles(ids: string[]): Promise<Account[]> {
  if (!ids.length) return [];
  const { data } = await db().from('profiles').select('*').in('id', ids);
  return ((data ?? []) as ProfileRow[]).map(p => toAccount(p));
}

// ── Entries: notes, comments, check-ins, messages ───────────

export function entriesToState(rows: EntryRow[]) {
  const comments = rows.filter(r => r.kind === 'comment').map(r => r.data as NoteComment & { noteId: string });
  const notes = rows.filter(r => r.kind === 'note').map(r => ({
    ...(r.data as CareNote),
    comments: comments.filter(c => c.noteId === r.id).sort((a, b) => a.createdAt - b.createdAt),
  }));
  const quizzes = rows.filter(r => r.kind === 'quiz').map(r => r.data as QuizResponse);
  const messages = rows.filter(r => r.kind === 'message').map(r => r.data as ChatMessage)
    .sort((a, b) => a.createdAt - b.createdAt);
  const schedule = rows.filter(r => r.kind === 'schedule').map(r => r.data as ScheduleItem)
    .sort((a, b) => a.time.localeCompare(b.time));
  const scheduleLog = rows.filter(r => r.kind === 'dose').map(r => r.data as ScheduleLog);
  return { notes, quizzes, messages, schedule, scheduleLog };
}

export async function addEntry(circleId: string, kind: EntryKind, id: string, data: object) {
  const { data: { session } } = await db().auth.getSession();
  const { error } = await db().from('entries').insert({
    id, circle_id: circleId, author_id: session?.user.id, kind, data,
  });
  if (error) throw error;
}

export async function updateEntry(id: string, data: object) {
  const { error } = await db().from('entries').update({ data }).eq('id', id);
  if (error) throw error;
}

export async function deleteEntry(id: string) {
  const { error } = await db().from('entries').delete().eq('id', id);
  if (error) throw error;
}

/** Messages are stored without translations; each phone translates for its reader. */
export const stripMessage = (m: ChatMessage) => ({ ...m, translations: {}, translating: undefined });
/** Notes are stored without comments; comments are their own rows. */
export const stripNote = (n: CareNote) => ({ ...n, comments: [] });

// ── Circles ────────────────────────────────────────────────

export async function createCircle(pnc: Pnc): Promise<{ id: string; joinCode: string }> {
  const { data, error } = await db().rpc('create_circle', { pnc });
  if (error) throw error;
  const row = data as CircleRow;
  return { id: row.id, joinCode: row.join_code };
}

export async function joinCircle(code: string, role: 'family' | 'caregiver' = 'family') {
  const { error } = await db().rpc('join_circle', { code, as_role: role });
  if (error) throw error;
}

export async function updateCirclePnc(circleId: string, pnc: Pnc) {
  const { error } = await db().from('circles').update({ pnc }).eq('id', circleId);
  if (error) throw error;
}

// ── Caregiver directory ────────────────────────────────────

export async function saveListing(name: string, l: CaregiverListing) {
  const { data: { session } } = await db().auth.getSession();
  const { error } = await db().from('caregiver_profiles').upsert({
    user_id: session?.user.id,
    display_name: name,
    headline: l.headline,
    bio: l.bio,
    hourly_rate: l.hourlyRate,
    years_experience: l.yearsExperience,
    specialties: l.specialties,
    languages: l.languages,
    area_label: l.areaLabel,
    lat: coarse(l.location.lat),
    lng: coarse(l.location.lng),
    service_radius_km: l.serviceRadiusKm,
    available: true,
    updated_at: new Date().toISOString(),
  });
  if (error) throw error;
}

/**
 * Caregivers who would travel to `origin`: within their own travel radius and
 * within `maxKm` overall. Nearest first.
 */
export async function searchCaregivers(origin: GeoPoint, maxKm = 50): Promise<CaregiverProfile[]> {
  // A rough bounding box keeps the query small; exact distance is checked below.
  const dLat = maxKm / 111;
  const dLng = maxKm / (111 * Math.max(0.2, Math.cos((origin.lat * Math.PI) / 180)));
  const { data, error } = await db()
    .from('caregiver_profiles').select('*')
    .eq('available', true)
    .gte('lat', origin.lat - dLat).lte('lat', origin.lat + dLat)
    .gte('lng', origin.lng - dLng).lte('lng', origin.lng + dLng)
    .limit(200);
  if (error) throw error;
  return ((data ?? []) as ListingRow[])
    .map(r => ({ row: r, cg: toCaregiver(r, origin) }))
    .filter(({ row, cg }) => (cg.distanceKm ?? 0) <= Math.min(maxKm, Number(row.service_radius_km) + 1))
    .map(({ cg }) => cg)
    .sort((a, b) => (a.distanceKm ?? 0) - (b.distanceKm ?? 0));
}

// ── Invites ────────────────────────────────────────────────

function fromInviteRow(r: InviteRow): CareInvite {
  return {
    ...r.data,
    id: r.id,
    status: r.status,
    respondedAt: r.responded_at ? Date.parse(r.responded_at) : r.data.respondedAt,
  };
}

export async function sendInvite(circleId: string, invite: CareInvite) {
  const { data: { session } } = await db().auth.getSession();
  const { id, status: _s, ...data } = invite;
  const { error } = await db().from('invites').insert({
    id, circle_id: circleId, family_id: session?.user.id, caregiver_id: invite.caregiverId,
    status: 'pending', data,
  });
  if (error) throw error;
}

export async function answerInvite(id: string, status: 'accepted' | 'declined') {
  const { error } = await db().from('invites').update({ status }).eq('id', id);
  if (error) throw error;
}

// ── Live updates ───────────────────────────────────────────

export interface LiveHandlers {
  onEntry: (kind: EntryKind, data: any, id: string, event: 'INSERT' | 'UPDATE' | 'DELETE') => void;
  onInvite: (invite: CareInvite) => void;
  onCircle: (pnc: Pnc) => void;
  onMembersChanged: () => void;
  /** Live updates could not connect; the app falls back to checking every few seconds. */
  onLiveUnavailable: () => void;
}

/** Subscribe to everything this person can see. Returns an unsubscribe function. */
export function subscribe(userId: string, circleId: string | null, h: LiveHandlers): () => void {
  const channels: RealtimeChannel[] = [];
  const s = db();
  let reported = false;
  const status = (st: string) => {
    if (!reported && (st === 'CHANNEL_ERROR' || st === 'TIMED_OUT' || st === 'CLOSED')) {
      reported = true;
      h.onLiveUnavailable();
    }
  };

  // Invites addressed to me (caregiver side), any circle.
  channels.push(
    s.channel(`invites-me-${userId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'invites', filter: `caregiver_id=eq.${userId}` },
        p => { if (p.new && 'id' in p.new) h.onInvite(fromInviteRow(p.new as InviteRow)); })
      .subscribe(status),
  );

  if (circleId) {
    channels.push(
      s.channel(`circle-${circleId}`)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'entries', filter: `circle_id=eq.${circleId}` },
          p => {
            const row = (p.eventType === 'DELETE' ? p.old : p.new) as EntryRow;
            h.onEntry(row.kind, row.data, row.id, p.eventType);
          })
        .on('postgres_changes', { event: '*', schema: 'public', table: 'invites', filter: `circle_id=eq.${circleId}` },
          p => { if (p.new && 'id' in p.new) h.onInvite(fromInviteRow(p.new as InviteRow)); })
        .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'circles', filter: `id=eq.${circleId}` },
          p => h.onCircle((p.new as CircleRow).pnc))
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'circle_members', filter: `circle_id=eq.${circleId}` },
          () => h.onMembersChanged())
        .subscribe(status),
    );
  }

  return () => { channels.forEach(c => s.removeChannel(c)); };
}
