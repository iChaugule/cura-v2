/**
 * Real care providers near an address, from OpenStreetMap.
 *
 * These are actual organisations mapped by volunteers: nursing homes, assisted
 * living, adult day care, home-care agencies and nurses, with whatever contact
 * details are on the map (phone, website, email, opening hours). Cura does not
 * vouch for them; it finds them and makes them easy to contact.
 *
 * Data © OpenStreetMap contributors, available under the Open Database Licence.
 * Queried through the public Overpass API, which needs no key.
 */
import { Platform } from 'react-native';
import type { GeoPoint } from '../models/types';
import { haversineKm } from './geo';

const ENDPOINTS = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
];

export type ProviderKind =
  | 'home_care' | 'nursing_home' | 'assisted_living' | 'day_care' | 'nurse' | 'group_home' | 'senior_services';

export const KIND_LABEL: Record<ProviderKind, string> = {
  home_care: 'Home care',
  nursing_home: 'Nursing home',
  assisted_living: 'Assisted living',
  day_care: 'Adult day care',
  nurse: 'Nursing service',
  group_home: 'Care home',
  senior_services: 'Senior services',
};

export interface CareProvider {
  id: string;
  name: string;
  kind: ProviderKind;
  location: GeoPoint;
  distanceKm: number;
  address: string | null;
  phone: string | null;
  website: string | null;
  email: string | null;
  openingHours: string | null;
  /** Mapped as serving older people, or names dementia / memory care. */
  forSeniors: boolean;
  mentionsDementia: boolean;
  /** Link to the place on openstreetmap.org, so anyone can check or correct it. */
  osmUrl: string;
}

const NAME_HINTS =
  'home care|homecare|home nursing|home health|caregiv|care giver|elder ?care|senior care|senior living|' +
  'dementia|alzheimer|memory care|old age home|vruddhashram|vridhashram|aged care|attendant';

function buildQuery(o: GeoPoint, radiusM: number): string {
  const a = `(around:${radiusM},${o.lat.toFixed(5)},${o.lng.toFixed(5)})`;
  return `[out:json][timeout:25];
(
  nwr["social_facility"~"nursing_home|assisted_living|group_home|day_care|outreach|ambulatory_care"]${a};
  nwr["amenity"="nursing_home"]${a};
  nwr["healthcare"~"^(nursing_home|nurse|home_care|caregiver)$"]${a};
  nwr["name"~"${NAME_HINTS}",i]["amenity"!~"pharmacy|school|kindergarten|place_of_worship"]${a};
);
out center tags 150;`;
}

interface OsmElement {
  type: 'node' | 'way' | 'relation';
  id: number;
  lat?: number;
  lon?: number;
  center?: { lat: number; lon: number };
  tags?: Record<string, string>;
}

function kindOf(t: Record<string, string>): ProviderKind {
  const sf = t.social_facility ?? '';
  const hc = t.healthcare ?? '';
  const name = (t.name ?? '').toLowerCase();
  if (/home.?care|home nursing|home health|caregiv|attendant/.test(name) || hc === 'home_care' || hc === 'caregiver' || sf === 'outreach') return 'home_care';
  if (sf === 'assisted_living') return 'assisted_living';
  if (sf === 'day_care') return 'day_care';
  if (sf === 'nursing_home' || t.amenity === 'nursing_home' || hc === 'nursing_home') return 'nursing_home';
  if (hc === 'nurse') return 'nurse';
  if (sf === 'group_home') return 'group_home';
  return 'senior_services';
}

function addressOf(t: Record<string, string>): string | null {
  if (t['addr:full']) return t['addr:full'];
  const street = [t['addr:housenumber'], t['addr:street']].filter(Boolean).join(' ');
  const parts = [street, t['addr:suburb'] ?? t['addr:neighbourhood'], t['addr:city'] ?? t['addr:town'] ?? t['addr:village'], t['addr:postcode']]
    .filter(Boolean);
  return parts.length ? parts.join(', ') : null;
}

const clean = (v?: string) => (v ? v.split(';')[0].trim() : null);

