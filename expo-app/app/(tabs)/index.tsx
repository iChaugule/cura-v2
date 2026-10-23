/**
 * Home — where everything comes together.
 *
 * Family sees: how they are doing, what the caregiver wrote, what the messages
 * covered, the check-in trend, and who is on shift.
 * Caregiver sees: what the family said, the check-in history, what to watch
 * today, and a way straight into writing a note.
 */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, Pressable, RefreshControl,
} from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import {
  Avatar, Banner, Button, Card, Chip, Meter, Pill, SectionHeader,
} from '../../src/components/ui';
import { Colors, Radius, Spacing, TrendColors, Type } from '../../src/design/tokens';
import { buildDigest, type Digest } from '../../src/ai/cura';
import { friendlyError, GEMINI_API_KEY } from '../../src/ai/gemini';
import { isSameDay, scoreDelta, scoreLabel, scoreTone, weakestAreas, QUIZ_QUESTIONS } from '../../src/data/quiz';
import { dayLabel, greeting, initials, relativeTime, rupees } from '../../src/lib/format';
import { useApp, useCareContext } from '../../src/state/AppContext';
import { analyze } from '../../src/engine/patterns';
import { FindingList, StatusLabel } from '../../src/components/Findings';
import { Skeleton } from '../../src/components/Skeleton';

