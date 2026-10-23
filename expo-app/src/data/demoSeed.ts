/**
 * Demo mode.
 *
 * Builds a complete, believable account — family member, caregiver, an accepted
 * engagement, a week of notes, check-ins and messages — so the whole product can
 * be walked through without signing anyone up. Delete this file and the
 * `demoMode` flag when real accounts land.
 */
import type {
  Account, CareInvite, CareNote, ChatMessage, Pnc, QuizResponse,
} from '../models/types';
import { computeScore } from './quiz';

const HOUR = 3600_000;
const DAY = 24 * HOUR;

export interface DemoSeed {
  family: Account;
  caregiver: Account;
  pnc: Pnc;
  invites: CareInvite[];
  notes: CareNote[];
  quizzes: QuizResponse[];
  messages: ChatMessage[];
}

export function buildDemoSeed(): DemoSeed {
  const now = Date.now();

  const family: Account = {
    id: 'acct-family-demo',
    role: 'family',
    name: 'Raj Rao',
    email: 'raj.rao@example.com',
    phone: '+91 98200 11234',
    language: 'en',
    relationship: 'Grandson',
  };

  const caregiver: Account = {
    id: 'acct-caregiver-demo',
    role: 'caregiver',
    name: 'Priya Sharma',
    email: 'priya.sharma@example.com',
    phone: '+91 98765 44321',
    language: 'mr',
  };

  const pnc: Pnc = {
    id: 'pnc-demo',
    fullName: 'Meena Rao',
    preferredName: 'Aaji',
    age: 83,
    pronouns: 'she/her',
    address: 'Flat 4B, Sahyadri Apartments, Shivaji Nagar, Pune 411005',
    location: { lat: 18.5308, lng: 73.8475 },
    conditions: ["Moderate Alzheimer's", 'Hypertension', 'Osteoarthritis (knees)'],
    mobility: 'Walks short distances with a walker. High fall risk on hard floors. Needs a hand on stairs.',
    diet: 'Soft vegetarian food. Low salt. Prefers dal rice, idli, and cardamom chai. Small frequent meals work best.',
    languages: ['Marathi', 'Hindi'],
    medications: [
      { id: 'med-1', name: 'Amlodipine', dose: '5 mg', schedule: 'Once daily, after breakfast' },
      { id: 'med-2', name: 'Donepezil', dose: '5 mg', schedule: 'Once daily, at bedtime' },
      { id: 'med-3', name: 'Calcium + Vitamin D3', dose: '1 tablet', schedule: 'Once daily, after lunch' },
    ],
    allergies: 'Sulfa drugs, causes rash',
    emergencyContact: 'Raj Rao (grandson)',
    emergencyPhone: '+91 98200 11234',
    routine:
      'Wakes around 6:30 with chai. Morning walk in the corridor before it gets hot. Lunch at 1, then a nap. ' +
      'Restless from about 5pm. Evening prayer at 7 settles her. In bed by 9.',
    calmingNotes:
      'Speak Marathi, slowly, and use her name. Never correct or argue. Agree and redirect. ' +
      'Chai and sitting quietly beside her works almost always. The family photo album is the reliable fallback. ' +
      'She may not recognise you each day, so introduce yourself gently every time.',
    careHoursPerDay: 6,
  };

  const invites: CareInvite[] = [
    {
      id: 'invite-demo-1',
      caregiverId: 'cg-priya',
      caregiverName: 'Priya Sharma',
      familyName: family.name,
      pncName: pnc.preferredName,
      startDate: new Date(now - 21 * DAY).toISOString().slice(0, 10),
      scheduleSummary: 'Mon–Sat, 8:00 AM – 2:00 PM',
      hoursPerDay: 6,
      hourlyRate: 320,
      daysPerWeek: 6,
      message: 'Aaji needs someone patient who speaks Marathi. Mornings are her best time.',
      status: 'accepted',
      createdAt: now - 22 * DAY,
      respondedAt: now - 21 * DAY - 4 * HOUR,
      payment: {
        id: 'pay-demo-1',
        method: 'Visa •••• 4242',
        weeklyTotal: 320 * 6 * 6,
        platformFee: Math.round(320 * 6 * 6 * 0.08),
        status: 'captured',
        authorizedAt: now - 22 * DAY,
        capturedAt: now - 21 * DAY - 4 * HOUR,
      },
    },
  ];

  const note = (
    n: number,
    daysAgo: number,
    atHour: number,
    category: CareNote['category'],
    trend: CareNote['trend'],
    title: string,
    body: string,
    comments: CareNote['comments'] = [],
  ): CareNote => ({
    id: `note-demo-${n}`,
    authorId: caregiver.id,
    authorName: caregiver.name,
    authorRole: 'caregiver',
    createdAt: now - daysAgo * DAY + atHour * HOUR,
    category,
    trend,
    title,
    body,
    comments,
  });

  const notes: CareNote[] = [
    note(
      1, 0, -2, 'hydration', 'worse',
      'Drinking less for the third day',
      'Aaji has only taken about 500 ml today by 2pm, mostly chai. She waves away water and says she is not thirsty. ' +
      'I switched to diluted coconut water and small glasses every half hour, which she accepts more readily. ' +
      'Third day in a row under her usual amount.',
      [
        {
          id: 'nc-1',
          authorId: family.id,
          authorName: family.name,
          authorRole: 'family',
          body: 'Thank you for flagging this. She has always hated plain water. Should I bring buttermilk when I visit on Sunday?',
          createdAt: now - 1 * HOUR,
        },
      ],
    ),
    note(
      2, 0, -4, 'mood', 'same',
      'Calm morning, asked about Raj twice',
      'Good mood on waking. She asked where Raj was twice before 10am. I showed her the photo album and she settled straight away and told me the story about his first day of school again.',
    ),
    note(
      3, 1, -5, 'mobility', 'better',
      'Walked 12 minutes, longest this week',
      'Corridor walk with the walker, 12 minutes without needing to sit. Steady, no wobble at the turn. She said the morning light was nice. This is up from 6–7 minutes earlier in the week.',
      [
        {
          id: 'nc-2',
          authorId: family.id,
          authorName: family.name,
          authorRole: 'family',
          body: 'That is wonderful. She used to walk to the market every morning, glad she is getting some of that back.',
          createdAt: now - 1 * DAY - 2 * HOUR,
        },
      ],
    ),
    note(
      4, 2, -6, 'appetite', 'worse',
      'Left half her lunch',
      'She ate the rice but pushed the sabzi away and said it tasted like nothing. Finished about half the plate. Breakfast was normal. I will try making it a little more flavourful tomorrow within the low-salt limit.',
    ),
    note(
      5, 3, -7, 'medication', 'same',
      'All doses on time, no refusals',
      'Amlodipine after breakfast, calcium after lunch, donepezil at bedtime. She takes them with a small biscuit without any fuss now that we have the routine.',
    ),
    note(
      6, 4, -8, 'sleep', 'worse',
      'Up twice in the night, restless from 5pm',
      'The family reported she was up at 1am and again at 4am looking for her mother. Evening restlessness started earlier than usual, around 4:30pm. Marathi bhajans on low volume helped after about twenty minutes.',
      [
        {
          id: 'nc-3',
          authorId: family.id,
          authorName: family.name,
          authorRole: 'family',
          body: 'We heard her too. Is this the sundowning you mentioned? Anything we can do differently in the evening?',
          createdAt: now - 4 * DAY - 6 * HOUR,
        },
        {
          id: 'nc-4',
          authorId: caregiver.id,
          authorName: caregiver.name,
          authorRole: 'caregiver',
          body: 'Yes, this is typical sundowning. Keeping the lights on before dusk and closing the curtains early usually helps. I will start doing that at 4pm.',
          createdAt: now - 4 * DAY - 5 * HOUR,
        },
      ],
    ),
    note(
      7, 6, -9, 'cognition', 'same',
      'Recognised me straight away today',
      'She used my name without prompting, which is not every day. Followed a full conversation about the neighbours. No new confusion.',
    ),
  ];

  const quiz = (
    n: number,
    daysAgo: number,
    answers: Record<string, number>,
    freeText = '',
    insight?: string,
  ): QuizResponse => ({
    id: `quiz-demo-${n}`,
    submittedAt: now - daysAgo * DAY - 3 * HOUR,
    submittedByRole: 'caregiver',
    submittedByName: caregiver.name,
    answers,
    freeText,
    score: computeScore(answers),
    aiInsight: insight,
  });

  // Three weeks of daily check-ins. The first 18 days are her normal (with the
  // small ups and downs real days have). In the last three, fluids and food
  // slip while walking improves, which is the story the notes tell too.
  const usual = { sleep: 2, water: 2, food: 3, mood: 2, mobility: 2, medication: 3, pain: 2, cognition: 2 };
  const wobble: Record<number, Partial<typeof usual>> = {
    20: { sleep: 3 }, 18: { mood: 3 }, 17: { food: 2 }, 15: { sleep: 1 }, 13: { water: 3 },
    12: { mood: 1 }, 10: { pain: 3 }, 9: { food: 2 }, 7: { sleep: 3, cognition: 3 }, 5: { mood: 3 }, 4: { sleep: 1, mood: 1 },
  };
  const lastDays: Record<number, Partial<typeof usual>> = {
    2: { water: 1, food: 2, mobility: 3, pain: 1 },
    1: { water: 1, food: 2, mobility: 3, mood: 3 },
    0: { water: 1, food: 2, mobility: 3 },
  };
  const quizzes: QuizResponse[] = [];
  for (let d = 0; d <= 20; d++) {
    const answers = { ...usual, ...(wobble[d] ?? {}), ...(lastDays[d] ?? {}) };
    quizzes.push(quiz(21 - d, d, answers));
  }

  const msg = (
    n: number,
    from: 'family' | 'caregiver',
    text: string,
    sourceLang: string,
    hoursAgo: number,
    translations: Record<string, string> = {},
  ): ChatMessage => ({
    id: `msg-demo-${n}`,
    senderId: from === 'family' ? family.id : caregiver.id,
    senderName: from === 'family' ? family.name : caregiver.name,
    senderRole: from,
    text,
    sourceLang,
    translations,
    createdAt: now - hoursAgo * HOUR,
  });

  const messages: ChatMessage[] = [
    msg(1, 'caregiver', 'नमस्कार! मी आत्ताच पोहोचले. आजी उठल्या आहेत आणि चहा मागत आहेत.', 'mr', 30, {
      en: 'Hello! I have just arrived. Aaji is awake and asking for her chai.',
    }),
    msg(2, 'family', 'That is a good sign. How did she sleep last night?', 'en', 29, {
      mr: 'ही चांगली गोष्ट आहे. काल रात्री त्यांची झोप कशी झाली?',
    }),
    msg(3, 'caregiver', 'रात्री दोनदा उठल्या, पण पुन्हा लवकर झोपल्या. सकाळी शांत आहेत.', 'mr', 28, {
      en: 'She woke twice in the night but went back to sleep quickly. She is calm this morning.',
    }),
    msg(4, 'family', 'Thank you Priya. Please keep offering her fluids, I saw your note about it.', 'en', 26, {
      mr: 'धन्यवाद प्रिया. कृपया त्यांना पाणी देत राहा, मी तुमची नोंद वाचली.',
    }),
    msg(5, 'caregiver', 'हो, दर अर्ध्या तासाने थोडं थोडं देत आहे. नारळपाणी त्या जास्त घेतात.', 'mr', 25, {
      en: 'Yes, I am giving small amounts every half hour. She takes coconut water more willingly.',
    }),
    msg(6, 'family', 'Perfect. I will bring buttermilk on Sunday, she always liked that.', 'en', 4, {
      mr: 'छान. मी रविवारी ताक आणेन, त्यांना ते नेहमी आवडायचं.',
    }),
    msg(7, 'caregiver', 'उत्तम कल्पना. आज दुपारी त्या १२ मिनिटे चालल्या, या आठवड्यातील सर्वात जास्त.', 'mr', 2, {
      en: 'Great idea. She walked for 12 minutes this afternoon, the longest this week.',
    }),
  ];

  return { family, caregiver, pnc, invites, notes, quizzes, messages };
}

