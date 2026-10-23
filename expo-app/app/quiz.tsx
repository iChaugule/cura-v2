/**
 * The daily check-in.
 *
 * Six short steps: a safety check first, then one step per area (memory and
 * thinking, mood and behaviour, daily living and body, engagement), then a note
 * for the family. Each area has a few one-tap questions and an "also noticed
 * today" list of specific signs. About three minutes.
 *
 * When it is saved, the pattern engine runs on the new answers straight away
 * and the caregiver sees what Cura will tell the family.
 */
import { useMemo, useRef, useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, Pressable, KeyboardAvoidingView, Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Button, Input } from '../src/components/ui';
import { Colors, Radius, Spacing, Type } from '../src/design/tokens';
import { quizInsight } from '../src/ai/cura';
import { GEMINI_API_KEY } from '../src/ai/gemini';
import {
  OBSERVATIONS, QUIZ_QUESTIONS, RED_FLAG_ITEMS, SECTIONS, type CheckInSection,
} from '../src/data/quiz';
import { analyze, TIER_LABEL } from '../src/engine/patterns';
import { TierColors } from '../src/components/Findings';
import { Skeleton } from '../src/components/Skeleton';
import { useApp, useCareContext } from '../src/state/AppContext';

type Step = 'safety' | CheckInSection['id'] | 'note';
const STEPS: Step[] = ['safety', ...SECTIONS.map(s => s.id), 'note'];
const STEP_TITLE: Record<Step, string> = {
  safety: 'Safety check',
  memory: 'Memory and thinking',
  mood: 'Mood and behaviour',
  daily: 'Daily living and body',
  engagement: 'Engagement',
  note: 'For the family',
};