function toProvider(e: OsmElement, origin: GeoPoint): CareProvider | null {
  const t = e.tags ?? {};
  const lat = e.lat ?? e.center?.lat;
  const lon = e.lon ?? e.center?.lon;
  const name = t.name ?? t['name:en'] ?? t.operator;
  if (!name || lat === undefined || lon === undefined) return null;
  // Child and youth facilities share some of these tags; leave them out.
  const forWho = `${t['social_facility:for'] ?? ''}`.toLowerCase();
  if (/child|juvenile|orphan|youth/.test(forWho)) return null;
  const location = { lat, lng: lon };
  const text = `${name} ${t.description ?? ''} ${t['healthcare:speciality'] ?? ''}`.toLowerCase();
  let website = clean(t.website ?? t['contact:website'] ?? t.url);
  if (website && !/^https?:\/\//.test(website)) website = `https://${website}`;
  return {
    id: `osm-${e.type}-${e.id}`,
    name,
    kind: kindOf(t),
    location,
    distanceKm: haversineKm(origin, location),
    address: addressOf(t),
    phone: clean(t.phone ?? t['contact:phone'] ?? t['contact:mobile']),
    website,
    email: clean(t.email ?? t['contact:email']),
    openingHours: t.opening_hours ?? null,
    forSeniors: /senior|elder|aged|old/.test(forWho) || /senior|elder|old age|aged/.test(text),
    mentionsDementia: /dementia|alzheimer|memory/.test(text),
    osmUrl: `https://www.openstreetmap.org/${e.type}/${e.id}`,
  };
}

/** Most useful first: dementia-specific, then home care, then nearest. */
function rank(p: CareProvider): number {
  let score = p.distanceKm;
  if (p.mentionsDementia) score -= 8;
  if (p.kind === 'home_care') score -= 4;
  if (p.forSeniors) score -= 2;
  if (p.phone || p.website) score -= 1;
  return score;
}

const cache = new Map<string, CareProvider[]>();

export class ProviderSearchError extends Error {}

// ── Source 1: Nominatim (OpenStreetMap search) ──────────────
// Reliable, but returns a handful of places per phrase and allows about one
// request a second, so phrases are asked one after another.

const NOMINATIM = 'https://nominatim.openstreetmap.org/search';
const PHRASES = [
  'home care', 'nursing home', 'old age home', 'assisted living', 'dementia',
  'elder care', 'home nursing', 'senior living', 'caregiver',
];
const UA = 'CuraCareApp/1.0 (dementia care coordination; student project)';

interface NominatimPlace {
  osm_type: 'node' | 'way' | 'relation';
  osm_id: number;
  lat: string;
  lon: string;
  name?: string;
  display_name: string;
  category: string;
  type: string;
  extratags?: Record<string, string> | null;
  address?: Record<string, string>;
}

const RELEVANT = new RegExp(NAME_HINTS, 'i');

function viewbox(o: GeoPoint, km: number) {
  const dLat = km / 111;
  const dLng = km / (111 * Math.max(0.2, Math.cos((o.lat * Math.PI) / 180)));
  return [o.lng - dLng, o.lat + dLat, o.lng + dLng, o.lat - dLat].map(n => n.toFixed(4)).join(',');
}

function fromNominatim(p: NominatimPlace, origin: GeoPoint): CareProvider | null {
  const name = p.name || p.display_name.split(',')[0];
  const cat = `${p.category}/${p.type}`;
  const careTagged =
    /^amenity\/(nursing_home|social_facility)$/.test(cat) || p.category === 'healthcare' ||
    (p.extratags?.social_facility ?? '') !== '';
  const businessNamedForCare = /^(office|amenity|building|healthcare|shop)\//.test(cat) && RELEVANT.test(name);
  if (!careTagged && !businessNamedForCare) return null;
  const tags: Record<string, string> = { ...(p.extratags ?? {}), name };
  if (p.category === 'amenity') tags.amenity = p.type;
  if (p.category === 'healthcare') tags.healthcare = p.type;
  const a = p.address ?? {};
  if (!tags['addr:street'] && a.road) tags['addr:street'] = a.road;
  if (!tags['addr:housenumber'] && a.house_number) tags['addr:housenumber'] = a.house_number;
  if (!tags['addr:suburb'] && (a.suburb || a.neighbourhood)) tags['addr:suburb'] = a.suburb ?? a.neighbourhood;
  if (!tags['addr:city'] && (a.city || a.town || a.village)) tags['addr:city'] = a.city ?? a.town ?? a.village;
  if (!tags['addr:postcode'] && a.postcode) tags['addr:postcode'] = a.postcode;
  return toProvider(
    { type: p.osm_type, id: p.osm_id, lat: parseFloat(p.lat), lon: parseFloat(p.lon), tags },
    origin,
  );
}

async function nominatimSearch(
  origin: GeoPoint, radiusKm: number, onBatch: (found: CareProvider[]) => void, signal?: AbortSignal,
) {
  for (let i = 0; i < PHRASES.length; i++) {
    if (signal?.aborted) return;
    const url = `${NOMINATIM}?format=jsonv2&extratags=1&addressdetails=1&limit=25&bounded=1` +
      `&viewbox=${viewbox(origin, radiusKm)}&q=${encodeURIComponent(PHRASES[i])}`;
    try {
      // Browsers send their own User-Agent; setting one there would force a CORS preflight.
      const headers: Record<string, string> = Platform.OS === 'web' ? {} : { 'User-Agent': UA };
      const res = await fetch(url, { signal, headers: { Accept: 'application/json', ...headers } });
      if (res.ok) {
        const places = (await res.json()) as NominatimPlace[];
        onBatch(places.map(p => fromNominatim(p, origin)).filter((p): p is CareProvider => !!p));
      }
    } catch (err) {
      if ((err as Error)?.name === 'AbortError') return;
    }
    // Nominatim's usage policy: at most one request per second.
    if (i < PHRASES.length - 1) await new Promise(r => setTimeout(r, 1100));
  }
}

// ── Source 2: Overpass (OpenStreetMap database) ─────────────
// Finds everything tagged as care in one go when it is available, but the
// public servers are often at capacity, so it gets a short time limit.

async function overpassSearch(origin: GeoPoint, radiusKm: number, signal?: AbortSignal): Promise<CareProvider[]> {
  const body = `data=${encodeURIComponent(buildQuery(origin, Math.round(radiusKm * 1000)))}`;
  for (const url of ENDPOINTS) {
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), 8_000);
    const stop = () => ctl.abort();
    signal?.addEventListener('abort', stop);
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body,
        signal: ctl.signal,
      });
      if (!res.ok) continue;
      const json = (await res.json()) as { elements?: OsmElement[] };
      return (json.elements ?? [])
        .map(e => toProvider(e, origin))
        .filter((p): p is CareProvider => !!p);
    } catch {
      if (signal?.aborted) return [];
    } finally {
      clearTimeout(timer);
      signal?.removeEventListener('abort', stop);
    }
  }
  return [];
}

