/**
 * The daily check-in.
 *
 * One question per screen so it can be filled in while standing in a kitchen.
 * On submit the answers are scored, stored, and sent to Cura AI for a short
 * read — which then feeds the home digest and the chatbot's context.
 */
import { useMemo, useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, Pressable, KeyboardAvoidingView, Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Button, Card, Input, Meter } from '../src/components/ui';
import { Colors, Radius, Spacing, Type } from '../src/design/tokens';
import { quizInsight } from '../src/ai/cura';
import { friendlyError } from '../src/ai/gemini';
import {
  QUIZ_QUESTIONS, computeScore, scoreLabel, scoreTone, MAX_OPTION_INDEX,
} from '../src/data/quiz';
import { useApp, useCareContext } from '../src/state/AppContext';
import { Skeleton } from '../src/components/Skeleton';

export default function Quiz() {
  const { state, submitQuiz, setQuizInsight } = useApp();
  const ctx = useCareContext();
  const pncName = state.pnc?.preferredName ?? 'them';

  const [index, setIndex] = useState(0);
  const [answers, setAnswers] = useState<Record<string, number>>({});
  const [freeText, setFreeText] = useState('');
  const [phase, setPhase] = useState<'questions' | 'note' | 'done'>('questions');
  const [insight, setInsight] = useState<string | null>(null);
  const [insightError, setInsightError] = useState<string | null>(null);
  const [working, setWorking] = useState(false);

  const question = QUIZ_QUESTIONS[index];
  const answered = Object.keys(answers).length;
  const score = useMemo(() => computeScore(answers), [answers]);
  const tone = scoreTone(score);

  const choose = (optionIndex: number) => {
    const next = { ...answers, [question.id]: optionIndex };
    setAnswers(next);
    // Small pause so the selection is visible before advancing.
    setTimeout(() => {
      if (index < QUIZ_QUESTIONS.length - 1) setIndex(index + 1);
      else setPhase('note');
    }, 180);
  };

  const submit = async () => {
    setWorking(true);
    const response = submitQuiz(answers, freeText.trim());
    setPhase('done');
    try {
      const text = await quizInsight(response, ctx);
      setInsight(text);
      setQuizInsight(response.id, text);
    } catch (err) {
      setInsightError(friendlyError(err));
    } finally {
      setWorking(false);
    }
  };

  // ── Done ────────────────────────────────────────────────
  if (phase === 'done') {
    return (
      <SafeAreaView style={s.safe}>
        <ScrollView contentContainerStyle={s.doneScroll} showsVerticalScrollIndicator={false}>
          <View style={[s.scoreRing, { borderColor: tone.fg, backgroundColor: tone.bg }]}>
            <Text style={[s.scoreBig, { color: tone.fg }]}>{score}</Text>
            <Text style={s.scoreUnit}>/ 100</Text>
          </View>
          <Text style={s.doneTitle}>{scoreLabel(score)}</Text>
          <Text style={s.doneSub}>Today&apos;s check-in for {pncName} is saved.</Text>

          <Card style={s.insightCard}>
            <View style={s.insightHead}>
              <Text style={s.insightLabel}>WHAT CURA NOTICED</Text>
            </View>
            {working ? (
              <View style={{ gap: 8 }}>
                <Text style={s.insightLoadingText}>Comparing with the notes and past check-ins</Text>
                <Skeleton width="100%" height={11} />
                <Skeleton width="85%" height={11} />
              </View>
            ) : insight ? (
              <Text style={s.insightText}>{insight}</Text>
            ) : (
              <Text style={s.insightError}>
                {insightError ?? 'Could not reach Cura AI. Your answers are saved.'}
              </Text>
            )}
          </Card>

          <View style={s.breakdown}>
            {QUIZ_QUESTIONS.map(q => {
              const a = answers[q.id];
              if (a === undefined) return null;
              const good = a === MAX_OPTION_INDEX;
              return (
                <View key={q.id} style={s.breakRow}>
                  <Ionicons
                    name={q.icon as React.ComponentProps<typeof Ionicons>['name']}
                    size={15}
                    color={good ? Colors.positive : a === 0 ? Colors.urgent : Colors.caution}
                  />
                  <Text style={s.breakText} numberOfLines={1}>{q.options[a]}</Text>
                </View>
              );
            })}
          </View>

          <View style={{ gap: Spacing.sm, marginTop: Spacing.md }}>
            <Button label="Done" icon="checkmark" onPress={() => router.back()} />
            <Button
              label="Ask Cura AI about this"
              variant="secondary"
              icon="chatbox-ellipses-outline"
              onPress={() => { router.back(); setTimeout(() => router.push('/(tabs)/cura'), 200); }}
            />
          </View>
        </ScrollView>
      </SafeAreaView>
    );
  }

  // ── Free-text step ──────────────────────────────────────
  if (phase === 'note') {
    return (
      <SafeAreaView style={s.safe}>
        <Header
          title="Anything else?"
          subtitle="Optional"
          onClose={() => router.back()}
          onBack={() => { setPhase('questions'); setIndex(QUIZ_QUESTIONS.length - 1); }}
          progress={1}
        />
        <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <ScrollView contentContainerStyle={s.scroll} keyboardShouldPersistTaps="handled">
            <Text style={s.prompt}>Anything the numbers miss?</Text>
            <Text style={s.helper}>
              Something they said, a change you noticed, a question for the doctor. Cura AI reads
              this along with the answers.
            </Text>
            <Input
              value={freeText}
              onChangeText={setFreeText}
              multiline
              style={{ minHeight: 130, marginTop: Spacing.md }}
              placeholder={`e.g. ${pncName} kept rubbing her knee after lunch and did not want her walk.`}
            />

            <Card style={s.previewCard}>
              <View style={s.previewRow}>
                <Text style={s.previewLabel}>Today&apos;s wellbeing score</Text>
                <Text style={[s.previewScore, { color: tone.fg }]}>{score}/100</Text>
              </View>
              <Meter value={score} tone={tone.fg} />
              <Text style={s.previewMeta}>{scoreLabel(score)} · {answered} of {QUIZ_QUESTIONS.length} answered</Text>
            </Card>
          </ScrollView>

          <View style={s.footer}>
            <Button
              label={working ? 'Saving…' : 'Submit check-in'}
              icon="checkmark"
              loading={working}
              onPress={submit}
            />
          </View>
        </KeyboardAvoidingView>
      </SafeAreaView>
    );
  }

  // ── Questions ───────────────────────────────────────────
  return (
    <SafeAreaView style={s.safe}>
      <Header
        title={`Check-in for ${pncName}`}
        subtitle={`Question ${index + 1} of ${QUIZ_QUESTIONS.length}`}
        onClose={() => router.back()}
        onBack={index > 0 ? () => setIndex(index - 1) : undefined}
        progress={(index + (answers[question.id] !== undefined ? 1 : 0)) / QUIZ_QUESTIONS.length}
      />

      <ScrollView contentContainerStyle={s.scroll} showsVerticalScrollIndicator={false}>
        <View style={s.qIcon}>
          <Ionicons
            name={question.icon as React.ComponentProps<typeof Ionicons>['name']}
            size={26}
            color={Colors.brown}
          />
        </View>
        <Text style={s.prompt}>{question.prompt}</Text>
        <Text style={s.helper}>{question.helper}</Text>

        <View style={s.options}>
          {question.options.map((option, i) => {
            const active = answers[question.id] === i;
            return (
              <Pressable
                key={option}
                onPress={() => choose(i)}
                accessibilityRole="radio"
                accessibilityState={{ selected: active }}
                style={({ pressed }) => [
                  s.option,
                  active && { borderColor: Colors.brown, backgroundColor: Colors.accentSoft, borderWidth: 2 },
                  pressed && { opacity: 0.85 },
                ]}
              >
                <View style={[s.optionDot, active && { backgroundColor: Colors.brown, borderColor: Colors.brown }]}>
                  {active ? <Ionicons name="checkmark" size={13} color={Colors.textOnBrown} /> : null}
                </View>
                <Text style={[s.optionText, active && { color: Colors.textStrong, fontWeight: '600' }]}>
                  {option}
                </Text>
              </Pressable>
            );
          })}
        </View>

        {answered > 0 ? (
          <Pressable onPress={() => setPhase('note')} style={s.skipRow} hitSlop={8}>
            <Text style={s.skipText}>Skip the rest and submit</Text>
          </Pressable>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
}

function Header({
  title, subtitle, onClose, onBack, progress,
}: {
  title: string;
  subtitle: string;
  onClose: () => void;
  onBack?: () => void;
  progress: number;
}) {
  return (
    <View style={s.header}>
      <View style={s.headerRow}>
        {onBack ? (
          <Pressable onPress={onBack} hitSlop={10} accessibilityRole="button" accessibilityLabel="Previous question">
            <Ionicons name="chevron-back" size={22} color={Colors.brown} />
          </Pressable>
        ) : (
          <View style={{ width: 22 }} />
        )}
        <View style={{ flex: 1, alignItems: 'center' }}>
          <Text style={s.headerTitle} numberOfLines={1}>{title}</Text>
          <Text style={s.headerSub}>{subtitle}</Text>
        </View>
        <Pressable onPress={onClose} hitSlop={10} accessibilityRole="button" accessibilityLabel="Close">
          <Ionicons name="close" size={22} color={Colors.textSecondary} />
        </Pressable>
      </View>
      <View style={s.progressTrack}>
        <View style={[s.progressFill, { width: `${Math.max(4, progress * 100)}%` }]} />
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.bgBase },

  header: {
    paddingHorizontal: Spacing.md, paddingVertical: 12, gap: 10,
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.separator,
  },
  headerRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  headerTitle: { ...Type.subhead, color: Colors.textStrong },
  headerSub: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', marginTop: 1 },
  progressTrack: { height: 4, borderRadius: 2, backgroundColor: Colors.surfaceTinted, overflow: 'hidden' },
  progressFill: { height: '100%', borderRadius: 2, backgroundColor: Colors.brown },

  scroll: { padding: Spacing.lg, paddingBottom: Spacing.xxl },
  qIcon: {
    width: 56, height: 56, borderRadius: 28, backgroundColor: Colors.accentSoft,
    alignItems: 'center', justifyContent: 'center', marginBottom: Spacing.md,
  },
  prompt: { ...Type.title, color: Colors.textStrong, lineHeight: 31 },
  helper: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400', marginTop: 6, lineHeight: 20 },

  options: { gap: Spacing.sm, marginTop: Spacing.lg },
  option: {
    flexDirection: 'row', alignItems: 'center', gap: 12,
    padding: 15, borderRadius: Radius.lg,
    backgroundColor: Colors.surface, borderWidth: 1.5, borderColor: Colors.separator,
  },
  optionDot: {
    width: 22, height: 22, borderRadius: 11, borderWidth: 2, borderColor: Colors.border,
    alignItems: 'center', justifyContent: 'center',
  },
  optionText: { ...Type.body, fontSize: 15, color: Colors.textPrimary, flex: 1, lineHeight: 21 },

  skipRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6, marginTop: Spacing.lg },
  skipText: { ...Type.callout, color: Colors.textSecondary },

  previewCard: { marginTop: Spacing.lg, gap: 8 },
  previewRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  previewLabel: { ...Type.callout, color: Colors.textSecondary, fontWeight: '500' },
  previewScore: { ...Type.heading, fontSize: 17 },
  previewMeta: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400' },

  footer: {
    padding: Spacing.md,
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator,
    backgroundColor: Colors.bgBase,
  },

  doneScroll: { padding: Spacing.lg, alignItems: 'stretch', paddingTop: Spacing.xl },
  scoreRing: {
    width: 124, height: 124, borderRadius: 62, borderWidth: 5,
    alignItems: 'center', justifyContent: 'center', alignSelf: 'center',
  },
  scoreBig: { fontSize: 42, fontWeight: '800', letterSpacing: -1.5 },
  scoreUnit: { ...Type.caption, color: Colors.textSecondary, fontWeight: '500', marginTop: -2 },
  doneTitle: { ...Type.title, color: Colors.textStrong, textAlign: 'center', marginTop: Spacing.md },
  doneSub: {
    ...Type.callout, color: Colors.textSecondary, fontWeight: '400',
    textAlign: 'center', marginTop: 4,
  },

  insightCard: { marginTop: Spacing.lg, gap: 8 },
  insightHead: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  insightLabel: { ...Type.overline, fontSize: 10, color: Colors.textSecondary },
  insightText: { ...Type.body, fontSize: 14, color: Colors.textPrimary, lineHeight: 21 },
  insightError: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400' },
  insightLoading: { flexDirection: 'row', alignItems: 'center', gap: 9 },
  insightLoadingText: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400', flex: 1 },

  breakdown: {
    marginTop: Spacing.md, gap: 8, backgroundColor: Colors.surfaceTinted,
    padding: Spacing.md, borderRadius: Radius.lg,
  },
  breakRow: { flexDirection: 'row', alignItems: 'center', gap: 9 },
  breakText: { ...Type.callout, color: Colors.textPrimary, fontWeight: '400', flex: 1 },
});
