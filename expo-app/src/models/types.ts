import type { Trend } from '../design/tokens';

export type Role = 'family' | 'caregiver';

export interface GeoPoint {
  lat: number;
  lng: number;
}

export interface PlaceResult extends GeoPoint {
  label: string;
  shortLabel: string;
}

// ── People ──────────────────────────────────────────────────

export interface Account {
  id: string;
  role: Role;
  name: string;
  email: string;
  phone: string;
  /** BCP-47-ish code used by auto-translate, e.g. "en", "mr", "es". */
  language: string;
  relationship?: string; // family only — "Son", "Daughter"…
}

/** The person needing care. */
export interface Pnc {
  id: string;
  fullName: string;
  preferredName: string;
  age: number;
  pronouns: string;
  address: string;
  location: GeoPoint;
  conditions: string[];
  mobility: string;
  diet: string;
  languages: string[];
  medications: Medication[];
  allergies: string;
  emergencyContact: string;
  emergencyPhone: string;
  routine: string;
  calmingNotes: string;
  careHoursPerDay: number;
}

export interface Medication {
  id: string;
  name: string;
  dose: string;
  schedule: string;
}

export interface CaregiverProfile {
  id: string;
  name: string;
  photoInitials: string;
  headline: string;
  bio: string;
  rating: number;
  reviewCount: number;
  yearsExperience: number;
  hourlyRate: number;
  specialties: string[];
  languages: string[];
  certifications: string[];
  location: GeoPoint;
  neighborhood: string;
  /** Filled in at search time, km from the PNC. */
  distanceKm?: number;
  availability: string;
  respondsIn: string;
}

// ── Engagement ──────────────────────────────────────────────

export type InviteStatus = 'pending' | 'accepted' | 'declined' | 'cancelled';

export interface CareInvite {
  id: string;
  caregiverId: string;
  caregiverName: string;
  familyName: string;
  pncName: string;
  startDate: string;
  scheduleSummary: string;
  hoursPerDay: number;
  hourlyRate: number;
  daysPerWeek: number;
  message: string;
  status: InviteStatus;
  createdAt: number;
  respondedAt?: number;
  declineReason?: string;
  payment: PaymentRecord;
  /**
   * What the caregiver needs to decide, copied in when the invite is sent.
   * They cannot read the full care profile until they accept.
   */
  pncSummary?: Pick<Pnc, 'preferredName' | 'age' | 'conditions' | 'mobility'> & { area: string };
}

export type PaymentStatus = 'authorized' | 'captured' | 'released' | 'refunded';

export interface PaymentRecord {
  id: string;
  method: string; // "Visa •••• 4242"
  weeklyTotal: number;
  platformFee: number;
  status: PaymentStatus;
  authorizedAt: number;
  capturedAt?: number;
}

// ── Care record ─────────────────────────────────────────────

export interface CareNote {
  id: string;
  authorId: string;
  authorName: string;
  authorRole: Role;
  createdAt: number;
  /** Which aspect of care changed. */
  category: NoteCategory;
  trend: Trend;
  title: string;
  body: string;
  comments: NoteComment[];
}

export type NoteCategory =
  | 'general'
  | 'appetite'
  | 'hydration'
  | 'sleep'
  | 'mood'
  | 'mobility'
  | 'medication'
  | 'skin'
  | 'cognition';

export interface NoteComment {
  id: string;
  authorId: string;
  authorName: string;
  authorRole: Role;
  body: string;
  createdAt: number;
}

// ── Daily check-in quiz ─────────────────────────────────────

export type QuizAnswerValue = number;

export interface QuizResponse {
  id: string;
  submittedAt: number;
  submittedByRole: Role;
  submittedByName: string;
  /** questionId → selected option index (0 = worst … n-1 = best). */
  answers: Record<string, QuizAnswerValue>;
  freeText: string;
  /** 0–100 wellbeing score derived from the answers. */
  score: number;
  /** Safety items answered "yes" (ids from RED_FLAG_ITEMS). */
  redFlags?: string[];
  /** Specific behaviours seen today (ids from OBSERVATIONS). */
  observed?: string[];
  aiInsight?: string;
}

export type CheckInSectionId = 'memory' | 'mood' | 'daily' | 'engagement';

export interface QuizQuestion {
  id: string;
  /** Which part of the check-in this belongs to. */
  section: CheckInSectionId;
  icon: string;
  prompt: string;
  helper: string;
  /** Ordered worst → best. */
  options: string[];
}

// ── Messaging ───────────────────────────────────────────────

export interface ChatMessage {
  id: string;
  senderId: string;
  senderName: string;
  senderRole: Role;
  /** Exactly as typed. */
  text: string;
  /** Language the sender wrote in. */
  sourceLang: string;
  /** targetLang → translated text, filled lazily by the AI layer. */
  translations: Record<string, string>;
  createdAt: number;
  translating?: boolean;
}

// ── AI ──────────────────────────────────────────────────────

export interface AiSource {
  title: string;
  uri: string;
}

export interface AiTurn {
  id: string;
  role: 'user' | 'assistant';
  text: string;
  createdAt: number;
  sources?: AiSource[];
  pending?: boolean;
  error?: boolean;
}
