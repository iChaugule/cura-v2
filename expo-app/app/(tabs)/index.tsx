/**
 * Home. One screen, two jobs.
 *
 * Family: how are they today, what has changed, and who is looking after them.
 * Caregiver: do today's check-in, what to watch for, and what helps this person.
 *
 * Everything on the "how are they" side comes from the pattern engine, so it is
 * instant, works offline and gives the same answer for the same data.
 */
import { useMemo, useState } from 'react';
import { View, Text, StyleSheet, ScrollView, Pressable, RefreshControl } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Avatar, Banner, Button, Card, Pill } from '../../src/components/ui';
import { Colors, Radius, Spacing, Type } from '../../src/design/tokens';
import { isSameDay, observationShort, redFlagLabel } from '../../src/data/quiz';
import { greeting, initials, relativeTime } from '../../src/lib/format';
import { useApp } from '../../src/state/AppContext';
import { analyze } from '../../src/engine/patterns';
import { FindingList, StatusLabel } from '../../src/components/Findings';
import { DayStrip } from '../../src/components/DayStrip';
import { CircleCode } from '../../src/components/CircleCode';
import { QuickNote, RecentMessages, TodaySchedule, useAuthorLang } from '../../src/components/HomeBlocks';
import { useTranslated } from '../../src/lib/useTranslated';
import { languageLabel } from '../../src/ai/cura';

