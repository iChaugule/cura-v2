/**
 * The emergency number to tell someone to call.
 *
 * Judged from where the person being cared for lives (their address), and only
 * falls back to the phone's region. When Cura cannot tell, it says "local
 * emergency services" rather than guessing a number.
 */
import { Platform, NativeModules } from 'react-native';

export interface EmergencyInfo {
  /** Short phrase for a sentence: "911", "112 (ambulance 108)", "your local emergency number". */
  label: string;
  country: string;
}

const RULES: { test: RegExp; label: string; country: string }[] = [
  { test: /\b(india|pune|mumbai|delhi|bengaluru|bangalore|chennai|hyderabad|kolkata|maharashtra|karnataka|tamil nadu|gujarat|kerala)\b/i, label: '112 (ambulance 108)', country: 'India' },
  { test: /\b(united states|usa|u\.s\.a?\.?|california|texas|new york|florida|illinois|washington|massachusetts|virginia|georgia|ohio|michigan|arizona|colorado|new jersey|pennsylvania|north carolina)\b/i, label: '911', country: 'United States' },
  { test: /\b(canada|ontario|british columbia|alberta|quebec|toronto|vancouver)\b/i, label: '911', country: 'Canada' },
  { test: /\b(united kingdom|england|scotland|wales|northern ireland|london|manchester)\b|\buk\b/i, label: '999 (or 112)', country: 'United Kingdom' },
  { test: /\b(australia|sydney|melbourne|brisbane|perth)\b/i, label: '000', country: 'Australia' },
  { test: /\b(new zealand|auckland|wellington)\b/i, label: '111', country: 'New Zealand' },
  { test: /\b(germany|france|spain|italy|netherlands|ireland|portugal|austria|belgium|sweden|poland)\b/i, label: '112', country: 'Europe' },
];

const BY_REGION: Record<string, string> = {
  IN: '112 (ambulance 108)', US: '911', CA: '911', GB: '999 (or 112)', AU: '000', NZ: '111',
  DE: '112', FR: '112', ES: '112', IT: '112', NL: '112', IE: '112',
};

function deviceRegion(): string | undefined {
  try {
    const loc = Intl.DateTimeFormat().resolvedOptions().locale;
    const fromIntl = loc.split('-')[1];
    if (fromIntl) return fromIntl.toUpperCase();
    const native = Platform.OS === 'ios'
      ? NativeModules.SettingsManager?.settings?.AppleLocale ?? NativeModules.SettingsManager?.settings?.AppleLanguages?.[0]
      : NativeModules.I18nManager?.localeIdentifier;
    return typeof native === 'string' ? native.split(/[-_]/)[1]?.toUpperCase() : undefined;
  } catch {
    return undefined;
  }
}

export function emergencyNumber(address?: string | null): EmergencyInfo {
  if (address) {
    const hit = RULES.find(r => r.test.test(address));
    if (hit) return { label: hit.label, country: hit.country };
  }
  const region = deviceRegion();
  if (region && BY_REGION[region]) return { label: BY_REGION[region], country: region };
  return { label: 'your local emergency number', country: '' };
}
