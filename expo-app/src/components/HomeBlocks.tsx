/**
 * Pieces of the two home screens that both roles share: today's schedule,
 * recent messages, a quick note box, and text that translates itself.
 */
import { useEffect, useState } from 'react';
import { View, Text, StyleSheet, Pressable, TextInput, type StyleProp, type TextStyle } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Button, Card, Chip } from './ui';
import { Colors, Radius, Spacing, Type, type Trend } from '../design/tokens';
import { languageLabel } from '../ai/cura';
import { relativeTime } from '../lib/format';
import { dateKey, dueState, itemsOn, logFor, progress, timeLabel } from '../lib/schedule';
import { useTranslated } from '../lib/useTranslated';
import { useApp } from '../state/AppContext';

/** Text shown in the reader's language, with a small note when it was translated. */
export function TranslatedText({
  text, sourceLang, targetLang, style, numberOfLines, noteStyle,
}: {
  text: string; sourceLang?: string; targetLang?: string;
  style?: StyleProp<TextStyle>; numberOfLines?: number; noteStyle?: StyleProp<TextStyle>;
}) {
  const [original, setOriginal] = useState(false);
  const t = useTranslated(text, sourceLang, targetLang);
  return (
    <View style={{ gap: 3 }}>
      <Text style={style} numberOfLines={numberOfLines}>{original ? text : t.text}</Text>
      {t.translated ? (
        <Pressable onPress={() => setOriginal(v => !v)} hitSlop={6} accessibilityRole="button">
          <Text style={[s.tNote, noteStyle]}>
            {original ? 'Show translation' : `Translated from ${languageLabel(sourceLang ?? '')}. Tap for original.`}
          </Text>
        </Pressable>
      ) : null}
    </View>
  );
}

/** The language a person writes in, by author id (or by role when ids are not known, as in demo). */
export function useAuthorLang() {
  const { state } = useApp();
  return (authorId: string, role: 'family' | 'caregiver') =>
    state.members.find(m => m.id === authorId)?.language
    ?? (role === 'family' ? state.familyAccount?.language : state.caregiverAccount?.language)
    ?? 'en';
}

// ── Today's schedule ────────────────────────────────────────

export function TodaySchedule({ limit = 4 }: { limit?: number }) {
  const { state, toggleDose } = useApp();
  const today = dateKey();
  const items = itemsOn(state.schedule, today);
  const { total, done } = progress(state.schedule, state.scheduleLog, today);
  const open = items.filter(i => !logFor(state.scheduleLog, i.id, today));
  const shown = open.slice(0, limit);

  return (
    <View style={{ gap: Spacing.sm }}>
      <View style={s.sectionRow}>
        <Text style={s.sectionTitle}>Today&apos;s schedule</Text>
        <Pressable onPress={() => router.push('/(tabs)/schedule')} hitSlop={8} accessibilityRole="link">
          <Text style={s.link}>{total ? `${done} of ${total} done` : 'Add'}</Text>
        </Pressable>
      </View>
      <Card style={{ paddingVertical: 4 }}>
        {total === 0 ? (
          <Text style={[s.body, { paddingVertical: 12 }]}>
            Nothing is scheduled yet. Add medicines, meals and the daily routine so everyone knows what is due.
          </Text>
        ) : shown.length === 0 ? (
          <Text style={[s.body, { paddingVertical: 12 }]}>Everything planned for today is done.</Text>
        ) : (
          shown.map((item, i) => {
            const st = dueState(item, false, today);
            return (
              <View key={item.id} style={[s.row, i > 0 && s.rowRule]}>
                <Text style={s.time}>{timeLabel(item.time)}</Text>
                <View style={{ flex: 1 }}>
                  <Text style={s.rowTitle}>{item.title}</Text>
                  {st === 'due' || st === 'missed' ? (
                    <Text style={[s.rowStatus, { color: st === 'missed' ? Colors.urgent : Colors.caution }]}>
                      {st === 'missed' ? 'Not marked done' : 'Due now'}
                    </Text>
                  ) : null}
                </View>
                <Pressable
                  onPress={() => toggleDose(item.id, today)}
                  accessibilityRole="checkbox" accessibilityState={{ checked: false }}
                  accessibilityLabel={`${item.title}, mark done`} hitSlop={10} style={s.box}
                />
              </View>
            );
          })
        )}
        {open.length > shown.length ? (
          <Pressable onPress={() => router.push('/(tabs)/schedule')} style={[s.row, s.rowRule]} accessibilityRole="link">
            <Text style={s.link}>{open.length - shown.length} more today</Text>
          </Pressable>
        ) : null}
      </Card>
    </View>
  );
}

// ── Recent messages ─────────────────────────────────────────

