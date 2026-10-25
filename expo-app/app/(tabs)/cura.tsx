/**
 * Cura AI.
 *
 * Every answer is grounded in the care record (profile, notes, check-ins,
 * messages) and clinical claims are checked against live sources, which are
 * listed under the answer. Anything unrelated to this person's care is turned
 * away by the system prompt.
 */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  View, Text, StyleSheet, FlatList, Pressable, TextInput,
  KeyboardAvoidingView, Platform, ScrollView, Linking,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { RichText } from '../../src/components/RichText';
import { Avatar, Chip } from '../../src/components/ui';
import { Colors, Radius, Spacing, Type } from '../../src/design/tokens';
import { askCura, suggestedPrompts } from '../../src/ai/cura';
import { emergencyNumber } from '../../src/lib/emergency';
import { friendlyError } from '../../src/ai/gemini';
import { clockTime, initials, plainSpeech, possessive } from '../../src/lib/format';
import { useSpeech } from '../../src/lib/useSpeech';
import { useApp, useCareContext } from '../../src/state/AppContext';
import { router, useLocalSearchParams } from 'expo-router';
import { DAY_NAMES, timeLabel } from '../../src/lib/schedule';
import type { ScheduleSuggestion } from '../../src/models/types';
import { Skeleton } from '../../src/components/Skeleton';
import type { AiTurn } from '../../src/models/types';

const uid = () => `turn-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 6)}`;

export default function CuraAI() {
  const { state, me, setAiTurns, addScheduleItem } = useApp();
  const { q } = useLocalSearchParams<{ q?: string }>();
  const [added, setAdded] = useState<Record<string, boolean>>({});
  const ctx = useCareContext();
  const role = state.activeRole;
  const emergency = emergencyNumber(state.pnc?.address).label;
  const turns = state.aiTurns[role] ?? [];

  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const listRef = useRef<FlatList<AiTurn>>(null);
  const { speakingId, toggle } = useSpeech();

  const prompts = useMemo(() => suggestedPrompts(ctx), [ctx]);

  const scrollToEnd = () =>
    setTimeout(() => listRef.current?.scrollToEnd({ animated: true }), 60);

  const send = useCallback(async (text: string) => {
    const question = text.trim();
    if (!question || busy) return;

    const userTurn: AiTurn = { id: uid(), role: 'user', text: question, createdAt: Date.now() };
    const history = [...turns];
    const next = [...history, userTurn];
    setAiTurns(role, next);
    setInput('');
    setBusy(true);
    scrollToEnd();

    try {
      const answer = await askCura(question, ctx, history);
      setAiTurns(role, [
        ...next,
        {
          id: uid(), role: 'assistant', text: answer.text,
          createdAt: Date.now(), sources: answer.sources, suggestions: answer.suggestions,
        },
      ]);
    } catch (err) {
      setAiTurns(role, [
        ...next,
        { id: uid(), role: 'assistant', text: friendlyError(err), createdAt: Date.now(), error: true },
      ]);
    } finally {
      setBusy(false);
      scrollToEnd();
    }
  }, [busy, turns, role, ctx, setAiTurns]);

  const clear = () => setAiTurns(role, []);

  // Arriving with a question (e.g. from the schedule's "Ask Cura") asks it once.
  const asked = useRef<string | null>(null);
  useEffect(() => {
    if (q && asked.current !== q) {
      asked.current = q;
      send(q);
      router.setParams({ q: '' });
    }
  }, [q, send]);

  return (
    <View style={s.screen}>
      {/* Header */}
      <View style={s.header}>
        <View style={s.headerIcon}>
          <Text style={s.mono}>C</Text>
        </View>
        <View style={{ flex: 1 }}>
          <Text style={s.headerTitle}>Ask Cura</Text>
          <Text style={s.headerSub}>
            Knows {possessive(state.pnc?.preferredName ?? '')} notes, check-ins, messages and schedule
          </Text>
        </View>
        {turns.length ? (
          <Pressable onPress={clear} hitSlop={8} accessibilityRole="button" accessibilityLabel="Clear conversation">
            <Text style={s.clear}>Clear</Text>
          </Pressable>
        ) : null}
      </View>

      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={Platform.OS === 'ios' ? 88 : 0}
      >
        <FlatList
          ref={listRef}
          data={turns}
          keyExtractor={t => t.id}
          style={s.list}
          contentContainerStyle={s.listContent}
          showsVerticalScrollIndicator={false}
          onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: false })}
          ListEmptyComponent={
            <Intro name={state.pnc?.preferredName ?? 'them'} role={role} />
          }
          ListFooterComponent={
            busy ? (
              <View style={s.typingRow}>
                <View style={s.aiAvatar}>
        <Text style={s.monoSm}>C</Text>
      </View>
                <View style={[s.bubble, s.bubbleAi, { gap: 8, width: 240 }]}>
                  <Text style={s.typingText}>Checking the record and sources</Text>
                  <Skeleton width="100%" height={10} />
                  <Skeleton width="80%" height={10} />
                </View>
              </View>
            ) : null
          }
          renderItem={({ item }) => (
            <Turn
              turn={item}
              myInitials={initials(me?.name ?? 'You')}
              speaking={speakingId === item.id}
              onSpeak={() => toggle(item.id, plainSpeech(item.text), me?.language ?? 'en')}
              added={added}
              onAdd={(sug, key) => {
                addScheduleItem({ ...sug, days: sug.days });
                setAdded(a => ({ ...a, [key]: true }));
              }}
            />
          )}
        />

        {/* Suggested prompts */}
        {turns.length === 0 && !busy ? (
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            style={s.promptStrip}
            contentContainerStyle={s.promptRow}
          >
            {prompts.map(p => (
              <Chip key={p} label={p} onPress={() => send(p)} />
            ))}
          </ScrollView>
        ) : null}

        {/* Composer */}
        <View style={s.composer}>
          <TextInput
            style={s.input}
            value={input}
            onChangeText={setInput}
            placeholder={`Ask about ${possessive(state.pnc?.preferredName ?? '')} care…`}
            placeholderTextColor={Colors.textTertiary}
            multiline
            maxLength={500}
            onSubmitEditing={() => send(input)}
            blurOnSubmit={false}
            accessibilityLabel="Ask Cura AI a question"
          />
          <Pressable
            onPress={() => send(input)}
            disabled={!input.trim() || busy}
            accessibilityRole="button"
            accessibilityLabel="Send"
            style={({ pressed }) => [
              s.sendBtn,
              (!input.trim() || busy) && { backgroundColor: Colors.textTertiary },
              pressed && { opacity: 0.8 },
            ]}
          >
            <Ionicons name="arrow-up" size={19} color={Colors.textOnBrown} />
          </Pressable>
        </View>
        <Text style={s.disclaimer}>
          Cura AI checks credible medical sources but cannot diagnose. In an emergency call {emergency}.
        </Text>
      </KeyboardAvoidingView>
    </View>
  );
}

