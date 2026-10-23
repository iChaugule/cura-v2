/**
 * The single source of truth for the whole app.
 *
 * Two ways to run:
 *   Live  (Supabase configured): you sign in as one real person. Your care
 *         circle, invites, notes, check-ins and messages come from the database
 *         and update live as other people in the circle add to them.
 *   Demo  ("Open demo"): a sample family and caregiver on one phone, saved only
 *         on this device, so the whole product can be shown without accounts.
 *
 * Screens do not care which mode they are in. They call the same functions;
 * in live mode those functions also write to the database.
 */
import React, {
  createContext, useCallback, useContext, useEffect, useMemo, useReducer, useRef, useState,
} from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import type {
  Account, AiTurn, CareInvite, CareNote, CaregiverProfile, ChatMessage,
  NoteCategory, Pnc, QuizResponse, Role,
} from '../models/types';
import type { Trend } from '../design/tokens';
import { computeScore } from '../data/quiz';
import { buildDemoSeed } from '../data/demoSeed';
import { caregiverById } from '../data/caregivers';
import * as remote from '../backend/remote';

const STORAGE_KEY = 'cura.state.v1';

// ── State ───────────────────────────────────────────────────

export interface AppState {
  /** True once storage has been read — screens wait on this. */
  hydrated: boolean;
  demoMode: boolean;
  /** Which side of the relationship the user is currently looking at. */
  activeRole: Role;
  familyAccount: Account | null;
  caregiverAccount: Account | null;
  /** The caregiver's own marketplace profile, when they signed up as one. */
  caregiverProfile: remote.CaregiverListing | null;
  pnc: Pnc | null;
  invites: CareInvite[];
  notes: CareNote[];
  quizzes: QuizResponse[];
  messages: ChatMessage[];
  /** Chat history kept per role so each side has their own conversation. */
  aiTurns: Record<Role, AiTurn[]>;

  // ── Live mode only ──
  /** True when signed in to a real account. */
  live: boolean;
  circleId: string | null;
  /** Code other relatives use to join this circle. */
  joinCode: string | null;
  /** Everyone in the circle (family members and the caregiver). */
  members: Account[];
  /** Last caregiver search, so the request screen can find who was picked. */
  nearby: CaregiverProfile[];
  /** A write that did not reach the database, shown so nothing fails silently. */
  syncError: string | null;
}

const EMPTY: AppState = {
  hydrated: false,
  demoMode: false,
  activeRole: 'family',
  familyAccount: null,
  caregiverAccount: null,
  caregiverProfile: null,
  pnc: null,
  invites: [],
  notes: [],
  quizzes: [],
  messages: [],
  aiTurns: { family: [], caregiver: [] },
  live: false,
  circleId: null,
  joinCode: null,
  members: [],
  nearby: [],
  syncError: null,
};

/** Fields that only make sense for one session and are never saved to the device. */
const SESSION_ONLY: (keyof AppState)[] = ['hydrated', 'nearby', 'syncError'];

// ── Actions ─────────────────────────────────────────────────

type Action =
  | { type: 'hydrate'; state: Partial<AppState> }
  | { type: 'startDemo' }
  | { type: 'reset' }
  | { type: 'setActiveRole'; role: Role }
  | { type: 'signUpFamily'; account: Account; pnc: Pnc }
  | { type: 'signUpCaregiver'; account: Account; profile: AppState['caregiverProfile'] }
  | { type: 'ensureCaregiverAccount'; account: Account }
  | { type: 'updateAccount'; role: Role; patch: Partial<Account> }
  | { type: 'updatePnc'; patch: Partial<Pnc> }
  | { type: 'addInvite'; invite: CareInvite }
  | { type: 'respondToInvite'; id: string; status: 'accepted' | 'declined'; reason?: string }
  | { type: 'addNote'; note: CareNote }
  | { type: 'deleteNote'; id: string }
  | { type: 'addComment'; noteId: string; comment: CareNote['comments'][number] }
  | { type: 'addQuiz'; quiz: QuizResponse }
  | { type: 'setQuizInsight'; id: string; insight: string }
  | { type: 'addMessage'; message: ChatMessage }
  | { type: 'setTranslation'; id: string; lang: string; text: string; sourceLang?: string }
  | { type: 'setTranslating'; id: string; value: boolean }
  | { type: 'setAiTurns'; role: Role; turns: AiTurn[] }
  | { type: 'loadSnapshot'; snap: remote.Snapshot }
  | { type: 'setNearby'; nearby: CaregiverProfile[] }
  | { type: 'upsertInvite'; invite: CareInvite }
  | { type: 'remoteEntry'; kind: 'note' | 'comment' | 'quiz' | 'message'; id: string; data: any; event: 'INSERT' | 'UPDATE' | 'DELETE' }
  | { type: 'setPnc'; pnc: Pnc }
  | { type: 'setMembers'; members: Account[] }
  | { type: 'syncError'; message: string | null };

