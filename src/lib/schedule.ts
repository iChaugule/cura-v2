/**
 * Schedule helpers: which items fall on a date, whether they are done, and
 * how to say a time out loud.
 */
import type { ScheduleItem, ScheduleKind, ScheduleLog } from '../models/types';

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
  const done = items.filter(i => logFor(log, i.id, date)).length;
  return { total: items.length, done };
}