export function RecentMessages() {
  const { state, me } = useApp();
  const last = state.messages.slice(-2).reverse();
  const myLang = me?.language ?? 'en';
  return (
    <View style={{ gap: Spacing.sm }}>
      <View style={s.sectionRow}>
        <Text style={s.sectionTitle}>Messages</Text>
        <Pressable onPress={() => router.push('/(tabs)/messages')} hitSlop={8} accessibilityRole="link">
          <Text style={s.link}>Open</Text>
        </Pressable>
      </View>
      <Card style={{ paddingVertical: 4 }}>
        {last.length === 0 ? (
          <Text style={[s.body, { paddingVertical: 12 }]}>No messages yet. Say hello from the Messages tab.</Text>
        ) : (
          last.map((m, i) => {
            const mine = state.live ? m.senderId === me?.id : m.senderRole === state.activeRole;
            return (
              <View key={m.id} style={[s.msg, i > 0 && s.rowRule]}>
                <Text style={s.msgMeta}>
                  {mine ? 'You' : m.senderName.split(' ')[0]} · {relativeTime(m.createdAt)}
                </Text>
                <TranslatedText
                  text={m.text} sourceLang={mine ? myLang : m.sourceLang} targetLang={myLang}
                  style={s.body} numberOfLines={2}
                />
              </View>
            );
          })
        )}
      </Card>
    </View>
  );
}

// ── Quick note (caregiver) ──────────────────────────────────

const TRENDS: { value: Trend; label: string }[] = [
  { value: 'better', label: 'Better' },
  { value: 'same', label: 'Same' },
  { value: 'worse', label: 'Worse' },
];

export function QuickNote({ name }: { name: string }) {
  const { addNote } = useApp();
  const [body, setBody] = useState('');
  const [trend, setTrend] = useState<Trend>('same');
  const [posted, setPosted] = useState(false);

  useEffect(() => {
    if (!posted) return;
    const t = setTimeout(() => setPosted(false), 3000);
    return () => clearTimeout(t);
  }, [posted]);

  const post = () => {
    const text = body.trim();
    if (!text) return;
    const first = text.split(/(?<=[.!?])\s/)[0];
    const title = first.split(/\s+/).slice(0, 7).join(' ').replace(/[.,;:]$/, '');
    addNote({ category: 'general', trend, title, body: text });
    setBody(''); setTrend('same'); setPosted(true);
  };

  return (
    <View style={{ gap: Spacing.sm }}>
      <View style={s.sectionRow}>
        <Text style={s.sectionTitle}>Write a note</Text>
        <Pressable onPress={() => router.push('/(tabs)/notes')} hitSlop={8} accessibilityRole="link">
          <Text style={s.link}>All notes</Text>
        </Pressable>
      </View>
      <Card style={{ gap: 12 }}>
        <TextInput
          value={body}
          onChangeText={setBody}
          multiline
          placeholder={`What did you notice about ${name}? The family reads this in their own language.`}
          placeholderTextColor={Colors.textTertiary}
          accessibilityLabel="Note for the family"
          style={s.noteInput}
        />
        <View style={s.noteFoot}>
          <View style={s.trendRow}>
            {TRENDS.map(t => <Chip key={t.value} label={t.label} selected={trend === t.value} onPress={() => setTrend(t.value)} />)}
          </View>
          <Button label={posted ? 'Posted' : 'Post'} size="sm" disabled={!body.trim() || posted} onPress={post} />
        </View>
      </Card>
    </View>
  );
}

const s = StyleSheet.create({
  tNote: { ...Type.caption, color: Colors.info, fontWeight: '400' },
  sectionRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'baseline', marginTop: Spacing.md, paddingHorizontal: 2 },
  sectionTitle: { fontFamily: 'Fraunces_600SemiBold', fontSize: 18, color: Colors.textStrong },
  link: { ...Type.caption, color: Colors.brown, fontWeight: '700' },
  body: { ...Type.callout, color: Colors.textPrimary, fontWeight: '400', lineHeight: 20 },

  row: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 12 },
  rowRule: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator },
  time: { width: 76, fontSize: 13, fontWeight: '700', color: Colors.textStrong, fontVariant: ['tabular-nums'] },
  rowTitle: { fontSize: 15, fontWeight: '600', color: Colors.textStrong },
  rowStatus: { ...Type.caption, fontWeight: '600', marginTop: 1 },
  box: {
    width: 28, height: 28, borderRadius: 14, borderWidth: 2, borderColor: Colors.border,
    backgroundColor: Colors.surfaceRaised,
  },

  msg: { paddingVertical: 12, gap: 3 },
  msgMeta: { ...Type.caption, color: Colors.textSecondary, fontWeight: '600' },

  noteInput: {
    minHeight: 76, maxHeight: 160, textAlignVertical: 'top', fontSize: 15, lineHeight: 21,
    color: Colors.textPrimary, backgroundColor: Colors.surfaceRaised, borderRadius: Radius.md,
    borderWidth: 1, borderColor: Colors.separator, padding: 12,
  },
  noteFoot: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 8 },
  trendRow: { flexDirection: 'row', gap: 6, flexShrink: 1, flexWrap: 'wrap' },
});