/** Insert or replace by id, newest first. */
function upsertById<T extends { id: string }>(list: T[], item: T, append = false): T[] {
  const i = list.findIndex(x => x.id === item.id);
  if (i >= 0) {
    const next = [...list];
    next[i] = { ...next[i], ...item };
    return next;
  }
  return append ? [...list, item] : [item, ...list];
}

/** Map the signed-in person and their circle onto the family/caregiver slots screens use. */
function fromSnapshot(snap: remote.Snapshot): Partial<AppState> {
  const isFamily = snap.me.role === 'family';
  const accepted = snap.invites.find(i => i.status === 'accepted');
  const caregiver = isFamily
    ? snap.members.find(m => m.role === 'caregiver') ?? null
    : snap.me;
  const family = isFamily
    ? snap.me
    : snap.members.find(m => m.role === 'family' && m.name === accepted?.familyName)
      ?? snap.members.find(m => m.role === 'family') ?? null;
  return {
    live: true,
    demoMode: false,
    activeRole: snap.me.role,
    familyAccount: family,
    caregiverAccount: caregiver,
    caregiverProfile: snap.listing,
    circleId: snap.circleId,
    joinCode: snap.joinCode,
    members: snap.members,
    pnc: snap.pnc,
    invites: snap.invites,
    notes: snap.notes,
    quizzes: snap.quizzes.sort((a, b) => b.submittedAt - a.submittedAt),
    messages: snap.messages,
    syncError: null,
  };
}

