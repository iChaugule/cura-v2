/**
 * Cura pattern engine.
 *
 * Plain, deterministic rules. No AI and no black box: every finding carries the
 * check-ins that caused it, so the family can see exactly why Cura said what it
 * said. The AI layer only ever explains these findings in words; it never
 * invents its own.
 *
 * What it does, in order:
 *   1. Red flags. A single answer that is a safety concern (a fall, severe pain,
 *      unresponsive) is always raised, whatever the history looks like.
 *   2. Baseline. For each area (sleep, fluids, food...) we take the median of
 *      the person's own earlier check-ins. Their normal, not a population normal.
 *   3. Recent vs baseline. The median of the last few check-ins is compared to
 *      the baseline using a robust z-score (median / MAD, so one odd day cannot
 *      drag the baseline around).
 *   4. Gradual drift. A two-sided CUSUM catches a slow slide that no single day
 *      would trigger.
 *   5. Sudden change. A drop of two or more steps within two days is flagged
 *      separately from a gradual one, because it usually needs a faster call.
 *   6. Clusters. Some changes matter more together (low fluids and low food,
 *      sudden confusion with poor sleep). Those are combined into one finding.
 *
 * Cura never diagnoses. Findings describe what changed and suggest who to talk
 * to. They never name a disease, a stage, or a medication change.
 */
import type { QuizResponse } from '../models/types';
import { QUIZ_QUESTIONS } from '../data/quiz';

const DAY = 24 * 3600_000;

/** How many of the newest check-ins count as "recent". */
const RECENT_WINDOW = 3;
/** Check-ins needed before the baseline is trusted. */
const MIN_BASELINE = 5;
const ESTABLISHED_BASELINE = 10;
/** Answers are 0..3, so a MAD of 0 is common. Floor it so z-scores stay sane. */
const MIN_MAD = 0.5;
/**
 * |z| at or above this is a meaningful change. With the MAD floor above, a
 * consistent person moving one full step (say "4-6 glasses" to "less than 3")
 * for three check-ins in a row scores 1.35, so 1.3 means "a sustained
 * one-step change". A single odd day never gets there, because recent is a median.
 */
const Z_THRESHOLD = 1.3;

export type Metric =
  | 'sleep' | 'water' | 'food' | 'mood' | 'mobility' | 'medication' | 'pain' | 'cognition';

export const METRIC_LABEL: Record<Metric, string> = {
  sleep: 'Sleep',
  water: 'Fluids',
  food: 'Food',
  mood: 'Mood',
  mobility: 'Mobility',
  medication: 'Medication',
  pain: 'Comfort',
  cognition: 'Alertness',
};

export type Direction = 'improving' | 'steady' | 'declining';
export type Tier = 'info' | 'monitor' | 'contact' | 'urgent';
export type Confidence = 'low' | 'moderate' | 'high';

export const TIER_LABEL: Record<Tier, string> = {
  info: 'For your information',
  monitor: 'Keep an eye on this',
  contact: 'Talk to the care team',
  urgent: 'Act now',
};

export interface Evidence {
  checkInId: string;
  at: number;
  metric: Metric;
  /** Answer index, 0 (worst) to 3 (best). */
  value: number;
  /** The option text the caregiver picked. */
  answer: string;
}

export interface MetricTrend {
  metric: Metric;
  label: string;
  baseline: number | null;
  recent: number | null;
  /** Robust z-score of recent vs baseline. Negative is worse. */
  z: number | null;
  direction: Direction;
  kind: 'none' | 'gradual' | 'sudden';
  series: { at: number; value: number }[];
}

export interface Finding {
  id: string;
  tier: Tier;
  title: string;
  /** One or two plain sentences on what changed. */
  detail: string;
  /** What to do next. Never medical advice. */
  nextStep: string;
  confidence: Confidence;
  evidence: Evidence[];
  metrics: Metric[];
}

export interface PatternReport {
  /** Overall read for the family. */
  status: Direction | 'not-enough-data';
  headline: string;
  baselineState: 'none' | 'provisional' | 'established';
  checkInCount: number;
  trends: MetricTrend[];
  findings: Finding[];
  generatedAt: number;
}

// ── Small, honest statistics ────────────────────────────────

