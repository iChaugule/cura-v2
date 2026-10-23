/**
 * Caregiver search.
 *
 * Live: real caregivers who signed up on Cura, who work near the loved one's
 * address and have said they will travel that far. Sorted by real distance.
 * Demo: sample profiles placed around the address, clearly labelled as samples.
 */
import { useCallback, useEffect, useMemo, useState } from 'react';
import { View, Text, StyleSheet, ScrollView, Pressable } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { ScreenHeader } from '../../src/components/ScreenHeader';
import { CareMap } from '../../src/components/CareMap';
import { Avatar, Button, Chip, EmptyState, Pill } from '../../src/components/ui';
import { Colors, Radius, Spacing, Type } from '../../src/design/tokens';
import { ALL_SPECIALTIES } from '../../src/data/caregivers';
import { Skeleton } from '../../src/components/Skeleton';
import { LocalProviders } from '../../src/components/LocalProviders';
import { KIND_LABEL, type CareProvider } from '../../src/lib/careProviders';
import { friendlyDbError } from '../../src/backend/remote';
import type { CaregiverProfile } from '../../src/models/types';
import { formatDistance } from '../../src/lib/geo';
import { rupees } from '../../src/lib/format';
import { useApp } from '../../src/state/AppContext';

type SortKey = 'distance' | 'rating' | 'price';