function reducer(state: AppState, action: Action): AppState {
  switch (action.type) {
    case 'hydrate':
      return { ...state, ...action.state, hydrated: true };

    case 'startDemo': {
      const seed = buildDemoSeed();
      return {
        ...EMPTY,
        hydrated: true,
        demoMode: true,
        activeRole: 'family',
        familyAccount: seed.family,
        caregiverAccount: seed.caregiver,
        caregiverProfile: null,
        pnc: seed.pnc,
        invites: seed.invites,
        notes: seed.notes,
        quizzes: seed.quizzes,
        messages: seed.messages,
        aiTurns: { family: [], caregiver: [] },
      };
    }

    case 'reset':
      return { ...EMPTY, hydrated: true };

    case 'setActiveRole':
      return { ...state, activeRole: action.role };

    case 'signUpFamily':
      return {
        ...state,
        activeRole: 'family',
        familyAccount: action.account,
        pnc: action.pnc,
      };

    case 'signUpCaregiver':
      // No invented family: a new caregiver starts with an empty inbox until a
      // real family nearby sends a request.
      return {
        ...state,
        activeRole: 'caregiver',
        caregiverAccount: action.account,
        caregiverProfile: action.profile,
      };

    case 'ensureCaregiverAccount':
      return state.caregiverAccount
        ? state
        : { ...state, caregiverAccount: action.account };

    case 'updateAccount': {
      const key = action.role === 'family' ? 'familyAccount' : 'caregiverAccount';
      const current = state[key];
      if (!current) return state;
      return { ...state, [key]: { ...current, ...action.patch } };
    }

    case 'updatePnc':
      return state.pnc ? { ...state, pnc: { ...state.pnc, ...action.patch } } : state;

    case 'addInvite':
      return { ...state, invites: [action.invite, ...state.invites] };

    case 'respondToInvite': {
      const invites = state.invites.map(i => {
        if (i.id !== action.id) return i;
        const accepted = action.status === 'accepted';
        return {
          ...i,
          status: action.status,
          respondedAt: Date.now(),
          declineReason: accepted ? undefined : action.reason,
          payment: {
            ...i.payment,
            // Money only moves once the caregiver says yes.
            status: accepted ? ('captured' as const) : ('released' as const),
            capturedAt: accepted ? Date.now() : undefined,
          },
        };
      });
      return { ...state, invites };
    }

    case 'addNote':
      return { ...state, notes: [action.note, ...state.notes] };

    case 'deleteNote':
      return { ...state, notes: state.notes.filter(n => n.id !== action.id) };

    case 'addComment':
      return {
        ...state,
        notes: state.notes.map(n =>
          n.id === action.noteId ? { ...n, comments: [...n.comments, action.comment] } : n,
        ),
      };

    case 'addQuiz':
      return { ...state, quizzes: [action.quiz, ...state.quizzes] };

    case 'setQuizInsight':
      return {
        ...state,
        quizzes: state.quizzes.map(q =>
          q.id === action.id ? { ...q, aiInsight: action.insight } : q,
        ),
      };

    case 'addMessage':
      return { ...state, messages: [...state.messages, action.message] };

    case 'setTranslation':
      return {
        ...state,
        messages: state.messages.map(m =>
          m.id === action.id
            ? {
                ...m,
                translations: { ...m.translations, [action.lang]: action.text },
                sourceLang: action.sourceLang ?? m.sourceLang,
                translating: false,
              }
            : m,
        ),
      };

    case 'setTranslating':
      return {
        ...state,
        messages: state.messages.map(m =>
          m.id === action.id ? { ...m, translating: action.value } : m,
        ),
      };

    case 'setAiTurns':
      return { ...state, aiTurns: { ...state.aiTurns, [action.role]: action.turns } };

    case 'loadSnapshot': {
      const next = fromSnapshot(action.snap);
      // Keep translations this phone already made, so a refresh never re-translates.
      const known = new Map(state.messages.map(m => [m.id, m.translations]));
      next.messages = (next.messages ?? []).map(m => ({ ...m, translations: known.get(m.id) ?? m.translations }));
      const insights = new Map(state.quizzes.map(q => [q.id, q.aiInsight]));
      next.quizzes = (next.quizzes ?? []).map(q => ({ ...q, aiInsight: q.aiInsight ?? insights.get(q.id) }));
      return { ...state, ...next, hydrated: true };
    }

    case 'setNearby':
      return { ...state, nearby: action.nearby };

    case 'upsertInvite':
      return { ...state, invites: upsertById(state.invites, action.invite) };

    case 'setPnc':
      return { ...state, pnc: action.pnc };

    case 'setMembers': {
      const isFamily = state.activeRole === 'family';
      return {
        ...state,
        members: action.members,
        caregiverAccount: isFamily
          ? action.members.find(m => m.role === 'caregiver') ?? state.caregiverAccount
          : state.caregiverAccount,
        familyAccount: isFamily
          ? state.familyAccount
          : action.members.find(m => m.role === 'family') ?? state.familyAccount,
      };
    }

    case 'syncError':
      return { ...state, syncError: action.message };

    case 'remoteEntry': {
      const { kind, id, data, event } = action;
      if (event === 'DELETE') {
        return {
          ...state,
          notes: state.notes
            .filter(n => n.id !== id)
            .map(n => ({ ...n, comments: n.comments.filter(c => c.id !== id) })),
          quizzes: state.quizzes.filter(q => q.id !== id),
          messages: state.messages.filter(m => m.id !== id),
        };
      }
      if (kind === 'note') {
        const existing = state.notes.find(n => n.id === id);
        return { ...state, notes: upsertById(state.notes, { ...data, comments: existing?.comments ?? [] }) };
      }
      if (kind === 'comment') {
        return {
          ...state,
          notes: state.notes.map(n =>
            n.id === data.noteId ? { ...n, comments: upsertById(n.comments, data, true) } : n,
          ),
        };
      }
      if (kind === 'quiz') {
        return { ...state, quizzes: upsertById(state.quizzes, data).sort((a, b) => b.submittedAt - a.submittedAt) };
      }
      if (kind === 'message') {
        // Keep translations this phone already made.
        const existing = state.messages.find(m => m.id === id);
        const merged = { ...data, translations: existing?.translations ?? {} };
        return { ...state, messages: upsertById(state.messages, merged, true).sort((a, b) => a.createdAt - b.createdAt) };
      }
      return state;
    }

    default:
      return state;
  }
}

