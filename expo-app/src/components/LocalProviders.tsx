/**
 * Real care providers near the loved one, from OpenStreetMap, with the
 * contact details that are on the map. Every action here does something real:
 * calls the number, opens the website, starts an email, opens directions, or
 * shares the provider with the whole care circle as a note.
 */
import { useCallback, useEffect, useRef, useState } from 'react';
import { View, Text, StyleSheet, Pressable, Linking } from 'react-native';
import { Colors, Radius, Spacing, Type } from '../design/tokens';
import {
  KIND_LABEL, directionsUrl, mapsSearchUrl, searchCareProviders, telUrl, type CareProvider,
} from '../lib/careProviders';
import { formatDistance } from '../lib/geo';
import type { Pnc } from '../models/types';
import { Skeleton } from './Skeleton';

const RADII = [5, 15, 30, 50];

export function LocalProviders({
  pnc, onShare, onResults,
}: {
  pnc: Pnc;
  /** Post this provider to the care circle so every relative sees it. */
  onShare?: (p: CareProvider) => void;
  onResults?: (list: CareProvider[]) => void;
}) {
  const [radius, setRadius] = useState(15);
  const [list, setList] = useState<CareProvider[]>([]);
  const [done, setDone] = useState(false);
  const [open, setOpen] = useState<string | null>(null);
  const [shared, setShared] = useState<Record<string, boolean>>({});
  const results = useRef(onResults);
  results.current = onResults;

  useEffect(() => {
    const ctl = new AbortController();
    setList([]);
    setDone(false);
    searchCareProviders(pnc.location, radius, l => { setList(l); results.current?.(l); }, ctl.signal)
      .then(l => { if (!ctl.signal.aborted) { setList(l); results.current?.(l); } })
      .catch(() => {})
      .finally(() => { if (!ctl.signal.aborted) setDone(true); });
    return () => ctl.abort();
  }, [pnc.location.lat, pnc.location.lng, radius]);

  const area = pnc.address.split(',').slice(0, 3).join(',');
  const share = useCallback((p: CareProvider) => {
    onShare?.(p);
    setShared(s => ({ ...s, [p.id]: true }));
  }, [onShare]);

  return (
    <View style={{ gap: Spacing.sm }}>
      <View style={s.radiusRow} accessibilityRole="radiogroup" accessibilityLabel="Search distance">
        <Text style={s.radiusLabel}>Within</Text>
        {RADII.map(r => (
          <Pressable
            key={r}
            onPress={() => setRadius(r)}
            accessibilityRole="radio"
            accessibilityState={{ selected: radius === r }}
            style={[s.radius, radius === r && s.radiusOn]}
          >
            <Text style={[s.radiusText, radius === r && s.radiusTextOn]}>{r} km</Text>
          </Pressable>
        ))}
      </View>

      {list.length === 0 && !done ? (
        <>
          <Text style={s.searching}>Searching the map around {pnc.preferredName}&apos;s home</Text>
          {[0, 1, 2].map(i => (
            <View key={i} style={[s.card, { gap: 8 }]}>
              <Skeleton width="60%" height={15} />
              <Skeleton width="35%" height={11} />
              <Skeleton width="80%" height={11} />
            </View>
          ))}
        </>
      ) : null}

      {list.length === 0 && done ? (
        <View style={s.card}>
          <Text style={s.emptyTitle}>Nothing mapped within {radius} km yet</Text>
          <Text style={s.body}>
            OpenStreetMap does not list any care homes or home-care agencies this close to {area}. Try a wider
            distance, or search Google Maps for the area, which lists more small agencies.
          </Text>
          <View style={s.actions}>
            {radius < 50 ? (
              <Action label={`Try ${RADII[RADII.indexOf(radius) + 1]} km`} onPress={() => setRadius(RADII[RADII.indexOf(radius) + 1])} primary />
            ) : null}
            <Action label="Search Google Maps" onPress={() => Linking.openURL(mapsSearchUrl(area))} />
          </View>
        </View>
      ) : null}

      {list.map(p => {
        const expanded = open === p.id;
        return (
          <View key={p.id} style={s.card}>
            <Pressable
              onPress={() => setOpen(expanded ? null : p.id)}
              accessibilityRole="button"
              accessibilityState={{ expanded }}
              accessibilityLabel={`${p.name}, ${KIND_LABEL[p.kind]}, ${formatDistance(p.distanceKm)}`}
              style={{ gap: 3 }}
            >
              <View style={s.head}>
                <Text style={s.name}>{p.name}</Text>
                <Text style={s.distance}>{formatDistance(p.distanceKm)}</Text>
              </View>
              <Text style={s.kind}>
                {KIND_LABEL[p.kind]}
                {p.mentionsDementia ? ' · mentions dementia care' : p.forSeniors ? ' · for older adults' : ''}
              </Text>
              {p.address ? <Text style={s.body} numberOfLines={expanded ? undefined : 1}>{p.address}</Text> : null}
            </Pressable>

            {expanded && p.openingHours ? <Text style={s.meta}>Hours: {p.openingHours}</Text> : null}
            {expanded && !p.phone && !p.website && !p.email ? (
              <Text style={s.meta}>No phone or website is listed on the map for this place. Directions still work.</Text>
            ) : null}

            <View style={s.actions}>
              {p.phone ? <Action label="Call" onPress={() => Linking.openURL(telUrl(p.phone!))} primary /> : null}
              {p.website ? <Action label="Website" onPress={() => Linking.openURL(p.website!)} /> : null}
              {p.email ? <Action label="Email" onPress={() => Linking.openURL(`mailto:${p.email}`)} /> : null}
              <Action label="Directions" onPress={() => Linking.openURL(directionsUrl(p))} />
              {onShare ? (
                <Action
                  label={shared[p.id] ? 'Shared with family' : 'Share with family'}
                  onPress={() => share(p)}
                  disabled={shared[p.id]}
                />
              ) : null}
            </View>
            {p.phone ? <Text style={s.phone} selectable>{p.phone}</Text> : null}
          </View>
        );
      })}

      {list.length > 0 && !done ? <Text style={s.searching}>Still searching, more may appear</Text> : null}

      <Text style={s.attribution}>
        Places and contact details from OpenStreetMap contributors. Cura has not checked these providers. Ask about
        dementia experience, licensing and references before arranging care.
      </Text>
    </View>
  );
}