export default function FindCare() {
  const { state, searchCaregivers, addNote } = useApp();
  const pnc = state.pnc;
  const [providers, setProviders] = useState<CareProvider[]>([]);

  const shareProvider = useCallback((p: CareProvider) => {
    const lines = [
      `${KIND_LABEL[p.kind]}, ${formatDistance(p.distanceKm)}.`,
      p.address ? `Address: ${p.address}` : null,
      p.phone ? `Phone: ${p.phone}` : null,
      p.website ? `Website: ${p.website}` : null,
      p.email ? `Email: ${p.email}` : null,
      'Found on OpenStreetMap through Cura. Not yet contacted.',
    ].filter(Boolean);
    addNote({ category: 'general', trend: 'same', title: `Possible care provider: ${p.name}`, body: lines.join('\n') });
  }, [addNote]);

  const [selected, setSelected] = useState<string | null>(null);
  const [specialty, setSpecialty] = useState<string | null>(null);
  const [sort, setSort] = useState<SortKey>('distance');

  const [all, setAll] = useState<CaregiverProfile[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setAll(await searchCaregivers());
    } catch (err) {
      setError(friendlyDbError(err));
      setAll([]);
    }
  }, [searchCaregivers]);

  useEffect(() => { load(); }, [load, pnc?.location.lat, pnc?.location.lng]);

  const results = useMemo(() => {
    const list = all ?? [];
    const filtered = specialty
      ? list.filter(c => c.specialties.includes(specialty))
      : list;
    const sorted = [...filtered];
    if (sort === 'rating') sorted.sort((a, b) => b.rating - a.rating);
    else if (sort === 'price') sorted.sort((a, b) => a.hourlyRate - b.hourlyRate);
    else sorted.sort((a, b) => (a.distanceKm ?? 0) - (b.distanceKm ?? 0));
    return sorted;
  }, [all, specialty, sort]);

  if (!pnc) {
    return (
      <SafeAreaView style={s.safe} edges={['top']}>
        <ScreenHeader title="Find care" />
        <EmptyState
          icon="location-outline"
          title="No address yet"
          body="Add the address of the person needing care first."
          action="Go back"
          onAction={() => router.back()}
        />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={s.safe} edges={['top']}>
      <ScreenHeader
        title={`Care near ${pnc.preferredName}`}
        subtitle={pnc.address.split(',').slice(0, 2).join(', ')}
        step={3}
        totalSteps={4}
      />

      <ScrollView contentContainerStyle={s.scroll} showsVerticalScrollIndicator={false}>
        <View style={{ paddingHorizontal: Spacing.md, paddingTop: Spacing.md }}>
          <CareMap
            center={pnc.location}
            centerLabel={pnc.address}
            pins={[
              ...results.map(c => ({
                id: c.id,
                point: c.location,
                label: `${c.name}, ${formatDistance(c.distanceKm ?? 0)}`,
                initials: c.photoInitials,
              })),
              ...providers.slice(0, 25).map(p => ({
                id: p.id,
                point: p.location,
                label: `${p.name}, ${formatDistance(p.distanceKm)}`,
                initials: p.name.replace(/[^A-Za-z ]/g, '').split(' ').filter(Boolean).slice(0, 2).map(w => w[0].toUpperCase()).join(''),
              })),
            ]}
            selectedId={selected}
            onSelectPin={id => setSelected(id === selected ? null : id)}
            height={230}
          />
          <View style={s.legend}>
            <View style={s.legendItem}>
              <View style={s.legendHome} />
              <Text style={s.legendText}>{pnc.preferredName}&apos;s home</Text>
            </View>
            <View style={s.legendItem}>
              <View style={s.legendPin} />
              <Text style={s.legendText}>
                {results.length ? `${results.length} on Cura, ` : ''}{providers.length} care provider{providers.length === 1 ? '' : 's'} nearby
              </Text>
            </View>
          </View>
        </View>

        {state.live ? (
        <>
        <Text style={s.sectionTitle}>Caregivers on Cura</Text>
        <Text style={s.sectionSub}>
          People who signed up on Cura and travel to {pnc.preferredName}&apos;s area. Send a request and they answer on
          their phone.
        </Text>
        {(all?.length ?? 0) > 1 ? (
        <View style={s.filters}>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={s.filterRow}>
            <Chip
              label={sort === 'distance' ? 'Nearest first' : sort === 'rating' ? 'Highest rated' : 'Lowest price'}
              selected
              onPress={() => setSort(sort === 'distance' ? 'rating' : sort === 'rating' ? 'price' : 'distance')}
            />
            {specialty ? (
              <Chip label={specialty} icon="close" selected onPress={() => setSpecialty(null)} />
            ) : (
              ALL_SPECIALTIES.slice(0, 8).map(sp => (
                <Chip key={sp} label={sp} onPress={() => setSpecialty(sp)} />
              ))
            )}
          </ScrollView>
        </View>
        ) : null}

        <View style={s.list}>
          {all === null ? (
            [0, 1, 2].map(i => (
              <View key={i} style={[s.card, { flexDirection: 'row', gap: 12, alignItems: 'center' }]}>
                <Skeleton width={48} height={48} style={{ borderRadius: 24 }} />
                <View style={{ flex: 1, gap: 8 }}>
                  <Skeleton width="55%" height={14} />
                  <Skeleton width="80%" height={11} />
                  <Skeleton width="40%" height={11} />
                </View>
              </View>
            ))
          ) : error ? (
            <EmptyState
              icon="cloud-offline-outline"
              title="Could not search right now"
              body={error}
              action="Try again"
              onAction={load}
            />
          ) : all.length === 0 ? (
            <View style={s.card}>
              <Text style={s.name}>No one on Cura nearby yet</Text>
              <Text style={s.bio}>
                Nobody who works within travelling distance has joined Cura so far. The care providers below are real and
                you can contact them today. A caregiver you trust can also download Cura and sign up, and they will appear here.
              </Text>
            </View>
          ) : results.length === 0 ? (
            <EmptyState
              icon="search-outline"
              title="No caregivers match"
              body="Try clearing the filter to see everyone in the area."
              action="Clear filter"
              onAction={() => setSpecialty(null)}
            />
          ) : (
            results.map(c => {
              const open = selected === c.id;
              return (
                <View
                  key={c.id}
                  style={[s.card, open && { borderColor: Colors.brown, borderWidth: 2 }]}
                >
                  {/*
                    Only the header toggles. Wrapping the whole card would nest
                    the "Request" button inside a button, which is invalid HTML
                    on web.
                  */}
                  <Pressable
                    onPress={() => setSelected(open ? null : c.id)}
                    accessibilityRole="button"
                    accessibilityLabel={`${c.name}, ${c.headline}`}
                    accessibilityState={{ expanded: open }}
                    style={({ pressed }) => [s.cardHead, pressed && { opacity: 0.7 }]}
                  >
                    <Avatar initials={c.photoInitials} size={48} />
                    <View style={{ flex: 1, gap: 2 }}>
                      <View style={s.nameRow}>
                        <Text style={s.name}>{c.name}</Text>
                        {c.reviewCount > 0 ? (
                          <View style={s.ratingRow}>
                            <Ionicons name="star" size={12} color={Colors.caution} />
                            <Text style={s.rating}>{c.rating.toFixed(1)}</Text>
                            <Text style={s.reviews}>({c.reviewCount})</Text>
                          </View>
                        ) : (
                          <Text style={s.reviews}>New on Cura</Text>
                        )}
                      </View>
                      <Text style={s.headline} numberOfLines={open ? undefined : 1}>{c.headline}</Text>
                      <View style={s.metaRow}>
                        <Text style={s.meta}>{formatDistance(c.distanceKm ?? 0)}</Text>
                        <Text style={s.dot}>·</Text>
                        <Text style={s.meta}>{c.yearsExperience} yrs</Text>
                        <Text style={s.dot}>·</Text>
                        <Text style={s.rate}>{rupees(c.hourlyRate)}/hr</Text>
                      </View>
                    </View>
                  </Pressable>

                  {open ? (
                    <View style={s.expanded}>
                      <Text style={s.bio}>{c.bio}</Text>

                      <View style={s.chipWrap}>
                        {c.specialties.map(sp => (
                          <Chip key={sp} label={sp} />
                        ))}
                      </View>

                      <View style={s.factRow}>
                        <Fact label="Speaks" text={c.languages.join(', ')} />
                        <Fact label="Travel" text={c.respondsIn} />
                        <Fact label="Status" text={c.availability} />
                      </View>

                      <View style={s.badges}>
                        {c.certifications.length === 0 ? (
                          <Text style={s.reviews}>No verified documents yet. Ask for references before booking.</Text>
                        ) : null}
                        {c.certifications.map(cert => (
                          <View key={cert} style={s.badge}>
                            <Text style={s.badgeText}>{cert}</Text>
                          </View>
                        ))}
                      </View>

                      <Button
                        label={`Request ${c.name.split(' ')[0]}`}
                        icon="paper-plane-outline"
                        onPress={() => router.push({ pathname: '/(onboard)/invite', params: { id: c.id } })}
                      />
                    </View>
                  ) : (
                    <View style={s.collapsedFooter}>
                      <Pill
                        label={c.availability}
                        tone={
                          c.availability.toLowerCase().includes('now')
                            ? { fg: Colors.positive, bg: Colors.positiveSoft }
                            : { fg: Colors.textSecondary, bg: Colors.surfaceTinted }
                        }
                      />
                      <Text style={s.tapHint}>Tap for details</Text>
                    </View>
                  )}
                </View>
              );
            })
          )}
        </View>
        </>
        ) : null}

        <Text style={s.sectionTitle}>Care providers near {pnc.preferredName}</Text>
        <Text style={s.sectionSub}>
          Real home-care agencies, nursing homes and assisted living from OpenStreetMap. Call, email or get directions
          right from here.
        </Text>
        <View style={s.list}>
          <LocalProviders pnc={pnc} onShare={state.circleId || state.demoMode ? shareProvider : undefined} onResults={setProviders} />
        </View>

        <View style={[s.list, { marginTop: Spacing.lg }]}>
          <Button label="Continue to Cura" variant="secondary" onPress={() => router.replace('/(tabs)')} />
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

function Fact({ label, text }: { label: string; text: string }) {
  return (
    <View style={s.fact}>
      <Text style={s.factLabel}>{label}</Text>
      <Text style={s.factText} numberOfLines={1}>{text}</Text>
    </View>
  );
}

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { paddingBottom: Spacing.xl },

  legend: { flexDirection: 'row', gap: Spacing.md, marginTop: 8, paddingHorizontal: 2 },
  legendItem: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  legendHome: { width: 10, height: 10, borderRadius: 5, backgroundColor: Colors.textStrong },
  legendPin: { width: 10, height: 10, borderRadius: 5, borderWidth: 2, borderColor: Colors.brown, backgroundColor: Colors.surface },
  legendText: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },

  filters: { paddingVertical: Spacing.md },
  filterRow: { gap: Spacing.sm, paddingHorizontal: Spacing.md },

  list: { paddingHorizontal: Spacing.md, gap: Spacing.sm },
  card: {
    backgroundColor: Colors.surface, borderRadius: Radius.xl,
    borderWidth: 1, borderColor: Colors.separator, padding: Spacing.md, gap: 10,
  },
  cardHead: { flexDirection: 'row', gap: 12, alignItems: 'center' },
  nameRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 8 },
  name: { ...Type.subhead, color: Colors.textStrong, flex: 1 },
  ratingRow: { flexDirection: 'row', alignItems: 'center', gap: 2 },
  rating: { ...Type.caption, color: Colors.textStrong, fontWeight: '700' },
  reviews: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400' },
  headline: { ...Type.caption, color: Colors.textPrimary, fontWeight: '500' },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: 5, marginTop: 2 },
  meta: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  dot: { color: Colors.textTertiary, fontSize: 12 },
  rate: { ...Type.caption, color: Colors.textStrong, fontWeight: '700' },

  collapsedFooter: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  tapHint: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400' },

  expanded: { gap: 12, paddingTop: 4 },
  bio: { ...Type.body, fontSize: 14, color: Colors.textPrimary, lineHeight: 21 },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
  factRow: { gap: 6 },
  fact: { flexDirection: 'row', alignItems: 'center', gap: 7 },
  factLabel: { ...Type.caption, color: Colors.textTertiary, width: 52 },
  factText: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', flex: 1 },
  badges: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
  badge: {
    flexDirection: 'row', alignItems: 'center', gap: 4,
    backgroundColor: Colors.positiveSoft, paddingHorizontal: 8, paddingVertical: 4,
    borderRadius: Radius.pill,
  },
  sectionTitle: { fontFamily: 'Fraunces_600SemiBold', fontSize: 19, color: Colors.textStrong, paddingHorizontal: Spacing.md, marginTop: Spacing.lg },
  sectionSub: { ...Type.callout, fontWeight: '400', color: Colors.textSecondary, paddingHorizontal: Spacing.md, marginTop: 4, marginBottom: Spacing.sm },
  sampleNote: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', marginBottom: 2 },
  badgeText: { fontSize: 11, color: Colors.positive, fontWeight: '600' },
});