// ── Context ─────────────────────────────────────────────────

export interface AppApi {
  state: AppState;
  /** The account whose eyes you are looking through right now. */
  me: Account | null;
  /** The other party in the care relationship. */
  them: Account | null;
  /** The accepted engagement, if there is one. */
  activeInvite: CareInvite | null;
  pendingInvites: CareInvite[];
  isOnboarded: boolean;
  /** True when the app is connected to the Cura database. */
  canGoLive: boolean;

  startDemo: () => void;
  /** Signs out (live) or wipes this device (demo). */
  reset: () => Promise<void>;
  setActiveRole: (role: Role) => void;
  /** Demo helper: give the other side an account so you can look through it. */
  ensureCaregiverAccount: (name: string, language?: string) => void;
  signUpFamily: (account: Account, pnc: Pnc, password?: string) => Promise<void>;
  signUpCaregiver: (account: Account, profile: remote.CaregiverListing, password?: string) => Promise<void>;
  /** A relative joining a circle someone else created. */
  joinWithCode: (account: Account, code: string, password: string) => Promise<void>;
  signIn: (email: string, password: string) => Promise<void>;
  /** Re-read everything from the database. */
  refresh: () => Promise<void>;
  searchCaregivers: () => Promise<CaregiverProfile[]>;
  updateAccount: (role: Role, patch: Partial<Account>) => void;
  updatePnc: (patch: Partial<Pnc>) => void;
  sendInvite: (input: SendInviteInput) => Promise<CareInvite>;
  respondToInvite: (id: string, status: 'accepted' | 'declined', reason?: string) => Promise<void>;
  addNote: (input: AddNoteInput) => CareNote;
  deleteNote: (id: string) => void;
  addComment: (noteId: string, body: string) => void;
  submitQuiz: (answers: Record<string, number>, freeText: string) => QuizResponse;
  setQuizInsight: (id: string, insight: string) => void;
  addMessage: (text: string) => ChatMessage;
  setTranslation: (id: string, lang: string, text: string, sourceLang?: string) => void;
  setTranslating: (id: string, value: boolean) => void;
  setAiTurns: (role: Role, turns: AiTurn[]) => void;
  clearSyncError: () => void;
}

export interface SendInviteInput {
  caregiver: CaregiverProfile;
  startDate: string;
  scheduleSummary: string;
  hoursPerDay: number;
  daysPerWeek: number;
  message: string;
  paymentMethod: string;
}

export interface AddNoteInput {
  category: NoteCategory;
  trend: Trend;
  title: string;
  body: string;
}

const Ctx = createContext<AppApi | null>(null);

const uid = (prefix: string) =>
  `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`;