export default function Home() {
  const { state, me, them, activeInvite, pendingInvites } = useApp();
  const ctx = useCareContext();
  const pnc = state.pnc;
  const isFamily = state.activeRole === 'family';

  const [digest, setDigest] = useState<Digest | null>(null);
  const [digestError, setDigestError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const signature = useRef('');

  const latestQuiz = state.quizzes[0];
  const doneToday = latestQuiz ? isSameDay(latestQuiz.submittedAt, Date.now()) : false;
  const delta = scoreDelta(state.quizzes);
  // Deterministic, instant, and the same answer every time for the same data.
  const report = useMemo(() => analyze(state.quizzes), [state.quizzes]);

  const loadDigest = useCallback(async (force = false) => {
    const sig = [
      state.activeRole, state.notes.length, state.quizzes.length,
      state.messages.length, state.notes[0]?.id ?? '', state.quizzes[0]?.id ?? '',
    ].join('|');
    if (!force && sig === signature.current) return;
    if (!pnc) return;

    signature.current = sig;
    setLoading(true);
    setDigestError(null);
    try {
      setDigest(await buildDigest(ctx));
    } catch (err) {
      setDigestError(friendlyError(err));
    } finally {
      setLoading(false);
    }
  }, [ctx, pnc, state.activeRole, state.notes, state.quizzes, state.messages]);

  useEffect(() => { loadDigest(); }, [loadDigest]);

  if (!pnc || !me) return null;

  const statusTone = StatusLabel[report.status];
  const recentNotes = state.notes.slice(0, 2);
  const lastMessage = state.messages[state.messages.length - 1];
  const unreadFromThem = state.messages.filter(
    m => m.senderRole !== state.activeRole && Date.now() - m.createdAt < 12 * 3600_000,
  ).length;

  return (
    <ScrollView
      style={s.screen}
      contentContainerStyle={s.scroll}
      showsVerticalScrollIndicator={false}
      refreshControl={
        <RefreshControl refreshing={loading} onRefresh={() => loadDigest(true)} tintColor={Colors.brown} />
      }
    >
      {/* ── Greeting ─────────────────────────────────────── */}
      <View style={s.greetRow}>
        <View style={{ flex: 1 }}>
          <Text style={s.greeting}>{greeting()}, {me.name.split(' ')[0]}</Text>
          <Text style={s.greetSub}>
            {isFamily
              ? `Here's how ${pnc.preferredName} is doing`
              : `Your notes keep ${ctx.familyName?.split(' ')[0] ?? 'the family'} in the loop`}
          </Text>
        </View>
        <Avatar initials={initials(me.name)} size={42} />
      </View>

      {/* ── Caregiver: pending requests ───────────────────── */}
      {!isFamily && pendingInvites.length > 0 ? (
        <Banner
          icon="mail-unread-outline"
          tone="caution"
          title={`${pendingInvites.length} care request${pendingInvites.length > 1 ? 's' : ''} waiting`}
          body="A family is waiting on your answer."
          action="Open"
          onAction={() => router.push('/(onboard)/invites')}
        />
      ) : null}

      {/* ── The headline card ────────────────────────────── */}
      <Card style={s.heroCard} raised>
        <View style={s.heroTop}>
          <View style={{ flex: 1, gap: 3 }}>
            <Text style={s.heroLabel}>{pnc.preferredName.toUpperCase()} · TODAY</Text>
            <Text style={s.heroHeadline}>
              {latestQuiz ? report.headline : 'No check-ins yet. The first one starts the history.'}
            </Text>
          </View>
          {latestQuiz ? <Pill label={statusTone.label} tone={statusTone} /> : null}
        </View>

        {latestQuiz ? (
          <View style={s.scoreBlock}>
            <View style={s.scoreRow}>
              <Text style={s.scoreValue}>{latestQuiz.score}</Text>
              <Text style={s.scoreOutOf}>/100 wellbeing</Text>
              {delta !== null ? (
                <View style={s.deltaRow}>
                  <Ionicons
                    name={delta > 0 ? 'trending-up' : delta < 0 ? 'trending-down' : 'remove'}
                    size={14}
                    color={delta > 0 ? Colors.positive : delta < 0 ? Colors.caution : Colors.textTertiary}
                  />
                  <Text
                    style={[
                      s.deltaText,
                      { color: delta > 0 ? Colors.positive : delta < 0 ? Colors.caution : Colors.textTertiary },
                    ]}
                  >
                    {delta > 0 ? '+' : ''}{delta} since last
                  </Text>
                </View>
              ) : null}
            </View>
            <Meter value={latestQuiz.score} tone={scoreTone(latestQuiz.score).fg} />
            <Text style={s.scoreMeta}>
              Last check-in {relativeTime(latestQuiz.submittedAt)} by {latestQuiz.submittedByName.split(' ')[0]}
            </Text>
          </View>
        ) : null}

      </Card>

      {/* ── Daily check-in ───────────────────────────────── */}
      {doneToday && latestQuiz ? (
        <Card style={{ gap: 10 }}>
          <View style={s.rowBetween}>
            <View style={s.rowCenter}>
              <Text style={s.cardTitle}>Today&apos;s check-in is done</Text>
            </View>
            <Pressable onPress={() => router.push('/quiz')} hitSlop={8}>
              <Text style={s.link}>Redo</Text>
            </Pressable>
          </View>
          {weakestAreas(latestQuiz).length ? (
            <View style={s.weakList}>
              {weakestAreas(latestQuiz).map(({ question, answerIndex }) => (
                <View key={question.id} style={s.weakRow}>
                  <View style={[s.weakDot, { backgroundColor: answerIndex === 0 ? Colors.urgent : Colors.caution }]} />
                  <Text style={s.weakText}>
                    <Text style={{ fontWeight: '700' }}>{question.prompt.replace(/\?$/, '')}</Text>
                    {': '}{question.options[answerIndex].toLowerCase()}
                  </Text>
                </View>
              ))}
            </View>
          ) : (
            <Text style={s.bodyText}>Every answer was at its best today.</Text>
          )}
          {latestQuiz.aiInsight ? (
            <View style={s.insightBox}>
              <Text style={s.insightText}>{latestQuiz.aiInsight}</Text>
            </View>
          ) : null}
        </Card>
      ) : (
        <Pressable onPress={() => router.push('/quiz')}>
          {({ pressed }) => (
            <Card style={[s.quizCta, pressed && { opacity: 0.9 }]}>
              <View style={s.quizDate}>
                <Text style={s.quizDay}>{new Date().getDate()}</Text>
                <Text style={s.quizMonth}>{new Date().toLocaleDateString(undefined, { month: 'short' }).toUpperCase()}</Text>
              </View>
              <View style={{ flex: 1 }}>
                <Text style={s.quizTitle}>Today&apos;s check-in</Text>
                <Text style={s.quizSub}>
                  {QUIZ_QUESTIONS.length} quick questions on sleep, food, fluids and mood
                </Text>
              </View>
              <Text style={s.quizStart}>Start</Text>
            </Card>
          )}
        </Pressable>
      )}

      {/* ── What changed (pattern engine) ────────────────── */}
      <SectionHeader title="What changed" icon="analytics-outline" />
      <FindingList report={report} name={pnc.preferredName} />

      {/* ── AI digest sections ───────────────────────────── */}
      {loading && !digest ? (
        <>
          <SectionHeader title="This week in words" icon="reader-outline" />
          <Card style={{ gap: 10 }}>
            <Skeleton width="40%" height={11} />
            <Skeleton width="100%" />
            <Skeleton width="85%" />
            <Skeleton width="40%" height={11} style={{ marginTop: 8 }} />
            <Skeleton width="95%" />
          </Card>
        </>
      ) : null}
      {digestError && !digest ? (
        <Card>
          <Pressable onPress={() => loadDigest(true)} accessibilityRole="button">
            <Text style={s.errorText}>
              {GEMINI_API_KEY ? `The written summary could not load (${digestError.replace(/\.$/, '')}). Tap to try again.` : 'Written summaries are off because no Gemini key is set.'}
            </Text>
          </Pressable>
        </Card>
      ) : null}
      {digest ? (
        <>
          <SectionHeader title="This week in words" icon="reader-outline" action="Ask" onAction={() => router.push('/(tabs)/cura')} />
          <Card style={{ gap: 14 }}>
            <Summary icon="document-text-outline" label="Caregiver notes" text={digest.notesSummary} />
            <View style={s.hr} />
            <Summary icon="chatbubbles-outline" label="Messages" text={digest.messagesSummary} />
            <View style={s.hr} />
            <Summary icon="pulse-outline" label="Check-ins" text={digest.checkInSummary} />
            {digest.suggestions.length ? (
              <>
                <View style={s.hr} />
                <View style={{ gap: 8 }}>
                  <Text style={s.summaryLabel}>SUGGESTED NEXT</Text>
                  {digest.suggestions.map((sg, i) => (
                    <View key={i} style={s.suggestRow}>
                      <View style={s.suggestDot}><Text style={s.suggestNum}>{i + 1}</Text></View>
                      <Text style={s.suggestText}>{sg}</Text>
                    </View>
                  ))}
                </View>
              </>
            ) : null}
            <Text style={s.aiCaveat}>
              Written by AI from the notes and messages, checked against the findings above. It does not diagnose.
            </Text>
          </Card>
        </>
      ) : null}

      {/* ── The other person ─────────────────────────────── */}
      <SectionHeader
        title={isFamily ? 'Current caregiver' : 'Family contact'}
        icon={isFamily ? 'medkit-outline' : 'people-outline'}
      />
      {them ? (
        <Card style={s.personCard}>
          <Avatar
            initials={initials(them.name)}
            size={46}
            tone={isFamily ? Colors.brown : Colors.textStrong}
          />
          <View style={{ flex: 1, gap: 2 }}>
            <Text style={s.personName}>{them.name}</Text>
            {isFamily && activeInvite ? (
              <>
                <Text style={s.personMeta}>{activeInvite.scheduleSummary}</Text>
                <Text style={s.personMeta}>
                  {rupees(activeInvite.hourlyRate)}/hr · {rupees(activeInvite.payment.weeklyTotal)}/week
                </Text>
              </>
            ) : (
              <Text style={s.personMeta}>
                {state.familyAccount?.relationship ?? 'Family'} of {pnc.preferredName}
              </Text>
            )}
          </View>
          <Pressable
            onPress={() => router.push('/(tabs)/messages')}
            accessibilityRole="button"
            accessibilityLabel={`Message ${them.name}`}
            style={s.msgBtn}
          >
            <Ionicons name="chatbubble-ellipses" size={17} color={Colors.textOnBrown} />
          </Pressable>
        </Card>
      ) : (
        <Card>
          <Button
            label="Find a caregiver"
            icon="search"
            variant="secondary"
            onPress={() => router.push('/(onboard)/find-care')}
          />
        </Card>
      )}

      {/* ── Recent notes ─────────────────────────────────── */}
      <SectionHeader
        title="Latest notes"
        icon="document-text-outline"
        action={isFamily ? 'See all' : 'Write one'}
        onAction={() => router.push('/(tabs)/notes')}
      />
      {recentNotes.length ? (
        recentNotes.map(n => {
          const tone = TrendColors[n.trend];
          return (
            <Pressable key={n.id} onPress={() => router.push('/(tabs)/notes')}>
              {({ pressed }) => (
                <Card style={[s.noteCard, pressed && { opacity: 0.9 }]}>
                  <View style={s.rowBetween}>
                    <View style={s.rowCenter}>
                      <View style={[s.trendDot, { backgroundColor: tone.fg }]} />
                      <Text style={s.noteTitle} numberOfLines={1}>{n.title}</Text>
                    </View>
                    <Text style={s.noteTime}>{relativeTime(n.createdAt)}</Text>
                  </View>
                  <Text style={s.noteBody} numberOfLines={2}>{n.body}</Text>
                  <View style={s.rowCenter}>
                    <Chip label={n.category} tone={{ fg: tone.fg, bg: tone.bg }} />
                    {n.comments.length ? (
                      <View style={s.commentCount}>
                        <Ionicons name="chatbubble-outline" size={11} color={Colors.textTertiary} />
                        <Text style={s.commentCountText}>{n.comments.length}</Text>
                      </View>
                    ) : null}
                  </View>
                </Card>
              )}
            </Pressable>
          );
        })
      ) : (
        <Card>
          <Text style={s.bodyText}>
            {isFamily
              ? 'No notes yet. Your caregiver writes one each visit.'
              : 'You have not written a note yet. The family reads these every day.'}
          </Text>
          {!isFamily ? (
            <Button
              label="Write the first note"
              variant="secondary"
              icon="create-outline"
              size="sm"
              style={{ marginTop: 10 }}
              onPress={() => router.push('/(tabs)/notes')}
            />
          ) : null}
        </Card>
      )}

      {/* ── Messages ─────────────────────────────────────── */}
      <SectionHeader
        title="Messages"
        icon="chatbubbles-outline"
        action="Open"
        onAction={() => router.push('/(tabs)/messages')}
      />
      {lastMessage ? (
        <Pressable onPress={() => router.push('/(tabs)/messages')}>
          {({ pressed }) => (
            <Card style={[s.msgCard, pressed && { opacity: 0.9 }]}>
              <Avatar initials={initials(lastMessage.senderName)} size={38} tone={
                lastMessage.senderRole === 'family' ? Colors.textStrong : Colors.brown
              } />
              <View style={{ flex: 1, gap: 2 }}>
                <View style={s.rowBetween}>
                  <Text style={s.msgName}>{lastMessage.senderName.split(' ')[0]}</Text>
                  <Text style={s.noteTime}>{relativeTime(lastMessage.createdAt)}</Text>
                </View>
                <Text style={s.msgPreview} numberOfLines={2}>
                  {lastMessage.translations[me.language] ?? lastMessage.text}
                </Text>
              </View>
            </Card>
          )}
        </Pressable>
      ) : (
        <Card><Text style={s.bodyText}>No messages yet.</Text></Card>
      )}
      {unreadFromThem > 0 ? (
        <Text style={s.msgHint}>
          {unreadFromThem} message{unreadFromThem > 1 ? 's' : ''} from{' '}
          {them?.name.split(' ')[0] ?? 'them'} in the last 12 hours
        </Text>
      ) : null}

      {/* ── Check-in history ─────────────────────────────── */}
      {state.quizzes.length > 1 ? (
        <>
          <SectionHeader title="Check-in trend" icon="stats-chart-outline" />
          <Card style={{ gap: 12 }}>
            <View style={s.chartRow}>
              {state.quizzes.slice(0, 7).reverse().map(q => (
                <View key={q.id} style={s.chartCol}>
                  <View style={s.chartTrack}>
                    <View
                      style={[
                        s.chartBar,
                        { height: `${Math.max(6, q.score)}%`, backgroundColor: scoreTone(q.score).fg },
                      ]}
                    />
                  </View>
                  <Text style={s.chartLabel}>
                    {new Date(q.submittedAt).toLocaleDateString(undefined, { weekday: 'narrow' })}
                  </Text>
                </View>
              ))}
            </View>
            <Text style={s.chartCaption}>
              Last {Math.min(7, state.quizzes.length)} check-ins · {dayLabel(state.quizzes[state.quizzes.length - 1].submittedAt)} to today
            </Text>
          </Card>
        </>
      ) : null}

      <View style={{ height: Spacing.xl }} />
    </ScrollView>
  );
}

function Summary({
  icon, label, text,
}: {
  icon: React.ComponentProps<typeof Ionicons>['name'];
  label: string;
  text: string;
}) {
  return (
    <View style={{ gap: 5 }}>
      <Text style={s.summaryLabel}>{label}</Text>
      <Text style={s.summaryText}>{text}</Text>
    </View>
  );
}

const s = StyleSheet.create({
  weakDot: { width: 7, height: 7, borderRadius: 4, marginTop: 6 },
  quizDate: {
    width: 46, height: 50, borderRadius: Radius.sm, backgroundColor: Colors.brown,
    alignItems: 'center', justifyContent: 'center',
  },
  quizDay: { fontFamily: 'Fraunces_700Bold', fontSize: 20, color: Colors.textOnBrown, lineHeight: 22 },
  quizMonth: { fontSize: 9, fontWeight: '700', letterSpacing: 0.8, color: Colors.textOnBrown },
  quizStart: { ...Type.callout, fontWeight: '700', color: Colors.brown },
  screen: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { padding: Spacing.md, paddingTop: Spacing.sm, gap: Spacing.sm },

  rowBetween: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 8 },
  rowCenter: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  hr: { height: StyleSheet.hairlineWidth, backgroundColor: Colors.separator },

  greetRow: { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: Spacing.md },
  greeting: { ...Type.title, color: Colors.textStrong },
  greetSub: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400', marginTop: 2 },

  heroCard: { gap: 14 },
  heroTop: { flexDirection: 'row', alignItems: 'flex-start', gap: 10 },
  heroLabel: { ...Type.overline, fontSize: 10, color: Colors.textSecondary },
  heroHeadline: { ...Type.heading, fontSize: 19, color: Colors.textStrong, lineHeight: 25 },
  heroLoading: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingVertical: 3 },
  heroLoadingText: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400' },

  scoreBlock: { gap: 7 },
  scoreRow: { flexDirection: 'row', alignItems: 'baseline', gap: 5 },
  scoreValue: { fontSize: 30, fontWeight: '800', color: Colors.textStrong, letterSpacing: -1 },
  scoreOutOf: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', flex: 1 },
  deltaRow: { flexDirection: 'row', alignItems: 'center', gap: 3 },
  deltaText: { fontSize: 12, fontWeight: '700' },
  scoreMeta: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400' },
  errorText: { ...Type.caption, color: Colors.urgent, fontWeight: '500' },

  cardTitle: { ...Type.subhead, color: Colors.textStrong },
  link: { ...Type.caption, color: Colors.brown, fontWeight: '700' },
  bodyText: { ...Type.body, fontSize: 14, color: Colors.textSecondary },

  quizCta: { flexDirection: 'row', alignItems: 'center', gap: 12, backgroundColor: Colors.accentSoft },
  quizIcon: {
    width: 42, height: 42, borderRadius: 21, backgroundColor: Colors.brown,
    alignItems: 'center', justifyContent: 'center',
  },
  quizTitle: { ...Type.subhead, color: Colors.textStrong },
  quizSub: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', marginTop: 2 },

  weakList: { gap: 7 },
  weakRow: { flexDirection: 'row', alignItems: 'flex-start', gap: 8 },
  weakText: { ...Type.callout, color: Colors.textPrimary, fontWeight: '400', flex: 1, lineHeight: 19 },
  insightBox: {
    flexDirection: 'row', gap: 8, alignItems: 'flex-start',
    backgroundColor: Colors.accentSoft, padding: 11, borderRadius: Radius.md,
  },
  insightText: { fontSize: 13, color: Colors.textPrimary, lineHeight: 19, flex: 1 },

  summaryLabel: { ...Type.overline, fontSize: 10, color: Colors.textSecondary },
  summaryText: { ...Type.body, fontSize: 14, color: Colors.textPrimary, lineHeight: 21 },
  suggestRow: { flexDirection: 'row', alignItems: 'center', gap: 9 },
  suggestDot: {
    width: 20, height: 20, borderRadius: 10, backgroundColor: Colors.accentSoft,
    alignItems: 'center', justifyContent: 'center',
  },
  suggestNum: { fontSize: 11, fontWeight: '800', color: Colors.brown },
  suggestText: { ...Type.callout, color: Colors.textPrimary, flex: 1 },
  aiCaveat: { fontSize: 11, color: Colors.textTertiary, fontStyle: 'italic' },

  personCard: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  personName: { ...Type.subhead, color: Colors.textStrong },
  personMeta: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  msgBtn: {
    width: 38, height: 38, borderRadius: 19, backgroundColor: Colors.brown,
    alignItems: 'center', justifyContent: 'center',
  },

  noteCard: { gap: 8, marginBottom: Spacing.sm },
  trendDot: { width: 8, height: 8, borderRadius: 4 },
  noteTitle: { ...Type.subhead, fontSize: 15, color: Colors.textStrong, flex: 1 },
  noteTime: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400' },
  noteBody: { ...Type.body, fontSize: 14, color: Colors.textSecondary, lineHeight: 20 },
  commentCount: { flexDirection: 'row', alignItems: 'center', gap: 3, marginLeft: 4 },
  commentCountText: { fontSize: 11, color: Colors.textTertiary },

  msgCard: { flexDirection: 'row', gap: 11, alignItems: 'center' },
  msgName: { ...Type.callout, color: Colors.textStrong, fontWeight: '700' },
  msgPreview: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400', lineHeight: 19 },
  msgHint: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400', marginTop: 6, textAlign: 'center' },

  chartRow: { flexDirection: 'row', alignItems: 'flex-end', gap: 6, height: 110 },
  chartCol: { flex: 1, alignItems: 'center', gap: 5, height: '100%' },
  chartTrack: {
    flex: 1, width: '100%', backgroundColor: Colors.surfaceTinted,
    borderRadius: Radius.sm, justifyContent: 'flex-end', overflow: 'hidden',
  },
  chartBar: { width: '100%', borderRadius: Radius.sm },
  chartLabel: { fontSize: 10, color: Colors.textTertiary, fontWeight: '600' },
  chartCaption: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400', textAlign: 'center' },
});
