/**
 * The daily check-in. Lives on the home screen for both roles and feeds the
 * chatbot, the home digest and the trend line on the notes tab.
 *
 * Options are always ordered worst → best so the index doubles as a score.
 */
import type { QuizQuestion, QuizResponse } from '../models/types';
import { Colors } from '../design/tokens';

export const QUIZ_QUESTIONS: QuizQuestion[] = [
  {
    id: 'sleep',
    icon: 'moon-outline',
    prompt: 'How did they sleep last night?',
    helper: 'Include naps only if they replaced night sleep.',
    options: ['Barely slept / up all night', 'Restless, woke often', 'Slept but woke once or twice', 'Slept soundly through'],
  },
  {
    id: 'water',
    icon: 'water-outline',
    prompt: 'How much did they drink today?',
    helper: 'Water, chai, juice, soup: anything fluid.',
    options: ['Almost nothing', 'Less than 3 glasses', 'About 4–6 glasses', '7+ glasses, well hydrated'],
  },
  {
    id: 'food',
    icon: 'restaurant-outline',
    prompt: 'How much of their meals did they eat?',
    helper: 'Across breakfast, lunch and dinner.',
    options: ['Refused most meals', 'Only a few bites', 'About half of each meal', 'Finished most meals'],
  },
  {
    id: 'mood',
    icon: 'happy-outline',
    prompt: 'How has their mood been?',
    helper: 'Compared with their usual self.',
    options: ['Very distressed or agitated', 'Low, withdrawn or anxious', 'Settled with some ups and downs', 'Calm and cheerful'],
  },
  {
    id: 'mobility',
    icon: 'walk-outline',
    prompt: 'How were they moving around?',
    helper: 'Walking, standing, transfers.',
    options: ['Could not get up / a fall today', 'Needed a lot of help', 'Moved with usual support', 'Steady and active'],
  },
  {
    id: 'medication',
    icon: 'medkit-outline',
    prompt: 'Were medications taken as prescribed?',
    helper: 'Right medicine, right time.',
    options: ['Missed most doses', 'Missed one dose', 'All taken, some late', 'All taken on time'],
  },
  {
    id: 'pain',
    icon: 'pulse-outline',
    prompt: 'Any pain or discomfort?',
    helper: 'Including new aches they mentioned.',
    options: ['Severe pain', 'Noticeable pain at times', 'Mild, manageable discomfort', 'No pain reported'],
  },
  {
    id: 'cognition',
    icon: 'bulb-outline',
    prompt: 'How clear and engaged were they?',
    helper: 'Recognising people, following conversation.',
    options: ['Very confused or unresponsive', 'More confused than usual', 'About their normal', 'Alert and engaged'],
  },
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
  if (score >= 85) return 'Doing well';
  if (score >= 65) return 'Mostly steady';
  if (score >= 45) return 'Some concerns';
  if (score >= 25) return 'Needs attention';
  return 'Needs attention now';
}

export function scoreTone(score: number): { fg: string; bg: string } {
  if (score >= 75) return { fg: Colors.positive, bg: Colors.positiveSoft };
  if (score >= 50) return { fg: Colors.caution, bg: Colors.cautionSoft };
  return { fg: Colors.urgent, bg: Colors.urgentSoft };
}

/** The answers that dragged a check-in down, worst first. */
export function weakestAreas(response: QuizResponse, limit = 3) {
  return QUIZ_QUESTIONS
    .filter(q => response.answers[q.id] !== undefined && response.answers[q.id] < MAX_OPTION_INDEX)
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
