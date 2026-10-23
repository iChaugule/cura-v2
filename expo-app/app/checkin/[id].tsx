/**
 * One check-in, read-only, laid out by section. What the family opens from
 * "View" on Home.
 */
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useLocalSearchParams } from 'expo-router';
import { ScreenHeader } from '../../src/components/ScreenHeader';
import { EmptyState } from '../../src/components/ui';
import { Colors, Radius, Spacing, Type } from '../../src/design/tokens';
import { OBSERVATIONS, QUIZ_QUESTIONS, RED_FLAG_ITEMS, SECTIONS } from '../../src/data/quiz';
import { useApp } from '../../src/state/AppContext';

export default function CheckInDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { state } = useApp();
  const q = state.quizzes.find(x => x.id === id);
  const name = state.pnc?.preferredName ?? 'them';

  if (!q) {
    return (
      <SafeAreaView style={s.safe} edges={['top']}>
        <ScreenHeader title="Check-in" />
        <EmptyState title="Check-in not found" body="It may have been removed." />
      </SafeAreaView>
    );
  }

  const when = new Date(q.submittedAt);
  const flags = RED_FLAG_ITEMS.filter(r => q.redFlags?.includes(r.id));

  return (
    <SafeAreaView style={s.safe} edges={['top']}>
      <ScreenHeader
        title={`${name}, ${when.toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric' })}`}
        subtitle={`By ${q.submittedByName} at ${when.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })}`}
      />
      <ScrollView contentContainerStyle={s.scroll}>
        <View style={[s.block, flags.length ? { backgroundColor: Colors.urgentSoft, borderColor: Colors.urgentSoft } : null]}>
          <Text style={s.blockTitle}>Safety check</Text>
          {flags.length ? flags.map(f => (
            <Text key={f.id} style={[s.line, { color: Colors.urgent, fontWeight: '700' }]}>{f.label}</Text>
          )) : <Text style={s.line}>None of the warning signs happened.</Text>}
        </View>

        {SECTIONS.map(sec => {
          const qs = QUIZ_QUESTIONS.filter(x => x.section === sec.id && q.answers[x.id] !== undefined);
          const seen = OBSERVATIONS.filter(o => o.section === sec.id && q.observed?.includes(o.id));
          if (!qs.length && !seen.length) return null;
          return (
            <View key={sec.id} style={s.block}>
              <Text style={s.blockTitle}>{sec.title}</Text>
              {qs.map(x => (
                <View key={x.id} style={s.row}>
                  <Text style={s.q}>{x.prompt}</Text>
                  <Text style={[s.a, q.answers[x.id] <= 1 && { color: Colors.caution }]}>{x.options[q.answers[x.id]]}</Text>
                </View>
              ))}
              {seen.length ? (
                <View style={{ gap: 4, marginTop: 6 }}>
                  <Text style={s.small}>ALSO NOTICED</Text>
                  {seen.map(o => <Text key={o.id} style={s.line}>{o.label}</Text>)}
                </View>
              ) : null}
            </View>
          );
        })}

        {q.freeText ? (
          <View style={s.block}>
            <Text style={s.blockTitle}>Note for the family</Text>
            <Text style={s.line}>{q.freeText}</Text>
          </View>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { padding: Spacing.md, gap: Spacing.sm, paddingBottom: Spacing.xxl, maxWidth: 680, width: '100%', alignSelf: 'center' },
  block: {
    backgroundColor: Colors.surface, borderRadius: Radius.lg, padding: Spacing.md, gap: 8,
    borderWidth: StyleSheet.hairlineWidth * 2, borderColor: Colors.separator,
  },
  blockTitle: { fontFamily: 'Fraunces_600SemiBold', fontSize: 17, color: Colors.textStrong },
  row: { gap: 2, paddingVertical: 4 },
  q: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  a: { ...Type.callout, color: Colors.textStrong, fontWeight: '700' },
  line: { ...Type.callout, color: Colors.textPrimary, fontWeight: '400' },
  small: { ...Type.overline, fontSize: 10, color: Colors.textSecondary },
});
