/**
 * Shows what the pattern engine found, with the receipts.
 *
 * Every finding can be opened to see exactly which check-ins caused it, the
 * answer given on each day, and how confident Cura is. Nothing is hidden behind
 * a score.
 */
import { useState } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { Colors, Radius, Spacing, Type } from '../design/tokens';
import { METRIC_LABEL, TIER_LABEL, type Finding, type PatternReport, type Tier } from '../engine/patterns';
import { Card } from './ui';

export const TierColors: Record<Tier, { fg: string; bg: string }> = {
  urgent: { fg: Colors.urgent, bg: Colors.urgentSoft },
  contact: { fg: Colors.caution, bg: Colors.cautionSoft },
  monitor: { fg: Colors.textStrong, bg: Colors.surfaceTinted },
  info: { fg: Colors.positive, bg: Colors.positiveSoft },
};

export const StatusLabel: Record<PatternReport['status'], { label: string; fg: string; bg: string }> = {
  steady: { label: 'Steady', fg: Colors.textStrong, bg: Colors.surfaceTinted },
  improving: { label: 'Improving', fg: Colors.positive, bg: Colors.positiveSoft },
  declining: { label: 'Needs attention', fg: Colors.urgent, bg: Colors.urgentSoft },
  'not-enough-data': { label: 'Learning', fg: Colors.textSecondary, bg: Colors.surfaceTinted },
};

const CONFIDENCE_TEXT = {
  low: 'Low confidence. Cura has only a few days of history to compare against.',
  moderate: 'Moderate confidence. Based on about a week of history.',
  high: 'High confidence. Based on two weeks or more of history.',
} as const;

export function FindingList({ report, name }: { report: PatternReport; name: string }) {
  if (report.status === 'not-enough-data') {
    return (
      <Card style={s.empty}>
        <Text style={s.emptyTitle}>Still learning {name}&apos;s normal</Text>
        <Text style={s.emptyBody}>{report.headline}</Text>
        <Text style={s.emptyBody}>
          Until then, every check-in still shows up in the history, and anything urgent (a fall, severe pain) is
          raised straight away.
        </Text>
      </Card>
    );
  }
  if (!report.findings.length) {
    return (
      <Card style={s.empty}>
        <Text style={s.emptyTitle}>Nothing has changed</Text>
        <Text style={s.emptyBody}>
          Sleep, fluids, food, mood, mobility, medication, comfort and alertness are all within {name}&apos;s
          usual range over the last {report.checkInCount} check-ins.
        </Text>
      </Card>
    );
  }
  return (
    <View style={{ gap: Spacing.sm }}>
      {report.findings.map(f => <FindingCard key={f.id} finding={f} />)}
    </View>
  );
}

function FindingCard({ finding }: { finding: Finding }) {
  const [open, setOpen] = useState(finding.tier === 'urgent');
  const tone = TierColors[finding.tier];
  return (
    <Card style={s.card}>
      <Pressable
        onPress={() => setOpen(o => !o)}
        accessibilityRole="button"
        accessibilityState={{ expanded: open }}
        accessibilityLabel={`${TIER_LABEL[finding.tier]}: ${finding.title}`}
        accessibilityHint={open ? 'Hides the check-ins behind this' : 'Shows the check-ins behind this'}
        style={{ gap: 6 }}
      >
        <Text style={[s.tier, { color: tone.fg }]}>{TIER_LABEL[finding.tier].toUpperCase()}</Text>
        <Text style={s.title}>{finding.title}</Text>
        <Text style={s.body}>{finding.detail}</Text>
        <View style={[s.next, { backgroundColor: tone.bg }]}>
          <Text style={[s.nextLabel, { color: tone.fg }]}>What to do</Text>
          <Text style={s.nextText}>{finding.nextStep}</Text>
        </View>
        <Text style={s.toggle}>{open ? 'Hide the check-ins behind this' : `Show the ${finding.evidence.length} check-in answers behind this`}</Text>
      </Pressable>

      {open ? (
        <View style={s.evidence}>
          {finding.evidence.map(e => (
            <View key={`${e.checkInId}-${e.metric}`} style={s.evRow}>
              <Text style={s.evDate}>
                {new Date(e.at).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' })}
              </Text>
              <Text style={s.evText}>
                <Text style={{ fontWeight: '700' }}>{METRIC_LABEL[e.metric]}:</Text>{' '}
                {e.answer}
              </Text>
            </View>
          ))}
          <Text style={s.confidence}>{CONFIDENCE_TEXT[finding.confidence]}</Text>
        </View>
      ) : null}
    </Card>
  );
}

const s = StyleSheet.create({
  card: { gap: 10 },
  tier: { ...Type.overline, fontSize: 10 },
  title: { ...Type.subhead, color: Colors.textStrong },
  body: { ...Type.callout, fontWeight: '400', color: Colors.textPrimary },
  next: { borderRadius: Radius.sm, padding: 10, gap: 2, marginTop: 2 },
  nextLabel: { ...Type.caption, fontWeight: '700' },
  nextText: { ...Type.callout, fontWeight: '400', color: Colors.textStrong },
  toggle: { ...Type.caption, color: Colors.brown, fontWeight: '700', paddingTop: 4 },
  evidence: {
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator,
    paddingTop: 10, gap: 6,
  },
  evRow: { flexDirection: 'row', gap: 10 },
  evDate: { ...Type.caption, color: Colors.textSecondary, width: 86 },
  evText: { ...Type.caption, color: Colors.textPrimary, flex: 1, fontWeight: '400' },
  confidence: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', marginTop: 4 },
  empty: { gap: 6 },
  emptyTitle: { ...Type.subhead, color: Colors.textStrong },
  emptyBody: { ...Type.callout, fontWeight: '400', color: Colors.textSecondary },
});