export function median(values: number[]): number {
  if (!values.length) return 0;
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

/** Median absolute deviation, floored so a very consistent person is not over-flagged. */
export function mad(values: number[], center: number): number {
  return Math.max(median(values.map(v => Math.abs(v - center))), MIN_MAD);
}

/** (x - median) / (1.4826 * MAD). 1.4826 makes MAD comparable to a standard deviation. */
export function robustZ(x: number, center: number, spread: number): number {
  return (x - center) / (1.4826 * spread);
}

/**
 * Two-sided CUSUM. Adds up small deviations from the baseline; if the running
 * total passes the threshold, the series has shifted even if no single day
 * looked alarming. Returns which way it shifted, or null.
 */
export function cusum(
  values: number[], center: number, sigma: number, slack = 0.5, threshold = 3,
): 'up' | 'down' | null {
  const k = slack * sigma;
  const h = threshold * sigma;
  let up = 0;
  let down = 0;
  let result: 'up' | 'down' | null = null;
  for (const x of values) {
    up = Math.max(0, up + (x - center) - k);
    down = Math.max(0, down + (center - x) - k);
    if (up > h) result = 'up';
    if (down > h) result = 'down';
  }
  return result;
}

// ── Engine ──────────────────────────────────────────────────

const METRICS = QUIZ_QUESTIONS.map(q => q.id) as Metric[];

function answerText(metric: Metric, value: number): string {
  return QUIZ_QUESTIONS.find(q => q.id === metric)?.options[value] ?? String(value);
}

function evidenceFor(checkIns: QuizResponse[], metric: Metric): Evidence[] {
  return checkIns
    .filter(c => c.answers[metric] !== undefined)
    .map(c => ({
      checkInId: c.id,
      at: c.submittedAt,
      metric,
      value: c.answers[metric],
      answer: answerText(metric, c.answers[metric]),
    }));
}

function confidenceFor(baselineCount: number, evidenceCount: number): Confidence {
  if (baselineCount >= ESTABLISHED_BASELINE && evidenceCount >= RECENT_WINDOW) return 'high';
  if (baselineCount >= MIN_BASELINE) return 'moderate';
  return 'low';
}

function trendFor(metric: Metric, ordered: QuizResponse[]): MetricTrend {
  const series = ordered
    .filter(c => c.answers[metric] !== undefined)
    .map(c => ({ at: c.submittedAt, value: c.answers[metric] }));
  const base = series.slice(0, Math.max(0, series.length - RECENT_WINDOW)).map(p => p.value);
  const recent = series.slice(-RECENT_WINDOW).map(p => p.value);

  const empty: MetricTrend = {
    metric, label: METRIC_LABEL[metric], baseline: null, recent: null, z: null,
    direction: 'steady', kind: 'none', series,
  };
  if (base.length < MIN_BASELINE || !recent.length) return empty;

  const center = median(base);
  const spread = mad(base, center);
  const recentMedian = median(recent);
  const z = robustZ(recentMedian, center, spread);

  // Sudden: a fall of 2+ steps between consecutive check-ins within ~2 days.
  const last = series.slice(-RECENT_WINDOW - 1);
  let sudden = false;
  for (let i = 1; i < last.length; i++) {
    const drop = last[i - 1].value - last[i].value;
    if (drop >= 2 && last[i].at - last[i - 1].at <= 2.5 * DAY) sudden = true;
  }
  const drift = cusum(series.slice(-ESTABLISHED_BASELINE).map(p => p.value), center, 1.4826 * spread);

  let direction: Direction = 'steady';
  if (z <= -Z_THRESHOLD || drift === 'down' || sudden) direction = 'declining';
  else if (z >= Z_THRESHOLD || drift === 'up') direction = 'improving';

  return {
    metric,
    label: METRIC_LABEL[metric],
    baseline: center,
    recent: recentMedian,
    z,
    direction,
    kind: direction === 'steady' ? 'none' : sudden ? 'sudden' : 'gradual',
    series,
  };
}

/** Advice-free next steps, one per area. */
const NEXT_STEP: Record<Metric, string> = {
  sleep: 'Ask the caregiver what the evenings have been like, and mention the change at the next doctor visit.',
  water: 'Ask the caregiver to offer small drinks more often, and call the care team if they seem drowsy or confused.',
  food: 'Ask what they are leaving on the plate. If it keeps up for a week, mention it to their doctor.',
  mood: 'Ask the caregiver what was happening around the hard moments. Their calming notes may need an update.',
  mobility: 'Ask the caregiver whether anything changed at home, and tell their doctor if walking keeps getting harder.',
  medication: 'Check the medication routine with the caregiver. Do not change doses without their doctor.',
  pain: 'Ask where it hurts and tell their doctor. Pain can be hard for them to describe.',
  cognition: 'A quick change in alertness is worth a call to their doctor, even if everything else looks normal.',
};

/** Clusters: changes that matter more together than alone. */
const CLUSTERS: {
  id: string;
  needs: Metric[];
  anyOf?: Metric[];
  title: string;
  detail: string;
  nextStep: string;
  tier: Tier;
}[] = [
  {
    id: 'fluids-and-food',
    needs: ['water'],
    anyOf: ['food', 'cognition', 'sleep'],
    title: 'Drinking less, alongside another change',
    detail: 'Fluids are below their usual, and so is at least one other area. Changes like this are worth checking together.',
    nextStep: 'Call their care team today and tell them about the drop in fluids and what else changed. If they are hard to wake or breathing differently, call emergency services.',
    tier: 'contact',
  },
  {
    id: 'sudden-confusion',
    needs: ['cognition'],
    anyOf: ['sleep', 'mood', 'pain'],
    title: 'More confused than usual, with other changes',
    detail: 'Alertness dropped along with sleep, mood or comfort. A quick change like this has many possible causes, and a doctor should hear about it.',
    nextStep: 'Call their doctor and describe what changed and when. Cura cannot tell you the cause, and does not try to.',
    tier: 'contact',
  },
  {
    id: 'falls-risk',
    needs: ['mobility'],
    anyOf: ['sleep', 'pain'],
    title: 'Moving less steadily, with poor sleep or pain',
    detail: 'Mobility is down at the same time as sleep or comfort. Tired or sore days are often unsteady days.',
    nextStep: 'Ask the caregiver to stay close on walks and stairs, and tell their doctor about the change.',
    tier: 'monitor',
  },
];

/** Single answers that are always raised. */
const RED_FLAGS: { metric: Metric; value: number; title: string; nextStep: string }[] = [
  {
    metric: 'mobility', value: 0, title: 'Could not get up, or had a fall',
    nextStep: 'If they are hurt, dizzy or cannot get up, call emergency services. Otherwise call the caregiver now.',
  },
  {
    metric: 'pain', value: 0, title: 'Severe pain reported',
    nextStep: 'Call the caregiver and their doctor now. If the pain is sudden or in the chest, call emergency services.',
  },
  {
    metric: 'cognition', value: 0, title: 'Very confused or unresponsive',
    nextStep: 'If they are hard to wake or unresponsive, call emergency services now.',
  },
  {
    metric: 'water', value: 0, title: 'Almost nothing to drink today',
    nextStep: 'Call the caregiver now and keep offering small sips. If they are drowsy or confused, call their care team.',
  },
];

export function analyze(checkIns: QuizResponse[], now = Date.now()): PatternReport {
  // Oldest first is easier to reason about.
  const ordered = [...checkIns].sort((a, b) => a.submittedAt - b.submittedAt);
  const trends = METRICS.map(m => trendFor(m, ordered));
  const baselineCount = Math.max(0, ordered.length - RECENT_WINDOW);
  const baselineState: PatternReport['baselineState'] =
    baselineCount >= ESTABLISHED_BASELINE ? 'established'
      : baselineCount >= MIN_BASELINE ? 'provisional' : 'none';

  const findings: Finding[] = [];
  const recent = ordered.slice(-RECENT_WINDOW);
  /** Areas already explained by a red flag or cluster, so they are not repeated. */
  const covered = new Set<Metric>();

  // 1. Red flags, from the last 48 hours only.
  for (const flag of RED_FLAGS) {
    const hits = ordered.filter(
      c => c.answers[flag.metric] === flag.value && now - c.submittedAt <= 2 * DAY,
    );
    if (hits.length) {
      findings.push({
        id: `red-${flag.metric}`,
        tier: 'urgent',
        title: flag.title,
        detail: `Reported in the check-in on ${dayName(hits[hits.length - 1].submittedAt)}.`,
        nextStep: flag.nextStep,
        confidence: 'high',
        evidence: evidenceFor(hits, flag.metric),
        metrics: [flag.metric],
      });
      covered.add(flag.metric);
    }
  }

  // 2. Clusters. These replace the single-area findings they are built from.
  const declining = new Set(trends.filter(t => t.direction === 'declining').map(t => t.metric));
  for (const c of CLUSTERS) {
    if (!c.needs.every(m => declining.has(m))) continue;
    const extra = (c.anyOf ?? []).filter(m => declining.has(m));
    if (c.anyOf && !extra.length) continue;
    const metrics = [...c.needs, ...extra];
    metrics.forEach(m => covered.add(m));
    findings.push({
      id: `cluster-${c.id}`,
      tier: c.tier,
      title: c.title,
      detail: `${c.detail} ${metrics.map(m => describeTrend(trends.find(t => t.metric === m)!)).join(' ')}`,
      nextStep: c.nextStep,
      confidence: confidenceFor(baselineCount, recent.length),
      evidence: metrics.flatMap(m => evidenceFor(recent, m)),
      metrics,
    });
  }

  // 3. Single-area changes not already part of a cluster.
  for (const t of trends) {
    if (t.direction === 'steady' || covered.has(t.metric)) continue;
    const improving = t.direction === 'improving';
    findings.push({
      id: `trend-${t.metric}`,
      tier: improving ? 'info' : t.kind === 'sudden' ? 'contact' : 'monitor',
      title: improving
        ? `${t.label} is better than usual`
        : t.kind === 'sudden' ? `${t.label} dropped suddenly` : `${t.label} is slowly slipping`,
      detail: describeTrend(t),
      nextStep: improving ? 'Nothing to do. Worth telling the caregiver it was noticed.' : NEXT_STEP[t.metric],
      confidence: confidenceFor(baselineCount, recent.length),
      evidence: evidenceFor(recent, t.metric),
      metrics: [t.metric],
    });
  }

  const order: Tier[] = ['urgent', 'contact', 'monitor', 'info'];
  findings.sort((a, b) => order.indexOf(a.tier) - order.indexOf(b.tier));

  // Overall status.
  let status: PatternReport['status'];
  if (baselineState === 'none' && !findings.some(f => f.tier === 'urgent')) {
    status = 'not-enough-data';
  } else if (findings.some(f => f.tier !== 'info')) {
    status = 'declining';
  } else if (findings.some(f => f.tier === 'info')) {
    status = 'improving';
  } else {
    status = 'steady';
  }

  return {
    status,
    headline: headlineFor(status, findings, ordered.length),
    baselineState,
    checkInCount: ordered.length,
    trends,
    findings,
    generatedAt: now,
  };
}

// ── Words ───────────────────────────────────────────────────

function describeTrend(t: MetricTrend): string {
  if (t.baseline === null || t.recent === null) return '';
  const usual = answerText(t.metric, Math.round(t.baseline)).toLowerCase();
  const lately = answerText(t.metric, Math.round(t.recent)).toLowerCase();
  const span = t.kind === 'sudden' ? 'in the last two days' : `for the last ${RECENT_WINDOW} check-ins`;
  return `${t.label}: usually "${usual}", ${span} "${lately}".`;
}

function headlineFor(status: PatternReport['status'], findings: Finding[], count: number): string {
  switch (status) {
    case 'not-enough-data':
      return `Cura needs about ${MIN_BASELINE + RECENT_WINDOW} daily check-ins to learn what is normal for them. ${count} so far.`;
    case 'steady':
      return 'Holding steady. Nothing has moved away from their usual.';
    case 'improving':
      return `Doing better than usual in ${findings.length === 1 ? 'one area' : `${findings.length} areas`}.`;
    case 'declining': {
      const top = findings[0];
      // The status pill beside the headline already says "Needs attention".
      return `${top.title}.`;
    }
  }
}

function dayName(at: number): string {
  return new Date(at).toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric' });
}