function Action({ label, onPress, primary, disabled }: { label: string; onPress: () => void; primary?: boolean; disabled?: boolean }) {
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      accessibilityRole="button"
      style={({ pressed }) => [s.action, primary && s.actionPrimary, disabled && { opacity: 0.55 }, pressed && { opacity: 0.75 }]}
    >
      <Text style={[s.actionText, primary && { color: Colors.textOnBrown }]}>{label}</Text>
    </Pressable>
  );
}

const s = StyleSheet.create({
  radiusRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  radiusLabel: { ...Type.caption, color: Colors.textSecondary, marginRight: 2 },
  radius: { paddingHorizontal: 10, paddingVertical: 6, borderRadius: Radius.sm, backgroundColor: Colors.surfaceTinted },
  radiusOn: { backgroundColor: Colors.textStrong },
  radiusText: { ...Type.caption, color: Colors.textStrong, fontWeight: '700' },
  radiusTextOn: { color: Colors.textOnBrown },
  searching: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  card: {
    backgroundColor: Colors.surface, borderRadius: Radius.lg, padding: Spacing.md, gap: 8,
    borderWidth: StyleSheet.hairlineWidth * 2, borderColor: Colors.separator,
  },
  head: { flexDirection: 'row', justifyContent: 'space-between', gap: 10 },
  name: { ...Type.subhead, color: Colors.textStrong, flex: 1 },
  distance: { ...Type.caption, color: Colors.textSecondary, fontWeight: '600' },
  kind: { ...Type.caption, color: Colors.brown, fontWeight: '700' },
  body: { ...Type.callout, color: Colors.textPrimary, fontWeight: '400' },
  meta: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  phone: { ...Type.caption, color: Colors.textSecondary, fontVariant: ['tabular-nums'] },
  actions: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginTop: 2 },
  action: {
    paddingHorizontal: 12, paddingVertical: 8, borderRadius: Radius.sm,
    borderWidth: 1, borderColor: Colors.border, backgroundColor: Colors.surfaceRaised,
  },
  actionPrimary: { backgroundColor: Colors.brown, borderColor: Colors.brown },
  actionText: { ...Type.caption, fontSize: 13, color: Colors.brown, fontWeight: '700' },
  emptyTitle: { ...Type.subhead, color: Colors.textStrong },
  attribution: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400', lineHeight: 17, marginTop: 4 },
});
