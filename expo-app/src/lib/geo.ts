/**
 * Location helpers: address lookup, distance maths, and the slippy-map tile
 * arithmetic the map component uses to place caregiver pins.
 */
import { Platform } from 'react-native';
import type { GeoPoint, PlaceResult } from '../models/types';

const EARTH_RADIUS_KM = 6371;
const NOMINATIM = 'https://nominatim.openstreetmap.org/search';

/** OpenStreetMap asks for an identifying User-Agent / Referer. */
const UA = 'CuraCareApp/1.0 (home care coordination demo)';

export function haversineKm(a: GeoPoint, b: GeoPoint): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(h));
}

export function formatDistance(km: number): string {
  if (km < 1) return `${Math.round(km * 1000)} m away`;
  return `${km.toFixed(1)} km away`;
}

/** Move a point `km` along `bearingDeg` (0 = north). */
export function offsetPoint(origin: GeoPoint, km: number, bearingDeg: number): GeoPoint {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const toDeg = (r: number) => (r * 180) / Math.PI;
  const d = km / EARTH_RADIUS_KM;
  const brg = toRad(bearingDeg);
  const lat1 = toRad(origin.lat);
  const lng1 = toRad(origin.lng);

  const lat2 = Math.asin(
    Math.sin(lat1) * Math.cos(d) + Math.cos(lat1) * Math.sin(d) * Math.cos(brg),
  );
  const lng2 =
    lng1 +
    Math.atan2(
      Math.sin(brg) * Math.sin(d) * Math.cos(lat1),
      Math.cos(d) - Math.sin(lat1) * Math.sin(lat2),
    );
  return { lat: toDeg(lat2), lng: ((toDeg(lng2) + 540) % 360) - 180 };
}

/** Stable 0–1 pseudo-random from a string — keeps caregiver pins put. */
export function hashUnit(seed: string, salt = 0): number {
  let h = 2166136261 ^ salt;
  for (let i = 0; i < seed.length; i++) {
    h ^= seed.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return ((h >>> 0) % 100000) / 100000;
}

// ── Address search ──────────────────────────────────────────

/** A few well-known places so the flow still works with no network. */
const FALLBACK_PLACES: PlaceResult[] = [
  { label: 'Shivaji Nagar, Pune, Maharashtra, India', shortLabel: 'Shivaji Nagar, Pune', lat: 18.5308, lng: 73.8475 },
  { label: 'Koregaon Park, Pune, Maharashtra, India', shortLabel: 'Koregaon Park, Pune', lat: 18.5362, lng: 73.8939 },
  { label: 'Bandra West, Mumbai, Maharashtra, India', shortLabel: 'Bandra West, Mumbai', lat: 19.0596, lng: 72.8295 },
  { label: 'Indiranagar, Bengaluru, Karnataka, India', shortLabel: 'Indiranagar, Bengaluru', lat: 12.9784, lng: 77.6408 },
  { label: 'Jersey City, New Jersey, United States', shortLabel: 'Jersey City, NJ', lat: 40.7282, lng: -74.0776 },
  { label: 'Brooklyn, New York, United States', shortLabel: 'Brooklyn, NY', lat: 40.6782, lng: -73.9442 },
];

function shorten(displayName: string): string {
  const parts = displayName.split(',').map(p => p.trim());
  if (parts.length <= 2) return displayName;
  return [parts[0], parts[parts.length - 3] ?? parts[1]].filter(Boolean).join(', ');
}

/**
 * Look up an address. Falls back to a small built-in list if the geocoder is
 * unreachable, so onboarding never dead-ends.
 */
export async function searchPlaces(query: string, signal?: AbortSignal): Promise<PlaceResult[]> {
  const q = query.trim();
  if (q.length < 3) return [];

  const local = FALLBACK_PLACES.filter(p =>
    p.label.toLowerCase().includes(q.toLowerCase()),
  );

  try {
    const url = `${NOMINATIM}?format=jsonv2&limit=6&addressdetails=0&q=${encodeURIComponent(q)}`;
    const res = await fetch(url, {
      signal,
      // Browsers set their own User-Agent and Referer; adding them would force a CORS preflight.
      headers: Platform.OS === 'web' ? { Accept: 'application/json' } : { Accept: 'application/json', 'User-Agent': UA },
    });
    if (!res.ok) throw new Error(`Geocoder ${res.status}`);
    const data = (await res.json()) as any[];
    const results: PlaceResult[] = data
      .filter(d => d?.lat && d?.lon)
      .map(d => ({
        label: d.display_name as string,
        shortLabel: shorten(d.display_name as string),
        lat: parseFloat(d.lat),
        lng: parseFloat(d.lon),
      }));
    return results.length ? results : local;
  } catch {
    return local;
  }
}

// ── Slippy map tile maths ───────────────────────────────────

export const TILE_SIZE = 256;

export function lngToTileX(lng: number, zoom: number): number {
  return ((lng + 180) / 360) * 2 ** zoom;
}

export function latToTileY(lat: number, zoom: number): number {
  const rad = (Math.max(-85.05, Math.min(85.05, lat)) * Math.PI) / 180;
  return ((1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2) * 2 ** zoom;
}

/** Pixel offset of `point` from `center` at `zoom`. */
export function pixelOffset(center: GeoPoint, point: GeoPoint, zoom: number) {
  return {
    x: (lngToTileX(point.lng, zoom) - lngToTileX(center.lng, zoom)) * TILE_SIZE,
    y: (latToTileY(point.lat, zoom) - latToTileY(center.lat, zoom)) * TILE_SIZE,
  };
}

/**
 * Esri's World Street Map — keyless, warm-toned, and street names stay legible
 * at neighbourhood zoom.
 *
 * Two other providers were ruled out: Carto's basemaps now stamp
 * "API KEY REQUIRED" across every tile, and OpenStreetMap's volunteer servers
 * return a 403 "Access blocked" tile to apps under their usage policy.
 *
 * NOTE: Esri's free tier covers development and non-commercial use with
 * attribution. Before launching commercially, sign up with a tile provider
 * (MapTiler, Mapbox, Carto or Esri paid) and put the key in an
 * EXPO_PUBLIC_ env var — only this function needs to change.
 *
 * Esri orders its path {z}/{row}/{col}, i.e. y before x — not the usual XYZ.
 */
export function tileUrl(x: number, y: number, zoom: number): string {
  const n = 2 ** zoom;
  const wrappedX = ((x % n) + n) % n;
  return (
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map' +
    `/MapServer/tile/${zoom}/${y}/${wrappedX}`
  );
}

/** Shown on the map to satisfy the provider's attribution requirement. */
export const TILE_ATTRIBUTION = '© Esri · © OpenStreetMap contributors';

/**
 * Zoom that fits `radiusKm` into a viewport `widthPx` wide.
 *
 * Floors at 12 — below that a city block is a smudge and the map stops telling
 * you anything useful about how close a caregiver actually is.
 */
export function zoomForRadius(radiusKm: number, widthPx: number, lat: number): number {
  const metersPerPixelAtZoom0 = 156543.03392 * Math.cos((lat * Math.PI) / 180);
  const targetMetersPerPixel = (radiusKm * 2 * 1000) / widthPx;
  const zoom = Math.log2(metersPerPixelAtZoom0 / targetMetersPerPixel);
  return Math.max(12, Math.min(17, Math.round(zoom)));
}