export default function Home() {
  const { state, me, them, activeInvite, pendingInvites, refresh, clearSyncError } = useApp();
  const pnc = state.pnc;
  const isFamily = state.activeRole === 'family';
  const [showAll, setShowAll] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const report = useMemo(() => analyze(state.quizzes), [state.quizzes]);
  const latest = state.quizzes[0];
  const doneToday = latest ? isSameDay(latest.submittedAt, Date.now()) : false;

  if (!pnc || !me) return null;

  const name = pnc.preferredName;
  const status = StatusLabel[report.status];
  // The town: the last part of the address, without a postcode or country.
  const parts = pnc.address.split(',').map(p => p.replace(/\d{4,}/g, '').trim()).filter(Boolean);
  const city = (parts.length > 2 && /india|united states|usa|united kingdom/i.test(parts[parts.length - 1]) ? parts[parts.length - 3] : parts[parts.length - 1]) ?? '';
  const latestNote = state.notes[0];
  const caregiver = isFamily ? them : me;
  // Live accounts list real members. Offline (and in the demo) the two accounts stand in for them.
  const offline = state.members.length === 0;
  const family = offline
    ? (state.familyAccount ? [state.familyAccount] : [])
    : state.members.filter(m => m.role === 'family');
  const caregivers = offline
    ? (state.caregiverAccount && activeInvite?.status === 'accepted' ? [state.caregiverAccount] : [])
    : state.members.filter(m => m.role === 'caregiver');

  const onRefresh = async () => {
    setRefreshing(true);
    await refresh().catch(() => {});
    setRefreshing(false);
  };

  const findingsSection = (title: string) => (
    <>
      <Section
        title={title}
        action={report.findings.length > 2 ? (showAll ? 'Show less' : `See all ${report.findings.length}`) : undefined}
        onAction={() => setShowAll(v => !v)}
      />
      <FindingList report={report} name={name} limit={showAll ? undefined : 2} />
    </>
  );

  return (
    <ScrollView
      style={s.screen}
      contentContainerStyle={s.scroll}
      showsVerticalScrollIndicator={false}
      refreshControl={state.live ? <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.brown} /> : undefined}
    >
      <View style={s.greet}>
        <Text style={s.greeting}>{greeting()}, {me.name.split(' ')[0]}</Text>
        <Text style={s.greetSub}>
          {isFamily ? `${name}${city ? ` in ${city}` : ''}` : `Caring for ${name} today`}
        </Text>
      </View>

      {state.syncError ? (
        <Banner tone="urgent" title={state.syncError} action="Dismiss" onAction={clearSyncError} />
      ) : null}

      {!isFamily && pendingInvites.length > 0 ? (
        <Banner
          tone="caution"
          title={`${pendingInvites.length} new care request${pendingInvites.length > 1 ? 's' : ''}`}
          body="A family is waiting for your answer."
          action="Open"
          onAction={() => router.push('/(onboard)/invites')}
        />
      ) : null}

      {isFamily ? (
        <>
          {/* ── How they are ───────────────────────────── */}
          <Card raised style={s.status}>
            <View style={s.statusTop}>
              <Text style={s.overline}>HOW {name.toUpperCase()} IS DOING</Text>
              {latest ? <Pill label={status.label} tone={status} /> : null}
            </View>
            <Text style={s.headline}>
              {latest ? report.headline : `No check-ins yet. The first one starts ${name}'s history.`}
            </Text>
            <DayStrip quizzes={state.quizzes} />
            <View style={s.statusFoot}>
              <Text style={s.footText}>
                {doneToday && latest
                  ? `Today's check-in by ${latest.submittedByName.split(' ')[0]}, ${relativeTime(latest.submittedAt)}`
                  : caregiver
                    ? `Waiting for today's check-in from ${caregiver.name.split(' ')[0]}`
                    : 'No check-in today'}
              </Text>
              {doneToday && latest ? (
                <Pressable onPress={() => router.push({ pathname: '/checkin/[id]', params: { id: latest.id } })} hitSlop={8} accessibilityRole="link">
                  <Text style={s.link}>View</Text>
                </Pressable>
              ) : null}
            </View>
          </Card>

          {findingsSection('What changed')}

          <TodaySchedule />

          <Section title="Latest note" action="All notes" onAction={() => router.push('/(tabs)/notes')} />
          <NoteCard note={latestNote} empty={`No notes yet. ${caregiver?.name.split(' ')[0] ?? 'The caregiver'} can add one after each visit.`} />

          <RecentMessages />

          {/* ── Who is in the circle ───────────────────── */}
          <Section title="Care circle" />
          <Card style={{ gap: 12 }}>
            {caregivers.length > 0 ? (
              caregivers.map(c => (
                <Person
                  key={c.id}
                  name={c.name}
                  meta={activeInvite && c.id === caregiver?.id ? activeInvite.scheduleSummary : 'Caregiver'}
                  tone={Colors.brown}
                  onMessage={() => router.push('/(tabs)/messages')}
                />
              ))
            ) : (
              <>
                <Text style={s.body}>No caregiver yet. Find one who works near {name}, or give them the circle code below.</Text>
                <Button label="Find care nearby" variant="secondary" size="sm" onPress={() => router.push('/(onboard)/find-care')} />
              </>
            )}
            {family.length > 1 ? (
              <Text style={s.meta}>
                Family in this circle: {family.map(f => f.id === me.id ? 'you' : f.name.split(' ')[0]).join(', ')}
              </Text>
            ) : null}
          </Card>

          {state.joinCode ? (
            <>
              <Section title="Add to the circle" />
              <Card><CircleCode code={state.joinCode} name={name} sample={!state.live} /></Card>
            </>
          ) : null}
        </>
      ) : (
        <>
          {/* ── Today's check-in, front and centre ─────── */}
          {doneToday && latest ? (
            <Card raised style={s.doneCard}>
              <View style={s.statusTop}>
                <Text style={[s.overline, { color: Colors.positive }]}>TODAY&apos;S CHECK-IN IS DONE</Text>
                <Pressable onPress={() => router.push('/quiz')} hitSlop={8} accessibilityRole="button">
                  <Text style={s.link}>Add another</Text>
                </Pressable>
              </View>
              <Text style={s.headline}>Saved {relativeTime(latest.submittedAt)}. The family can see it.</Text>
              {latest.redFlags?.length ? (
                <Text style={[s.body, { color: Colors.urgent }]}>
                  Flagged: {latest.redFlags.map(redFlagLabel).join('; ')}
                </Text>
              ) : null}
              {latest.observed?.length ? (
                <Text style={s.meta}>Also noted: {latest.observed.map(observationShort).join(', ')}</Text>
              ) : null}
            </Card>
          ) : (
            <Pressable onPress={() => router.push('/quiz')} accessibilityRole="button" accessibilityLabel="Start today's check-in">
              {({ pressed }) => (
                <View style={[s.cta, pressed && { opacity: 0.92 }]}>
                  <Text style={s.ctaOverline}>TODAY&apos;S CHECK-IN</Text>
                  <Text style={s.ctaTitle}>How was {name} today?</Text>
                  <Text style={s.ctaBody}>
                    Six short steps, about three minutes. It starts with a quick safety check, and the family sees it
                    the moment you save.
                  </Text>
                  <View style={s.ctaButton}>
                    <Text style={s.ctaButtonText}>Start check-in</Text>
                  </View>
                </View>
              )}
            </Pressable>
          )}

          <TodaySchedule />

          <QuickNote name={name} />

          <RecentMessages />

          {findingsSection('Watch today')}

          {/* ── What helps this person ─────────────────── */}
          <Section title={`What helps ${name}`} action="Full profile" onAction={() => router.push('/(tabs)/profile')} />
          <Card style={{ gap: 12 }}>
            <Fact label="When upset" text={pnc.calmingNotes} />
            <View style={s.hr} />
            <Fact label="Usual day" text={pnc.routine} />
          </Card>

          <Section title="Family" />
          <Card style={{ gap: 12 }}>
            {family.length > 0 ? (
              family.map(f => (
                <Person
                  key={f.id}
                  name={f.name}
                  meta={`${f.relationship ?? 'Family'} of ${name}`}
                  tone={Colors.textStrong}
                  onMessage={() => router.push('/(tabs)/messages')}
                />
              ))
            ) : (
              <Text style={s.body}>The family has not joined yet.</Text>
            )}
          </Card>

          {state.joinCode ? (
            <>
              <Section title="Add to the circle" />
              <Card><CircleCode code={state.joinCode} name={name} sample={!state.live} /></Card>
            </>
          ) : null}
        </>
      )}

      <View style={{ height: Spacing.xl }} />
    </ScrollView>
  );
}