function Intro({ name, role }: { name: string; role: 'family' | 'caregiver' }) {
  return (
    <View style={s.intro}>
      <Text style={s.introTitle}>Ask about {name}&apos;s care</Text>
      <Text style={s.introBody}>
        {role === 'family'
          ? `I read every note, check-in, message and the daily schedule for ${name}. Ask what changed, what it might mean, or what to raise with their doctor.`
          : `I have ${name}'s full record: notes, check-ins, the schedule and what the family has said. Ask about technique, warning signs, or what to write today.`}
      </Text>
      <View style={s.introNote}>
        <Text style={s.introNoteText}>
          I only answer questions about {name}&apos;s care, and I check medical facts against
          sources like the WHO, NHS and Mayo Clinic.
        </Text>
      </View>
    </View>
  );
}

function Turn({
  turn, myInitials, speaking, onSpeak, added, onAdd,
}: {
  turn: AiTurn;
  myInitials: string;
  speaking: boolean;
  onSpeak: () => void;
  added: Record<string, boolean>;
  onAdd: (s: ScheduleSuggestion, key: string) => void;
}) {
  const isAi = turn.role === 'assistant';

  if (!isAi) {
    return (
      <View style={[s.row, { justifyContent: 'flex-end' }]}>
        <View style={[s.bubble, s.bubbleUser]}>
          <Text style={s.userText}>{turn.text}</Text>
          <Text style={s.timeUser}>{clockTime(turn.createdAt)}</Text>
        </View>
        <Avatar initials={myInitials} size={26} tone={Colors.textStrong} />
      </View>
    );
  }

  return (
    <View style={s.row}>
      <View style={s.aiAvatar}>
        <Text style={s.monoSm}>C</Text>
      </View>
      <View style={[s.bubble, s.bubbleAi, turn.error && s.bubbleError]}>
        <RichText style={turn.error ? { color: Colors.urgent } : undefined}>{turn.text}</RichText>

        {turn.suggestions?.map((sug, i) => {
          const key = `${turn.id}:${i}`;
          const done = added[key];
          return (
            <View key={key} style={s.suggest}>
              <Text style={s.sourcesLabel}>SUGGESTED FOR THE SCHEDULE</Text>
              <Text style={s.sugTitle}>{sug.title}</Text>
              <Text style={s.sugMeta}>
                {timeLabel(sug.time)}, {sug.days.length ? sug.days.map(d => DAY_NAMES[d]).join(', ') : 'every day'}
              </Text>
              {sug.detail ? <Text style={s.sugMeta}>{sug.detail}</Text> : null}
              <Pressable
                disabled={done}
                onPress={() => onAdd(sug, key)}
                accessibilityRole="button"
                style={({ pressed }) => [s.sugBtn, done && { opacity: 0.5 }, pressed && { opacity: 0.8 }]}
              >
                <Text style={s.sugBtnText}>{done ? 'Added to the schedule' : 'Add to the schedule'}</Text>
              </Pressable>
            </View>
          );
        })}

        {turn.sources?.length ? (
          <View style={s.sources}>
            <Text style={s.sourcesLabel}>CHECKED AGAINST</Text>
            {turn.sources.map(src => (
              <Pressable
                key={src.uri}
                onPress={() => Linking.openURL(src.uri).catch(() => {})}
                accessibilityRole="link"
                accessibilityLabel={`Open source: ${src.title}`}
                style={({ pressed }) => [s.sourceRow, pressed && { opacity: 0.6 }]}
              >
                <Text style={s.sourceText} numberOfLines={1}>{src.title}</Text>
              </Pressable>
            ))}
          </View>
        ) : null}

        <View style={s.bubbleFooter}>
          <Text style={s.time}>{clockTime(turn.createdAt)}</Text>
          {!turn.error ? (
            <Pressable
              onPress={onSpeak}
              hitSlop={8}
              accessibilityRole="button"
              accessibilityLabel={speaking ? 'Stop reading aloud' : 'Read aloud'}
              style={s.speakBtn}
            >
              <Ionicons
                name={speaking ? 'stop-circle' : 'volume-medium-outline'}
                size={16}
                color={speaking ? Colors.brown : Colors.textTertiary}
              />
            </Pressable>
          ) : null}
        </View>
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  mono: { fontFamily: 'Fraunces_700Bold', fontSize: 17, color: Colors.textOnBrown },
  monoSm: { fontFamily: 'Fraunces_700Bold', fontSize: 13, color: Colors.textOnBrown },
  screen: { flex: 1, backgroundColor: Colors.bgSunken },

  header: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    paddingHorizontal: Spacing.md, paddingVertical: 10,
    backgroundColor: Colors.bgBase,
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.separator,
  },
  headerIcon: {
    width: 36, height: 36, borderRadius: 18, backgroundColor: Colors.brown,
    alignItems: 'center', justifyContent: 'center',
  },
  headerTitle: { ...Type.subhead, color: Colors.textStrong },
  headerSub: { fontSize: 11.5, color: Colors.textSecondary, marginTop: 1 },
  clear: { ...Type.caption, color: Colors.brown, fontWeight: '700' },

  list: { flex: 1 },
  listContent: { padding: Spacing.md, paddingBottom: Spacing.lg, gap: 12, flexGrow: 1 },

  row: { flexDirection: 'row', alignItems: 'flex-end', gap: 7 },
  aiAvatar: {
    width: 26, height: 26, borderRadius: 13, backgroundColor: Colors.brown,
    alignItems: 'center', justifyContent: 'center',
  },
  bubble: { maxWidth: '84%', paddingHorizontal: 14, paddingVertical: 11, borderRadius: Radius.lg },
  bubbleAi: {
    backgroundColor: Colors.surface, borderBottomLeftRadius: 4,
    borderWidth: StyleSheet.hairlineWidth, borderColor: Colors.separator, gap: 8,
  },
  bubbleError: { backgroundColor: Colors.urgentSoft, borderColor: Colors.urgentSoft },
  bubbleUser: { backgroundColor: Colors.brown, borderBottomRightRadius: 4 },
  userText: { ...Type.body, fontSize: 15, color: Colors.textOnBrown },
  time: { fontSize: 10, color: Colors.textTertiary },
  timeUser: { fontSize: 10, color: 'rgba(253,248,242,0.65)', alignSelf: 'flex-end', marginTop: 3 },
  bubbleFooter: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 8 },
  speakBtn: { padding: 2 },

  sources: {
    gap: 4, backgroundColor: Colors.infoSoft, padding: 9, borderRadius: Radius.sm,
  },
  sourcesLabel: { fontSize: 9, fontWeight: '800', letterSpacing: 0.6, color: Colors.info },
  sourceRow: { flexDirection: 'row', alignItems: 'center', gap: 5 },
  sourceText: { fontSize: 11.5, color: Colors.info, flex: 1, textDecorationLine: 'underline' },

  suggest: {
    gap: 4, backgroundColor: Colors.bgSunken, padding: 10, borderRadius: Radius.sm,
    borderWidth: StyleSheet.hairlineWidth, borderColor: Colors.separator,
  },
  sugTitle: { fontSize: 15, fontWeight: '700', color: Colors.textStrong },
  sugMeta: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  sugBtn: { alignSelf: 'flex-start', marginTop: 6, backgroundColor: Colors.brown, borderRadius: Radius.md, paddingHorizontal: 14, paddingVertical: 8 },
  sugBtnText: { fontSize: 13, fontWeight: '700', color: Colors.textOnBrown },
  typingRow: { flexDirection: 'row', alignItems: 'flex-end', gap: 7 },
  typingBubble: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  typingText: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400' },

  intro: { alignItems: 'center', gap: 8, paddingVertical: Spacing.xl, paddingHorizontal: Spacing.sm },
  introIcon: {
    width: 62, height: 62, borderRadius: 31, backgroundColor: Colors.accentSoft,
    alignItems: 'center', justifyContent: 'center', marginBottom: 4,
  },
  introTitle: { ...Type.heading, color: Colors.textStrong, textAlign: 'center' },
  introBody: {
    ...Type.body, fontSize: 14, color: Colors.textSecondary,
    textAlign: 'center', lineHeight: 21, maxWidth: 330,
  },
  introNote: {
    flexDirection: 'row', gap: 8, alignItems: 'flex-start',
    backgroundColor: Colors.surface, padding: 11, borderRadius: Radius.md,
    borderWidth: StyleSheet.hairlineWidth, borderColor: Colors.separator,
    marginTop: 8, maxWidth: 360,
  },
  introNoteText: { fontSize: 12, color: Colors.textSecondary, lineHeight: 17, flex: 1 },

  promptStrip: {
    maxHeight: 52, backgroundColor: Colors.bgBase,
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator,
  },
  promptRow: { gap: Spacing.sm, padding: 10, alignItems: 'center' },

  composer: {
    flexDirection: 'row', alignItems: 'flex-end', gap: 8,
    paddingHorizontal: Spacing.sm, paddingTop: Spacing.sm, paddingBottom: 4,
    backgroundColor: Colors.bgBase,
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator,
  },
  input: {
    flex: 1, backgroundColor: Colors.surfaceRaised,
    borderWidth: 1, borderColor: Colors.border, borderRadius: Radius.xl,
    paddingHorizontal: 14, paddingVertical: 10,
    fontSize: 15, color: Colors.textStrong, maxHeight: 110,
  },
  sendBtn: {
    width: 38, height: 38, borderRadius: 19, backgroundColor: Colors.brown,
    alignItems: 'center', justifyContent: 'center',
  },
  disclaimer: {
    fontSize: 10.5, color: Colors.textTertiary, textAlign: 'center',
    paddingBottom: 8, paddingHorizontal: Spacing.md, backgroundColor: Colors.bgBase,
  },
});