/**
 * A caregiver signing up outside demo mode still needs something in their
 * inbox, so they can see what accepting an invite looks like.
 */
export function pendingInviteForNewCaregiver(caregiverId: string, caregiverName: string): CareInvite {
  const now = Date.now();
  const rate = 320;
  const hours = 6;
  const days = 6;
  return {
    id: `invite-${now}`,
    caregiverId,
    caregiverName,
    familyName: 'Raj Rao',
    pncName: 'Aaji',
    startDate: new Date(now + 2 * DAY).toISOString().slice(0, 10),
    scheduleSummary: 'Mon–Sat, 8:00 AM – 2:00 PM',
    hoursPerDay: hours,
    hourlyRate: rate,
    daysPerWeek: days,
    message:
      'My grandmother Meena (we call her Aaji) is 83 and has moderate Alzheimer\'s. ' +
      'She needs someone patient who speaks Marathi. Mornings are her best time.',
    status: 'pending',
    createdAt: now - 2 * HOUR,
    payment: {
      id: `pay-${now}`,
      method: 'Visa •••• 4242',
      weeklyTotal: rate * hours * days,
      platformFee: Math.round(rate * hours * days * 0.08),
      status: 'authorized',
      authorizedAt: now - 2 * HOUR,
    },
  };
}