function Section({ title, action, onAction }: { title: string; action?: string; onAction?: () => void }) {
  return (
    <View style={s.section}>
      <Text style={s.sectionTitle} accessibilityRole="header">{title}</Text>
      {action ? (
        <Pressable onPress={onAction} hitSlop={8} accessibilityRole="button">
          <Text style={s.link}>{action}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

function Person({ name, meta, tone, onMessage }: { name: string; meta: string; tone: string; onMessage: () => void }) {
  return (
    <View style={s.person}>
      <Avatar initials={initials(name)} size={40} tone={tone} />
      <View style={{ flex: 1 }}>
        <Text style={s.personName}>{name}</Text>
        <Text style={s.meta} numberOfLines={1}>{meta}</Text>
      </View>
      <Pressable onPress={onMessage} style={s.msgBtn} accessibilityRole="button" accessibilityLabel={`Message ${name}`}>
        <Ionicons name="chatbubble-outline" size={15} color={Colors.brown} />
        <Text style={s.msgText}>Message</Text>
      </Pressable>
    </View>
  );
}

function Fact({ label, text }: { label: string; text: string }) {
  return (
    <View style={{ gap: 3 }}>
      <Text style={s.factLabel}>{label}</Text>
      <Text style={s.body} numberOfLines={3}>{text}</Text>
    </View>
  );
}

function NoteCard({ note, empty }: {
  note?: { id: string; title: string; body: string; authorId: string; authorRole: 'family' | 'caregiver'; authorName: string; createdAt: number };
  empty: string;
}) {
  const { me } = useApp();
  const authorLang = useAuthorLang();
  const src = note ? authorLang(note.authorId, note.authorRole) : undefined;
  const title = useTranslated(note?.title ?? '', src, me?.language);
  const body = useTranslated(note?.body ?? '', src, me?.language);
  if (!note) return <Card><Text style={s.body}>{empty}</Text></Card>;
  return (
    <Pressable onPress={() => router.push('/(tabs)/notes')} accessibilityRole="button">
      {({ pressed }) => (
        <Card style={[{ gap: 4 }, pressed && { opacity: 0.9 }]}>
          <Text style={s.noteTitle}>{title.text}</Text>
          <Text style={s.body} numberOfLines={2}>{body.text}</Text>
          <Text style={s.meta}>
            {note.authorName.split(' ')[0]} · {relativeTime(note.createdAt)}
            {title.translated || body.translated ? ` · Translated from ${languageLabel(src ?? '')}` : ''}
          </Text>
        </Card>
      )}
    </Pressable>
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { padding: Spacing.md, paddingTop: Spacing.sm, gap: Spacing.sm, maxWidth: 680, width: '100%', alignSelf: 'center' },

  greet: { paddingVertical: Spacing.sm, gap: 2 },
  greeting: { ...Type.title, color: Colors.textStrong },
  greetSub: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400' },

  status: { gap: 14 },
  statusTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 8 },
  overline: { ...Type.overline, fontSize: 10, color: Colors.textSecondary },
  headline: { ...Type.heading, fontSize: 21, lineHeight: 27, color: Colors.textStrong },
  statusFoot: {
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 8,
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator, paddingTop: 10,
  },
  footText: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', flex: 1 },
  link: { ...Type.caption, color: Colors.brown, fontWeight: '700' },

  section: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'baseline', marginTop: Spacing.md, paddingHorizontal: 2 },
  sectionTitle: { fontFamily: 'Fraunces_600SemiBold', fontSize: 18, color: Colors.textStrong },

  body: { ...Type.callout, color: Colors.textPrimary, fontWeight: '400', lineHeight: 20 },
  meta: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  hr: { height: StyleSheet.hairlineWidth, backgroundColor: Colors.separator },

  person: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  personName: { ...Type.subhead, color: Colors.textStrong },
  msgBtn: {
    flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 12, paddingVertical: 8,
    borderRadius: Radius.sm, borderWidth: 1, borderColor: Colors.border, backgroundColor: Colors.surfaceRaised,
  },
  msgText: { ...Type.caption, fontSize: 13, color: Colors.brown, fontWeight: '700' },

  factLabel: { ...Type.overline, fontSize: 10, color: Colors.textSecondary },
  noteTitle: { ...Type.subhead, color: Colors.textStrong },

  cta: {
    backgroundColor: Colors.brown, borderRadius: Radius.lg, padding: Spacing.lg, gap: 8,
    boxShadow: '0px 8px 20px rgba(110, 58, 38, 0.18)',
  },
  ctaOverline: { ...Type.overline, fontSize: 10, color: '#F3D9C4' },
  ctaTitle: { fontFamily: 'Fraunces_700Bold', fontSize: 26, lineHeight: 31, color: Colors.textOnBrown },
  ctaBody: { ...Type.callout, color: '#F6E6D8', fontWeight: '400', lineHeight: 20 },
  ctaButton: {
    marginTop: 8, alignSelf: 'flex-start', backgroundColor: Colors.cream,
    paddingHorizontal: 18, paddingVertical: 12, borderRadius: Radius.md,
  },
  ctaButtonText: { ...Type.subhead, color: Colors.brown },
  doneCard: { gap: 10 },
});
