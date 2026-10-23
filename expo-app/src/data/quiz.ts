/**
 * The daily check-in.
 *
 * Built around the signs that matter most in dementia care, grouped the way a
 * clinician would think about them: memory and thinking, mood and behaviour,
 * daily living and the body, and engagement with people. It opens with a short
 * safety check, because a few changes need a phone call today, not a trend.
 *
 * Every scored question is ordered worst to best, so the answer index doubles
 * as a score (0..3) and feeds the pattern engine's per-person baselines.
 * "Also noticed" items are yes/no observations whose frequency the engine
 * compares week to week.
 *
 * Wording describes what the caregiver saw. It never asks the caregiver to
 * judge a stage or a diagnosis.
 */
import type { CheckInSectionId, QuizQuestion, QuizResponse } from '../models/types';
import { Colors } from '../design/tokens';

export interface CheckInSection {
  id: CheckInSectionId;
  title: string;
  intro: string;
}

export const SECTIONS: CheckInSection[] = [
  { id: 'memory', title: 'Memory and thinking', intro: 'How clear they were today.' },
  { id: 'mood', title: 'Mood and behaviour', intro: 'How they felt and acted, compared with their usual self.' },
  { id: 'daily', title: 'Daily living and body', intro: 'Sleep, eating, moving and personal care.' },
  { id: 'engagement', title: 'Engagement', intro: 'How connected they were with people and things around them.' },
];

/** Asked first. A "yes" to any of these is raised straight away. */
export const RED_FLAG_ITEMS: { id: string; label: string; detail: string }[] = [
  {
    id: 'rf_confusion',
    label: 'Suddenly much more confused than a day or two ago',
    detail: 'A sharp change over hours or a couple of days, not their usual ups and downs.',
  },
  {
    id: 'rf_swallow',
    label: 'Coughing, choking or holding food in their cheeks while eating',
    detail: 'Including a wet or gurgly voice after drinking.',
  },
  { id: 'rf_fall', label: 'A fall, or a near fall', detail: 'Even if they seemed fine afterwards.' },
  { id: 'rf_drowsy', label: 'Very hard to wake, or drowsy most of the day', detail: 'More than their normal naps.' },
  { id: 'rf_refused', label: 'Refused almost all food or drink today', detail: 'Not just a smaller appetite.' },
];

export const QUIZ_QUESTIONS: QuizQuestion[] = [
  // ── Memory and thinking ──
  {
    id: 'cognition',
    section: 'memory',
    icon: 'bulb-outline',
    prompt: 'How clear and engaged were they in conversation?',
    helper: 'Recognising people, following what was said.',
    options: ['Very confused or unresponsive', 'More confused than usual', 'About their normal', 'Clear and engaged'],
  },
  {
    id: 'orientation',
    section: 'memory',
    icon: 'compass-outline',
    prompt: 'Did they know where they were and roughly what time of day it was?',
    helper: 'At home, in their own rooms.',
    options: ['Lost, even at home', 'Confused about time or place several times', 'Unsure once or twice', 'Oriented all day'],
  },
  // ── Mood and behaviour ──
  {
    id: 'mood',
    section: 'mood',
    icon: 'happy-outline',
    prompt: 'How was their mood overall?',
    helper: 'Compared with their usual self.',
    options: ['Very distressed or agitated', 'Low, anxious or irritable', 'Settled with some ups and downs', 'Calm and content'],
  },
  // ── Daily living and body ──
  {
    id: 'sleep',
    section: 'daily',
    icon: 'moon-outline',
    prompt: 'How did they sleep last night?',
    helper: 'Count naps only if they replaced night sleep.',
    options: ['Barely slept, up most of the night', 'Restless, woke often', 'Woke once or twice', 'Slept through'],
  },
  {
    id: 'food',
    section: 'daily',
    icon: 'restaurant-outline',
    prompt: 'How much of their meals did they eat?',
    helper: 'Across the day.',
    options: ['Refused most meals', 'Only a few bites', 'About half', 'Most or all of it'],
  },
  {
    id: 'water',
    section: 'daily',
    icon: 'water-outline',
    prompt: 'How much did they drink?',
    helper: 'Water, tea, juice, soup: anything fluid.',
    options: ['Almost nothing', 'Less than 3 glasses', 'About 4 to 6 glasses', '7 or more glasses'],
  },
  {
    id: 'mobility',
    section: 'daily',
    icon: 'walk-outline',
    prompt: 'How steady were they on their feet?',
    helper: 'Walking, standing up, getting in and out of bed.',
    options: ['Could not get up, or fell', 'Needed a lot of help', 'Moved with their usual support', 'Steady and active'],
  },
  {
    id: 'selfcare',
    section: 'daily',
    icon: 'shirt-outline',
    prompt: 'How much help did they need with washing, dressing and the toilet?',
    helper: 'Compared with what they can usually do.',
    options: ['Could not take part, even with help', 'Needed hands-on help throughout', 'Needed reminders or one step at a time', 'Managed as usual'],
  },
  {
    id: 'medication',
    section: 'daily',
    icon: 'medkit-outline',
    prompt: 'Were medicines taken as prescribed?',
    helper: 'Right medicine, right time.',
    options: ['Missed most doses', 'Missed one dose', 'All taken, some late', 'All taken on time'],
  },
  {
    id: 'pain',
    section: 'daily',
    icon: 'pulse-outline',
    prompt: 'Any pain or discomfort?',
    helper: 'Including wincing, guarding or new aches they mentioned.',
    options: ['Severe pain', 'Noticeable pain at times', 'Mild and manageable', 'None noticed'],
  },
  // ── Engagement ──
  {
    id: 'engagement',
    section: 'engagement',
    icon: 'people-outline',
    prompt: 'How interested were they in people and activities?',
    helper: 'Conversation, TV, music, hobbies, visitors.',
    options: ['Withdrawn, would not engage', 'Mostly flat or uninterested', 'Some interest at times', 'Interested as usual'],
  },
];

