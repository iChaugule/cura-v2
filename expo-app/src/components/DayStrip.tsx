/**
 * The last 14 days at a glance: one mark per day, coloured by how the day's
 * check-in went. A day with a safety item gets a dark ring. A missing day is an
 * empty outline, because a gap is information too.
 */
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Type } from '../design/tokens';
import type { QuizResponse } from '../models/types';
import { isSameDay } from '../data/quiz';

const DAY = 86_400_000;

export function DayStrip({ quizzes, days = 14 }: { quizzes: QuizResponse[]; days?: number }) {
  const today = new Date();
  today.setHours(12, 0, 0, 0);
  const cells = Array.from({ length: days }, (_, i) => {
    const at = today.getTime() - (days - 1 - i) * DAY;
    const q = quizzes.find(x => isSameDay(x.submittedAt, at));
    return { at, q };
  });
  const tone = (score: number) =>
    score >= 75 ? Colors.positive : score >= 50 ? Colors.caution : Colors.urgent;
  const done = cells.filter(c => c.q).length;

  return (
    <View
      accessible
      accessibilityLabel={`Check-ins on ${done} of the last ${days} days`}
      style={{ gap: 6 }}
    >
      <View style={s.row}>
        {cells.map(({ at, q }) => (
          <View
            key={at}
            style={[
              s.cell,
              q ? { backgroundColor: tone(q.score), borderColor: tone(q.score) } : null,
              q?.redFlags?.length ? s.flagged : null,
            ]}
          />
        ))}
      </View>
      <View style={s.labels}>
        <Text style={s.label}>{new Date(cells[0].at).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}</Text>
        <Text style={s.label}>{done} of {days} days checked in</Text>
        <Text style={s.label}>Today</Text>
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  row: { flexDirection: 'row', gap: 4 },
  cell: { flex: 1, height: 22, borderRadius: 4, borderWidth: 1.5, borderColor: Colors.border, backgroundColor: 'transparent' },
  flagged: { borderColor: Colors.textStrong, borderWidth: 2.5 },
  labels: { flexDirection: 'row', justifyContent: 'space-between' },
  label: { ...Type.caption, fontSize: 11, color: Colors.textTertiary, fontWeight: '400' },
});
