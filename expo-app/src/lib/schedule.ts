/**
 * Schedule helpers: which items fall on a date, whether they are done, and
 * how to say a time out loud.
 */
import type { DoseStatus, FoodRule, ScheduleItem, ScheduleKind, ScheduleLog } from '../models/types';

export const KIND_LABEL: Record<ScheduleKind, string> = {
  medication: 'Medicine',
  meal: 'Meal or drink',
  activity: 'Activity',
  appointment: 'Appointment',
  other: 'Other',
};

export const DAY_LETTERS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
export const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const pad = (n: number) => String(n).padStart(2, '0');

/** Local date as YYYY-MM-DD. */
export const dateKey = (d: Date | number = new Date()) => {
  const x = typeof d === 'number' ? new Date(d) : d;
  return `${x.getFullYear()}-${pad(x.getMonth() + 1)}-${pad(x.getDate())}`;
};

export const logId = (itemId: string, date: string) => `dose_${itemId}_${date}`;

export const minutesOf = (time: string) => {
  const [h, m] = time.split(':').map(Number);
  return (h || 0) * 60 + (m || 0);
};

/** "08:30" -> "8:30 AM". */
export function timeLabel(time: string): string {
  const [h, m] = time.split(':').map(Number);
  const hour = ((h + 11) % 12) + 1;
  return `${hour}:${pad(m || 0)} ${h >= 12 ? 'PM' : 'AM'}`;
}

/** Does this item happen on the given local date? */
export function occursOn(item: ScheduleItem, date: string): boolean {
  if (item.date) return item.date === date;
  if (item.endDate && date > item.endDate) return false;
  if (!item.days.length) return true;
  const [y, mo, d] = date.split('-').map(Number);
  return item.days.includes(new Date(y, mo - 1, d).getDay());
}

export const itemsOn = (schedule: ScheduleItem[], date: string) =>
  schedule.filter(i => occursOn(i, date)).sort((a, b) => a.time.localeCompare(b.time));

export const logFor = (log: ScheduleLog[], itemId: string, date: string) =>
  log.find(l => l.itemId === itemId && l.date === date);

export type DueState = 'done' | 'missed' | 'due' | 'later';

/** Where an item stands right now. "Missed" only applies to today, 90 minutes after its time. */
export function dueState(item: ScheduleItem, done: boolean, date: string, now = new Date()): DueState {
  if (done) return 'done';
  const today = dateKey(now);
  if (date < today) return 'missed';
  if (date > today) return 'later';
  const nowMin = now.getHours() * 60 + now.getMinutes();
  const at = minutesOf(item.time);
  if (nowMin > at + 90) return 'missed';
  if (nowMin >= at - 30) return 'due';
  return 'later';
}

export function repeatLabel(item: ScheduleItem): string {
  if (item.date) {
    const [y, m, d] = item.date.split('-').map(Number);
    return new Date(y, m - 1, d).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' });
  }
  if (!item.days.length || item.days.length === 7) return 'Every day';
  return item.days.map(d => DAY_NAMES[d]).join(', ');
}

/** How many of today's items are done, for a one-line summary. */
export function progress(schedule: ScheduleItem[], log: ScheduleLog[], date: string) {
  const items = itemsOn(schedule, date);
  const done = items.filter(i => statusOf(logFor(log, i.id, date))).length;
  return { total: items.length, done };
}

export const FOOD_LABEL: Record<FoodRule, string> = {
  with: 'With food',
  before: 'Before food',
  after: 'After food',
  empty: 'Empty stomach',
  any: 'Any time',
};

export const STATUS_LABEL: Record<DoseStatus, string> = {
  done: 'Done',
  refused: 'Refused',
  skipped: 'Skipped',
};

export const statusOf = (l?: ScheduleLog): DoseStatus | undefined => (l ? l.status ?? 'done' : undefined);

/** "5 mg, after food" — the line that goes under a medicine's name. */
export function medLine(item: ScheduleItem): string {
  return [item.dose, item.food && item.food !== 'any' ? FOOD_LABEL[item.food].toLowerCase() : '']
    .filter(Boolean).join(', ');
}

export interface Adherence {
  due: number;
  taken: number;
  refused: number;
  skipped: number;
  missed: number;
}

/** How one repeating item went over the last `days` days (not counting today). */
export function adherenceFor(item: ScheduleItem, log: ScheduleLog[], days = 7, now = new Date()): Adherence {
  const r: Adherence = { due: 0, taken: 0, refused: 0, skipped: 0, missed: 0 };
  for (let o = 1; o <= days; o++) {
    const d = new Date(now); d.setDate(d.getDate() - o);
    const k = dateKey(d);
    if (!occursOn(item, k)) continue;
    if (k < dateKey(item.createdAt)) continue; // did not exist yet
    r.due++;
    const st = statusOf(logFor(log, item.id, k));
    if (st === 'done') r.taken++;
    else if (st === 'refused') r.refused++;
    else if (st === 'skipped') r.skipped++;
    else r.missed++;
  }
  return r;
}

/** All medicines together, for the summary at the top of the schedule. */
export function weekSummary(schedule: ScheduleItem[], log: ScheduleLog[], days = 7) {
  const total: Adherence = { due: 0, taken: 0, refused: 0, skipped: 0, missed: 0 };
  for (const i of schedule.filter(x => x.kind === 'medication' && !x.date)) {
    const a = adherenceFor(i, log, days);
    (Object.keys(total) as (keyof Adherence)[]).forEach(k => { total[k] += a[k]; });
  }
  return total;
}