/** "Also noticed today" items, from the common signs of change in dementia. */
export const OBSERVATIONS: { id: string; section: CheckInSectionId; short: string; label: string }[] = [
  { id: 'repeat_questions', section: 'memory', short: 'Repeated questions', label: 'Asked the same question many times' },
  { id: 'word_finding', section: 'memory', short: 'Trouble finding words', label: 'Struggled to find words, or used the wrong word' },
  { id: 'misplaced', section: 'memory', short: 'Misplacing things', label: 'Put things in unusual places' },
  { id: 'spatial', section: 'memory', short: 'Misjudging distances', label: 'Misjudged distances or bumped into things' },

  { id: 'sundowning', section: 'mood', short: 'Evening restlessness', label: 'More confused or restless in the late afternoon or evening' },
  { id: 'paranoia', section: 'mood', short: 'Believing untrue things', label: 'Believed something untrue, like someone stealing from them' },
  { id: 'mood_swings', section: 'mood', short: 'Sudden mood swings', label: 'Sudden mood swings without a clear reason' },
  { id: 'disinhibition', section: 'mood', short: 'Out-of-character behaviour', label: 'Said or did something very out of character' },
  { id: 'shadowing', section: 'mood', short: 'Following the caregiver', label: 'Followed the caregiver from room to room' },
  { id: 'hiding', section: 'mood', short: 'Hiding or hoarding', label: 'Hid or hoarded things' },

  { id: 'unsteady', section: 'daily', short: 'Unsteady walking', label: 'Shuffled, dragged a foot or tripped' },
  { id: 'fine_motor', section: 'daily', short: 'Trouble with small tasks', label: 'Trouble with buttons, cutlery or opening things' },
  { id: 'incontinence', section: 'daily', short: 'Bladder or bowel accidents', label: 'New or more bladder or bowel accidents' },
  { id: 'night_waking', section: 'daily', short: 'Waking at night', label: 'Awake or wandering at night' },
  { id: 'forgot_how', section: 'daily', short: 'Forgetting familiar actions', label: 'Forgot how to do a familiar action, like using a cup' },
  { id: 'sweet_only', section: 'daily', short: 'Changes in eating', label: 'Forgot to eat, or only wanted sweet foods' },

  { id: 'avoided_people', section: 'engagement', short: 'Avoiding people', label: 'Avoided visitors or family calls' },
  { id: 'overwhelmed', section: 'engagement', short: 'Upset by busy places', label: 'Upset by noise, crowds or busy rooms' },
  { id: 'indifferent', section: 'engagement', short: 'Less aware of others', label: 'Seemed unaware of other people\'s feelings' },
];

export const MAX_OPTION_INDEX = 3;

/** 0–100, where 100 is every answer at its best option. */
export function computeScore(answers: Record<string, number>): number {
  const ids = QUIZ_QUESTIONS.map(q => q.id).filter(id => answers[id] !== undefined);
  if (!ids.length) return 0;
  const total = ids.reduce((sum, id) => sum + answers[id], 0);
  return Math.round((total / (ids.length * MAX_OPTION_INDEX)) * 100);
}

export function scoreLabel(score: number): string {
  if (score >= 85) return 'A good day';
  if (score >= 65) return 'Mostly steady';
  if (score >= 45) return 'Some concerns';
  return 'A hard day';
}

export function scoreTone(score: number): { fg: string; bg: string } {
  if (score >= 75) return { fg: Colors.positive, bg: Colors.positiveSoft };
  if (score >= 50) return { fg: Colors.caution, bg: Colors.cautionSoft };
  return { fg: Colors.urgent, bg: Colors.urgentSoft };
}

/** The answers that dragged a check-in down, worst first. */
export function weakestAreas(response: QuizResponse, limit = 3) {
  return QUIZ_QUESTIONS
    .filter(q => response.answers[q.id] !== undefined && response.answers[q.id] < 2)
    .sort((a, b) => response.answers[a.id] - response.answers[b.id])
    .slice(0, limit)
    .map(q => ({ question: q, answerIndex: response.answers[q.id] }));
}

/** Difference between the newest check-in and the one before it. */
export function scoreDelta(quizzes: QuizResponse[]): number | null {
  if (quizzes.length < 2) return null;
  return quizzes[0].score - quizzes[1].score;
}

export function isSameDay(a: number, b: number): boolean {
  const d1 = new Date(a);
  const d2 = new Date(b);
  return (
    d1.getFullYear() === d2.getFullYear() &&
    d1.getMonth() === d2.getMonth() &&
    d1.getDate() === d2.getDate()
  );
}

export const observationLabel = (id: string) => OBSERVATIONS.find(o => o.id === id)?.label ?? id;
export const observationShort = (id: string) => OBSERVATIONS.find(o => o.id === id)?.short ?? id;
export const redFlagLabel = (id: string) => RED_FLAG_ITEMS.find(o => o.id === id)?.label ?? id;