export function AppProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(reducer, EMPTY);
  const hydratedOnce = useRef(false);
  /** Always-current state for async callbacks. */
  const live = useRef(state);
  live.current = state;

  const loadFromServer = useCallback(async () => {
    const snap = await remote.loadSnapshot();
    if (snap) dispatch({ type: 'loadSnapshot', snap });
    return snap;
  }, []);

  // Load once on mount: a signed-in session wins, otherwise whatever demo was
  // saved on this device.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        if (remote.isLive) {
          const snap = await remote.loadSnapshot().catch(() => null);
          if (cancelled) return;
          if (snap) {
            dispatch({ type: 'loadSnapshot', snap });
            return;
          }
        }
        const raw = await AsyncStorage.getItem(STORAGE_KEY);
        if (cancelled) return;
        const parsed = raw ? (JSON.parse(raw) as Partial<AppState>) : {};
        // A saved live session without a database session is stale; drop it.
        dispatch({ type: 'hydrate', state: parsed.live ? {} : parsed });
      } catch {
        dispatch({ type: 'hydrate', state: {} });
      } finally {
        hydratedOnce.current = true;
      }
    })();
    return () => { cancelled = true; };
  }, []);

  // Demo mode is saved on the device. Live mode lives in the database.
  useEffect(() => {
    if (!state.hydrated || !hydratedOnce.current || state.live) return;
    const persistable: Partial<AppState> = { ...state };
    SESSION_ONLY.forEach(k => { delete persistable[k]; });
    AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(persistable)).catch(() => {});
  }, [state]);

  // Live updates from everyone else in the circle.
  const meId = state.live
    ? (state.activeRole === 'family' ? state.familyAccount?.id : state.caregiverAccount?.id)
    : undefined;
  const [polling, setPolling] = useState(false);
  useEffect(() => {
    if (!polling || !state.live) return;
    const t = setInterval(() => { loadFromServer().catch(() => {}); }, 5000);
    return () => clearInterval(t);
  }, [polling, state.live, loadFromServer]);

  useEffect(() => {
    if (!state.live || !meId) return;
    return remote.subscribe(meId, state.circleId, {
      onLiveUnavailable: () => setPolling(true),
      onEntry: (kind, data, id, event) => dispatch({ type: 'remoteEntry', kind, data, id, event }),
      onInvite: invite => {
        dispatch({ type: 'upsertInvite', invite });
      },
      onCircle: pnc => dispatch({ type: 'setPnc', pnc }),
      onMembersChanged: () => {
        const c = live.current.circleId;
        if (c) remote.loadMembers(c).then(members => dispatch({ type: 'setMembers', members })).catch(() => {});
      },
    });
  }, [state.live, meId, state.circleId]);

  /** Run a database write; if it fails, say so instead of failing silently. */
  const push = useCallback((work: () => Promise<unknown>) => {
    if (!live.current.live) return;
    work().catch(err => dispatch({ type: 'syncError', message: `Not saved: ${remote.friendlyDbError(err)}` }));
  }, []);

  const me = state.activeRole === 'family' ? state.familyAccount : state.caregiverAccount;
  const them = state.activeRole === 'family' ? state.caregiverAccount : state.familyAccount;

  const activeInvite = useMemo(
    () => state.invites.find(i => i.status === 'accepted') ?? null,
    [state.invites],
  );
  const pendingInvites = useMemo(
    () => state.invites.filter(i => i.status === 'pending'),
    [state.invites],
  );

  // A caregiver can be signed in before any family has invited them.
  const isOnboarded = !!me && (!!state.pnc || (state.live && state.activeRole === 'caregiver'));

  const signUpFamily = useCallback<AppApi['signUpFamily']>(async (account, pnc, password) => {
    if (!remote.isLive || !password) {
      dispatch({ type: 'signUpFamily', account, pnc });
      return;
    }
    await remote.signUp(account.email, password, account);
    await remote.createCircle(pnc);
    await loadFromServer();
  }, [loadFromServer]);

  const signUpCaregiver = useCallback<AppApi['signUpCaregiver']>(async (account, profile, password) => {
    if (!remote.isLive || !password) {
      dispatch({ type: 'signUpCaregiver', account, profile });
      return;
    }
    const created = await remote.signUp(account.email, password, account);
    await remote.saveListing(created.name, profile);
    await loadFromServer();
  }, [loadFromServer]);

  const joinWithCode = useCallback<AppApi['joinWithCode']>(async (account, code, password) => {
    await remote.signUp(account.email, password, account);
    await remote.joinCircle(code);
    await loadFromServer();
  }, [loadFromServer]);

  const signIn = useCallback<AppApi['signIn']>(async (email, password) => {
    await remote.signIn(email, password);
    const snap = await loadFromServer();
    if (!snap) throw new Error('Signed in, but this account has no Cura profile yet.');
  }, [loadFromServer]);

  const refresh = useCallback(async () => {
    if (live.current.live) await loadFromServer();
  }, [loadFromServer]);

  const searchCaregivers = useCallback(async () => {
    const pnc = live.current.pnc;
    if (!pnc) return [];
    // Only real people: caregivers who signed up on Cura. Demo mode has none to
    // search, so the screen shows real local providers instead.
    const nearby = live.current.live ? await remote.searchCaregivers(pnc.location) : [];
    dispatch({ type: 'setNearby', nearby });
    return nearby;
  }, []);

  const sendInvite = useCallback(async (input: SendInviteInput): Promise<CareInvite> => {
    const s = live.current;
    const weeklyTotal = input.hoursPerDay * input.daysPerWeek * input.caregiver.hourlyRate;
    const invite: CareInvite = {
      id: uid('invite'),
      caregiverId: input.caregiver.id,
      caregiverName: input.caregiver.name,
      familyName: s.familyAccount?.name ?? 'Family',
      pncName: s.pnc?.preferredName ?? 'their parent',
      pncSummary: s.pnc ? {
        preferredName: s.pnc.preferredName,
        age: s.pnc.age,
        conditions: s.pnc.conditions,
        mobility: s.pnc.mobility,
        // Area only. The full address is shared once the caregiver accepts.
        area: s.pnc.address.split(',').slice(-3).join(',').trim(),
      } : undefined,
      startDate: input.startDate,
      scheduleSummary: input.scheduleSummary,
      hoursPerDay: input.hoursPerDay,
      hourlyRate: input.caregiver.hourlyRate,
      daysPerWeek: input.daysPerWeek,
      message: input.message,
      status: 'pending',
      createdAt: Date.now(),
      payment: {
        id: uid('pay'),
        method: input.paymentMethod,
        weeklyTotal,
        platformFee: Math.round(weeklyTotal * 0.08),
        status: 'authorized',
        authorizedAt: Date.now(),
      },
    };
    if (s.live) {
      if (!s.circleId) throw new Error('Set up your loved one\'s profile first.');
      await remote.sendInvite(s.circleId, invite);
    }
    dispatch({ type: 'addInvite', invite });
    return invite;
  }, []);

  const respondToInvite = useCallback<AppApi['respondToInvite']>(async (id, status, reason) => {
    if (live.current.live) {
      await remote.answerInvite(id, status);
      dispatch({ type: 'respondToInvite', id, status, reason });
      // Accepting adds you to the family's circle; load it.
      if (status === 'accepted') await loadFromServer();
      return;
    }
    dispatch({ type: 'respondToInvite', id, status, reason });
  }, [loadFromServer]);

  const author = () => {
    const s = live.current;
    return s.activeRole === 'family' ? s.familyAccount : s.caregiverAccount;
  };

  const addNote = useCallback((input: AddNoteInput): CareNote => {
    const a = author();
    const note: CareNote = {
      id: uid('note'),
      authorId: a?.id ?? 'unknown',
      authorName: a?.name ?? 'Someone',
      authorRole: live.current.activeRole,
      createdAt: Date.now(),
      comments: [],
      ...input,
    };
    dispatch({ type: 'addNote', note });
    const c = live.current.circleId;
    if (c) push(() => remote.addEntry(c, 'note', note.id, remote.stripNote(note)));
    return note;
  }, [push]);

  const addComment = useCallback((noteId: string, body: string) => {
    const a = author();
    const comment = {
      id: uid('nc'),
      authorId: a?.id ?? 'unknown',
      authorName: a?.name ?? 'Someone',
      authorRole: live.current.activeRole,
      body,
      createdAt: Date.now(),
    };
    dispatch({ type: 'addComment', noteId, comment });
    const c = live.current.circleId;
    if (c) push(() => remote.addEntry(c, 'comment', comment.id, { ...comment, noteId }));
  }, [push]);

  const submitQuiz = useCallback((answers: Record<string, number>, freeText: string): QuizResponse => {
    const a = author();
    const quiz: QuizResponse = {
      id: uid('quiz'),
      submittedAt: Date.now(),
      submittedByRole: live.current.activeRole,
      submittedByName: a?.name ?? 'Someone',
      answers,
      freeText,
      score: computeScore(answers),
    };
    dispatch({ type: 'addQuiz', quiz });
    const c = live.current.circleId;
    if (c) push(() => remote.addEntry(c, 'quiz', quiz.id, quiz));
    return quiz;
  }, [push]);

  const setQuizInsight = useCallback((id: string, insight: string) => {
    dispatch({ type: 'setQuizInsight', id, insight });
    const q = live.current.quizzes.find(x => x.id === id);
    if (q && live.current.live) push(() => remote.updateEntry(id, { ...q, aiInsight: insight }));
  }, [push]);

  const addMessage = useCallback((text: string): ChatMessage => {
    const a = author();
    const message: ChatMessage = {
      id: uid('msg'),
      senderId: a?.id ?? 'unknown',
      senderName: a?.name ?? 'Someone',
      senderRole: live.current.activeRole,
      text,
      sourceLang: a?.language ?? 'en',
      translations: {},
      createdAt: Date.now(),
    };
    dispatch({ type: 'addMessage', message });
    const c = live.current.circleId;
    if (c) push(() => remote.addEntry(c, 'message', message.id, remote.stripMessage(message)));
    return message;
  }, [push]);

  const deleteNote = useCallback((id: string) => {
    dispatch({ type: 'deleteNote', id });
    push(() => remote.deleteEntry(id));
  }, [push]);

  const updatePnc = useCallback((patch: Partial<Pnc>) => {
    dispatch({ type: 'updatePnc', patch });
    const s = live.current;
    if (s.live && s.circleId && s.pnc) {
      const next = { ...s.pnc, ...patch };
      const c = s.circleId;
      push(() => remote.updateCirclePnc(c, next));
    }
  }, [push]);

  const reset = useCallback(async () => {
    if (live.current.live) await remote.signOut();
    await AsyncStorage.removeItem(STORAGE_KEY).catch(() => {});
    dispatch({ type: 'reset' });
  }, []);

  const api: AppApi = useMemo(() => ({
    state,
    me,
    them,
    activeInvite,
    pendingInvites,
    isOnboarded,
    canGoLive: remote.isLive,
    startDemo: () => dispatch({ type: 'startDemo' }),
    reset,
    setActiveRole: role => dispatch({ type: 'setActiveRole', role }),
    ensureCaregiverAccount: (name, language = 'mr') =>
      dispatch({
        type: 'ensureCaregiverAccount',
        account: {
          id: `acct-caregiver-${Date.now().toString(36)}`,
          role: 'caregiver',
          name,
          email: `${name.split(' ')[0].toLowerCase()}@example.com`,
          phone: '',
          language,
        },
      }),
    signUpFamily,
    signUpCaregiver,
    joinWithCode,
    signIn,
    refresh,
    searchCaregivers,
    updateAccount: (role, patch) => {
      dispatch({ type: 'updateAccount', role, patch });
      push(() => remote.updateProfile(patch));
    },
    updatePnc,
    sendInvite,
    respondToInvite,
    addNote,
    deleteNote,
    addComment,
    submitQuiz,
    setQuizInsight,
    addMessage,
    setTranslation: (id, lang, text, sourceLang) =>
      dispatch({ type: 'setTranslation', id, lang, text, sourceLang }),
    setTranslating: (id, value) => dispatch({ type: 'setTranslating', id, value }),
    setAiTurns: (role, turns) => dispatch({ type: 'setAiTurns', role, turns }),
    clearSyncError: () => dispatch({ type: 'syncError', message: null }),
  }), [
    state, me, them, activeInvite, pendingInvites, isOnboarded, reset, signUpFamily, signUpCaregiver,
    joinWithCode, signIn, refresh, searchCaregivers, updatePnc, sendInvite, respondToInvite, addNote,
    deleteNote, addComment, submitQuiz, setQuizInsight, addMessage, push,
  ]);

  return <Ctx.Provider value={api}>{children}</Ctx.Provider>;
}

export function useApp(): AppApi {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error('useApp must be used inside <AppProvider>');
  return ctx;
}

/** The care context every AI call needs, assembled from the store. */
export function useCareContext() {
  const { state, me } = useApp();
  const caregiverName =
    state.caregiverAccount?.name ??
    (state.invites[0] ? caregiverById(state.invites[0].caregiverId)?.name ?? null : null);

  return useMemo(() => ({
    pnc: state.pnc,
    notes: state.notes,
    quizzes: state.quizzes,
    messages: state.messages,
    invite: state.invites.find(i => i.status === 'accepted') ?? state.invites[0] ?? null,
    caregiverName,
    familyName: state.familyAccount?.name ?? null,
    viewerRole: state.activeRole,
    viewerName: me?.name ?? 'there',
  }), [state.pnc, state.notes, state.quizzes, state.messages, state.invites,
       caregiverName, state.familyAccount, state.activeRole, me]);
}