// ── Together ────────────────────────────────────────────────

function merge(into: Map<string, CareProvider>, found: CareProvider[], radiusKm: number) {
  for (const p of found) {
    if (p.distanceKm > radiusKm + 0.5) continue;
    // The same place is often mapped twice (a point and a building outline).
    const key = `${p.name.toLowerCase().replace(/[^a-z0-9]/g, '')}|${p.location.lat.toFixed(2)}|${p.location.lng.toFixed(2)}`;
    const prev = into.get(key);
    into.set(key, prev ? {
      ...prev,
      phone: prev.phone ?? p.phone,
      website: prev.website ?? p.website,
      email: prev.email ?? p.email,
      address: prev.address ?? p.address,
      openingHours: prev.openingHours ?? p.openingHours,
    } : p);
  }
}

/**
 * Real care providers within `radiusKm`, most useful first. `onProgress` gets
 * the list so far every time a source answers, so the screen fills in as
 * results arrive instead of waiting for the slowest one.
 */
export async function searchCareProviders(
  origin: GeoPoint,
  radiusKm = 15,
  onProgress?: (list: CareProvider[]) => void,
  signal?: AbortSignal,
): Promise<CareProvider[]> {
  const key = `${origin.lat.toFixed(3)},${origin.lng.toFixed(3)},${radiusKm}`;
  const hit = cache.get(key);
  if (hit) { onProgress?.(hit); return hit; }

  const all = new Map<string, CareProvider>();
  const emit = () => {
    const list = [...all.values()].sort((a, b) => rank(a) - rank(b));
    onProgress?.(list);
    return list;
  };

  await Promise.all([
    overpassSearch(origin, radiusKm, signal).then(found => { merge(all, found, radiusKm); emit(); }),
    nominatimSearch(origin, radiusKm, found => { merge(all, found, radiusKm); emit(); }, signal),
  ]);
  if (signal?.aborted) return [];
  const list = emit();
  cache.set(key, list);
  return list;
}

/** Search Google Maps for the same thing, for areas OpenStreetMap covers thinly. */
export function mapsSearchUrl(area: string): string {
  return `https://www.google.com/maps/search/${encodeURIComponent(`dementia home care near ${area}`)}`;
}

/** A directions link that opens in the phone's maps app or the browser. */
export function directionsUrl(p: CareProvider): string {
  return `https://www.google.com/maps/dir/?api=1&destination=${p.location.lat},${p.location.lng}`;
}

export function telUrl(phone: string): string {
  return `tel:${phone.replace(/[^\d+]/g, '')}`;
}