export default function CheckIn() {
  const { state, submitQuiz, setQuizInsight } = useApp();
  const ctx = useCareContext();
  const name = state.pnc?.preferredName ?? 'them';

  const [step, setStep] = useState(0);
  const [answers, setAnswers] = useState<Record<string, number>>({});
  const [redFlags, setRedFlags] = useState<string[]>([]);
  const [observed, setObserved] = useState<string[]>([]);
  const [note, setNote] = useState('');
  const [savedId, setSavedId] = useState<string | null>(null);
  const [insight, setInsight] = useState<string | null>(null);
  const [insightLoading, setInsightLoading] = useState(false);
  const scroll = useRef<ScrollView>(null);

  const current = STEPS[step];
  const section = SECTIONS.find(sec => sec.id === current);
  const questions = section ? QUIZ_QUESTIONS.filter(q => q.section === section.id) : [];
  const sectionDone = questions.every(q => answers[q.id] !== undefined);

  const toggle = (list: string[], set: (v: string[]) => void, id: string) =>
    set(list.includes(id) ? list.filter(x => x !== id) : [...list, id]);

  const go = (to: number) => {
    setStep(to);
    scroll.current?.scrollTo({ y: 0, animated: false });
  };

  const save = async () => {
    const response = submitQuiz(answers, note.trim(), { redFlags, observed });
    setSavedId(response.id);
    if (!GEMINI_API_KEY) return;
    setInsightLoading(true);
    try {
      const text = await quizInsight(response, ctx);
      setInsight(text);
      setQuizInsight(response.id, text);
    } catch {
      // The engine's findings below already say what matters.
    } finally {
      setInsightLoading(false);
    }
  };

  // After saving, show what the family will see.
  const report = useMemo(() => (savedId ? analyze(state.quizzes) : null), [savedId, state.quizzes]);

  if (savedId && report) {
    const top = report.findings.slice(0, 3);
    return (
      <SafeAreaView style={s.safe}>
        <ScrollView contentContainerStyle={s.doneScroll}>
          <Text style={s.overline}>CHECK-IN SAVED</Text>
          <Text style={s.doneTitle}>Thank you. The family can see today&apos;s check-in now.</Text>
          {redFlags.length ? (
            <View style={[s.alert, { backgroundColor: Colors.urgentSoft }]}>
              <Text style={[s.alertTitle, { color: Colors.urgent }]}>
                {redFlags.length === 1 ? 'One safety item was' : `${redFlags.length} safety items were`} flagged to the family
              </Text>
              <Text style={s.alertBody}>If anyone is in danger, call your local emergency number first.</Text>
            </View>
          ) : null}

          <Text style={s.doneSection}>What Cura is telling the family</Text>
          {top.length ? top.map(f => (
            <View key={f.id} style={s.finding}>
              <Text style={[s.findingTier, { color: TierColors[f.tier].fg }]}>{TIER_LABEL[f.tier].toUpperCase()}</Text>
              <Text style={s.findingTitle}>{f.title}</Text>
              <Text style={s.findingNext}>{f.nextStep}</Text>
            </View>
          )) : (
            <View style={s.finding}>
              <Text style={s.findingTitle}>{report.headline}</Text>
            </View>
          )}

          {insightLoading ? (
            <View style={[s.finding, { gap: 8 }]}>
              <Skeleton width="45%" height={11} />
              <Skeleton width="100%" height={11} />
              <Skeleton width="80%" height={11} />
            </View>
          ) : insight ? (
            <View style={s.finding}>
              <Text style={s.findingTier}>IN A SENTENCE</Text>
              <Text style={s.findingNext}>{insight}</Text>
            </View>
          ) : null}

          <Button label="Done" onPress={() => router.back()} style={{ marginTop: Spacing.lg }} />
        </ScrollView>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={s.safe}>
      {/* Header: where you are in the check-in */}
      <View style={s.header}>
        <View style={s.headerRow}>
          <Pressable
            onPress={() => (step === 0 ? router.back() : go(step - 1))}
            hitSlop={10}
            accessibilityRole="button"
            accessibilityLabel={step === 0 ? 'Close check-in' : 'Previous step'}
          >
            <Ionicons name={step === 0 ? 'close' : 'chevron-back'} size={22} color={Colors.brown} />
          </Pressable>
          <View style={{ flex: 1 }}>
            <Text style={s.headerTitle}>Daily check-in for {name}</Text>
            <Text style={s.headerSub}>Step {step + 1} of {STEPS.length} · {STEP_TITLE[current]}</Text>
          </View>
        </View>
        <View style={s.segments} accessibilityElementsHidden>
          {STEPS.map((st, i) => (
            <View key={st} style={[s.segment, i <= step && { backgroundColor: Colors.brown }]} />
          ))}
        </View>
      </View>

      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView ref={scroll} contentContainerStyle={s.scroll} keyboardShouldPersistTaps="handled">
          {current === 'safety' ? (
            <>
              <Text style={s.title}>First, a quick safety check</Text>
              <Text style={s.intro}>Since the last check-in, did any of these happen? Tap each one that did.</Text>
              <View style={{ gap: Spacing.sm, marginTop: Spacing.md }}>
                {RED_FLAG_ITEMS.map(item => {
                  const on = redFlags.includes(item.id);
                  return (
                    <Pressable
                      key={item.id}
                      onPress={() => toggle(redFlags, setRedFlags, item.id)}
                      accessibilityRole="checkbox"
                      accessibilityState={{ checked: on }}
                      style={[s.flag, on && s.flagOn]}
                    >
                      <View style={[s.box, on && s.boxOn]} />
                      <View style={{ flex: 1, gap: 2 }}>
                        <Text style={[s.flagLabel, on && { color: Colors.urgent }]}>{item.label}</Text>
                        <Text style={s.flagDetail}>{item.detail}</Text>
                      </View>
                    </Pressable>
                  );
                })}
              </View>
              {redFlags.length ? (
                <View style={[s.alert, { backgroundColor: Colors.urgentSoft, marginTop: Spacing.md }]}>
                  <Text style={[s.alertTitle, { color: Colors.urgent }]}>The family will be alerted as soon as you save</Text>
                  <Text style={s.alertBody}>
                    If they are hurt, cannot be woken, or are struggling to breathe, call your local emergency number now.
                  </Text>
                </View>
              ) : null}
            </>
          ) : null}

          {section ? (
            <>
              <Text style={s.title}>{section.title}</Text>
              <Text style={s.intro}>{section.intro}</Text>
              {questions.map((q, qi) => (
                <View key={q.id} style={s.question}>
                  <Text style={s.prompt}>
                    <Text style={s.qNum}>{qi + 1}.  </Text>{q.prompt}
                  </Text>
                  <Text style={s.helper}>{q.helper}</Text>
                  <View style={s.scale} accessibilityRole="radiogroup" accessibilityLabel={q.prompt}>
                    {[...q.options].reverse().map((label, ri) => {
                      const value = q.options.length - 1 - ri;
                      const on = answers[q.id] === value;
                      return (
                        <Pressable
                          key={label}
                          onPress={() => setAnswers(a => ({ ...a, [q.id]: value }))}
                          accessibilityRole="radio"
                          accessibilityState={{ selected: on }}
                          style={[s.option, on && s.optionOn]}
                        >
                          <View style={[s.radio, on && s.radioOn]}>{on ? <View style={s.radioDot} /> : null}</View>
                          <Text style={[s.optionText, on && s.optionTextOn]}>{label}</Text>
                        </Pressable>
                      );
                    })}
                  </View>
                </View>
              ))}

              <View style={s.noticed}>
                <Text style={s.noticedTitle}>Also noticed today</Text>
                <Text style={s.helper}>Tap any that happened. Leave the rest.</Text>
                <View style={s.chips}>
                  {OBSERVATIONS.filter(o => o.section === section.id).map(o => {
                    const on = observed.includes(o.id);
                    return (
                      <Pressable
                        key={o.id}
                        onPress={() => toggle(observed, setObserved, o.id)}
                        accessibilityRole="checkbox"
                        accessibilityState={{ checked: on }}
                        style={[s.chip, on && s.chipOn]}
                      >
                        <Text style={[s.chipText, on && s.chipTextOn]}>{o.label}</Text>
                      </Pressable>
                    );
                  })}
                </View>
              </View>
            </>
          ) : null}

          {current === 'note' ? (
            <>
              <Text style={s.title}>Anything the family should know?</Text>
              <Text style={s.intro}>
                A moment from the day, something that helped, or a question for them. Optional.
              </Text>
              <Input
                value={note}
                onChangeText={setNote}
                multiline
                placeholder="She enjoyed the old songs after lunch and settled quickly."
                style={{ minHeight: 120, textAlignVertical: 'top', marginTop: Spacing.md }}
              />
              <View style={s.summary}>
                <Text style={s.noticedTitle}>Before you save</Text>
                <Text style={s.summaryLine}>{Object.keys(answers).length} of {QUIZ_QUESTIONS.length} questions answered</Text>
                <Text style={s.summaryLine}>
                  {redFlags.length ? `${redFlags.length} safety item${redFlags.length > 1 ? 's' : ''} flagged` : 'No safety items flagged'}
                </Text>
                <Text style={s.summaryLine}>
                  {observed.length ? `${observed.length} sign${observed.length > 1 ? 's' : ''} noted` : 'No other signs noted'}
                </Text>
              </View>
            </>
          ) : null}
        </ScrollView>

        <View style={s.footer}>
          {current === 'note' ? (
            <Button label="Save check-in" onPress={save} />
          ) : (
            <Button
              label={current === 'safety' ? (redFlags.length ? 'Continue' : 'None of these happened') : 'Next'}
              onPress={() => go(step + 1)}
              disabled={!!section && !sectionDone}
            />
          )}
          {section && !sectionDone ? (
            <Text style={s.footHint}>Answer each question to continue.</Text>
          ) : null}
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.bgBase },

  header: {
    paddingHorizontal: Spacing.md, paddingTop: 10, paddingBottom: 12, gap: 10,
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.separator,
  },
  headerRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  headerTitle: { ...Type.subhead, color: Colors.textStrong },
  headerSub: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', marginTop: 1 },
  segments: { flexDirection: 'row', gap: 4 },
  segment: { flex: 1, height: 4, borderRadius: 2, backgroundColor: Colors.surfaceTinted },

  scroll: { padding: Spacing.lg, paddingBottom: Spacing.xxl, maxWidth: 640, width: '100%', alignSelf: 'center' },
  title: { ...Type.title, color: Colors.textStrong },
  intro: { ...Type.body, color: Colors.textSecondary, marginTop: 6 },

  flag: {
    flexDirection: 'row', gap: 12, alignItems: 'flex-start', padding: 14,
    borderRadius: Radius.md, backgroundColor: Colors.surface,
    borderWidth: 1.5, borderColor: Colors.separator,
  },
  flagOn: { borderColor: Colors.urgent, backgroundColor: Colors.urgentSoft },
  box: { width: 20, height: 20, borderRadius: 4, borderWidth: 2, borderColor: Colors.border, marginTop: 1 },
  boxOn: { backgroundColor: Colors.urgent, borderColor: Colors.urgent },
  flagLabel: { ...Type.subhead, fontSize: 15, color: Colors.textStrong },
  flagDetail: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },

  alert: { borderRadius: Radius.md, padding: 14, gap: 4 },
  alertTitle: { ...Type.callout, fontWeight: '700' },
  alertBody: { ...Type.callout, fontWeight: '400', color: Colors.textStrong },

  question: {
    marginTop: Spacing.lg, paddingTop: Spacing.md,
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator,
  },
  qNum: { color: Colors.textTertiary },
  prompt: { ...Type.subhead, fontSize: 17, lineHeight: 23, color: Colors.textStrong },
  helper: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', marginTop: 3 },
  scale: { gap: 6, marginTop: Spacing.sm },
  option: {
    flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 12, paddingHorizontal: 14,
    borderRadius: Radius.md, backgroundColor: Colors.surface, borderWidth: 1.5, borderColor: Colors.separator,
  },
  optionOn: { borderColor: Colors.brown, backgroundColor: Colors.accentSoft },
  radio: { width: 20, height: 20, borderRadius: 10, borderWidth: 2, borderColor: Colors.border, alignItems: 'center', justifyContent: 'center' },
  radioOn: { borderColor: Colors.brown },
  radioDot: { width: 10, height: 10, borderRadius: 5, backgroundColor: Colors.brown },
  optionText: { ...Type.callout, color: Colors.textPrimary, flex: 1 },
  optionTextOn: { color: Colors.textStrong, fontWeight: '700' },

  noticed: {
    marginTop: Spacing.xl, padding: Spacing.md, borderRadius: Radius.lg,
    backgroundColor: Colors.surfaceTinted, gap: 2,
  },
  noticedTitle: { fontFamily: 'Fraunces_600SemiBold', fontSize: 17, color: Colors.textStrong },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: Spacing.sm },
  chip: {
    paddingHorizontal: 12, paddingVertical: 9, borderRadius: Radius.md,
    backgroundColor: Colors.surface, borderWidth: 1, borderColor: Colors.border,
  },
  chipOn: { backgroundColor: Colors.textStrong, borderColor: Colors.textStrong },
  chipText: { ...Type.caption, fontSize: 13, color: Colors.textStrong },
  chipTextOn: { color: Colors.textOnBrown },

  summary: { marginTop: Spacing.lg, padding: Spacing.md, borderRadius: Radius.lg, backgroundColor: Colors.surfaceTinted, gap: 4 },
  summaryLine: { ...Type.callout, color: Colors.textPrimary, fontWeight: '400' },

  footer: {
    padding: Spacing.md, gap: 6,
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator, backgroundColor: Colors.bgBase,
  },
  footHint: { ...Type.caption, color: Colors.textTertiary, textAlign: 'center', fontWeight: '400' },

  doneScroll: { padding: Spacing.lg, paddingTop: Spacing.xl, gap: Spacing.sm, maxWidth: 640, width: '100%', alignSelf: 'center' },
  overline: { ...Type.overline, color: Colors.positive },
  doneTitle: { ...Type.title, color: Colors.textStrong, marginBottom: Spacing.sm },
  doneSection: { fontFamily: 'Fraunces_600SemiBold', fontSize: 18, color: Colors.textStrong, marginTop: Spacing.md },
  finding: {
    padding: Spacing.md, borderRadius: Radius.lg, backgroundColor: Colors.surface, gap: 4,
    borderWidth: StyleSheet.hairlineWidth * 2, borderColor: Colors.separator,
  },
  findingTier: { ...Type.overline, fontSize: 10, color: Colors.textSecondary },
  findingTitle: { ...Type.subhead, color: Colors.textStrong },
  findingNext: { ...Type.callout, fontWeight: '400', color: Colors.textPrimary },
});
