/**
 * Schedule: what should happen today and when. Medicines, meals and drinks,
 * walks, appointments. Everyone in the circle sees the same list; whoever is
 * with the person ticks things off, and the family sees it as it happens.
 */
import { useMemo, useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, Pressable, Modal, KeyboardAvoidingView, Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Button, Chip, EmptyState, Field, Input, Segmented } from '../../src/components/ui';
import { Colors, Radius, Spacing, Type } from '../../src/design/tokens';
import { clockTime } from '../../src/lib/format';
import {
  DAY_LETTERS, DAY_NAMES, FOOD_LABEL, KIND_LABEL, STATUS_LABEL, adherenceFor, dateKey, dueState, itemsOn, logFor,
  medLine, progress, repeatLabel, statusOf, timeLabel, weekSummary,
} from '../../src/lib/schedule';
import { useApp, type AddScheduleInput } from '../../src/state/AppContext';
import type { DoseStatus, FoodRule, ScheduleItem, ScheduleKind } from '../../src/models/types';

const KINDS: ScheduleKind[] = ['medication', 'meal', 'activity', 'appointment', 'other'];

/** Yesterday through the next week. */
const dayOffsets = [-1, 0, 1, 2, 3, 4, 5, 6];

export default function Schedule() {
  const { state, toggleDose, logDose, deleteScheduleItem, addScheduleItem } = useApp();
  const today = dateKey();
  const [selected, setSelected] = useState(today);
  const [open, setOpen] = useState<string | null>(null);
  const [composing, setComposing] = useState(false);

  const days = useMemo(() => dayOffsets.map(o => {
    const d = new Date(); d.setDate(d.getDate() + o);
    return { key: dateKey(d), letter: DAY_LETTERS[d.getDay()], num: d.getDate(), name: DAY_NAMES[d.getDay()] };
  }), []);

  const items = itemsOn(state.schedule, selected);
  const { total, done } = progress(state.schedule, state.scheduleLog, selected);
  const isToday = selected === today;
  const name = state.pnc?.preferredName ?? 'them';

  return (
    <View style={s.screen}>
      <View style={s.header}>
        <View style={{ flex: 1 }}>
          <Text style={s.title}>Schedule</Text>
          <Text style={s.sub}>
            {total === 0
              ? `Nothing planned ${isToday ? 'today' : 'that day'}`
              : `${isToday ? 'Today' : days.find(d => d.key === selected)?.name}: ${done} of ${total} done`}
          </Text>
        </View>
        <Pressable
          onPress={() => setComposing(true)}
          accessibilityRole="button" accessibilityLabel="Add to the schedule"
          style={({ pressed }) => [s.addBtn, pressed && { opacity: 0.8 }]}
        >
          <Ionicons name="add" size={22} color={Colors.textOnBrown} />
        </Pressable>
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={s.dayBar} contentContainerStyle={s.dayRow}>
        {days.map(d => {
          const on = d.key === selected;
          const count = itemsOn(state.schedule, d.key).length;
          return (
            <Pressable
              key={d.key}
              onPress={() => setSelected(d.key)}
              accessibilityRole="button"
              accessibilityState={{ selected: on }}
              accessibilityLabel={`${d.name} ${d.num}${d.key === today ? ', today' : ''}`}
              style={[s.day, on && s.dayOn]}
            >
              <Text style={[s.dayLetter, on && s.dayTextOn]}>{d.key === today ? 'Today' : d.name}</Text>
              <Text style={[s.dayNum, on && s.dayTextOn]}>{d.num}</Text>
              <View style={[s.dayDot, { opacity: count ? 1 : 0 }, on && { backgroundColor: Colors.textOnBrown }]} />
            </Pressable>
          );
        })}
      </ScrollView>

      <ScrollView contentContainerStyle={s.list} showsVerticalScrollIndicator={false}>
        {isToday ? <WeekCard name={name} /> : null}
        {items.length === 0 ? (
          <EmptyState
            icon="calendar-outline"
            title={state.schedule.length === 0 ? 'No schedule yet' : 'Nothing planned'}
            body={
              state.schedule.length === 0
                ? `Add ${name}'s medicines, meals and daily routine. Everyone in the circle sees it, and whoever is there ticks things off.`
                : 'Nothing is planned for this day.'
            }
            action="Add to the schedule"
            onAction={() => setComposing(true)}
          />
        ) : (
          items.map((item, i) => (
            <Row
              key={item.id}
              item={item}
              date={selected}
              first={i === 0}
              expanded={open === item.id}
              onToggleOpen={() => setOpen(open === item.id ? null : item.id)}
              onDone={() => toggleDose(item.id, selected)}
              onLog={(status, note) => logDose(item.id, selected, status, note)}
              onRemove={() => { setOpen(null); deleteScheduleItem(item.id); }}
            />
          ))
        )}
        <View style={{ height: Spacing.xl }} />
      </ScrollView>

      <AddSheet
        visible={composing}
        defaultDate={selected}
        onClose={() => setComposing(false)}
        onSave={input => { addScheduleItem(input); setComposing(false); }}
      />
    </View>
  );
}

function Row({
  item, date, first, expanded, onToggleOpen, onDone, onLog, onRemove,
}: {
  item: ScheduleItem; date: string; first: boolean; expanded: boolean;
  onToggleOpen: () => void; onDone: () => void; onLog: (s: DoseStatus, note?: string) => void; onRemove: () => void;
}) {
  const { state } = useApp();
  const log = logFor(state.scheduleLog, item.id, date);
  const result = statusOf(log);
  const st = dueState(item, !!log, date);
  const [reason, setReason] = useState<DoseStatus | null>(null);
  const [note, setNote] = useState('');
  const who = log?.doneByName.split(' ')[0];
  const status =
    result === 'done' ? `Done by ${who}, ${clockTime(log?.doneAt ?? 0)}`
    : result === 'refused' ? `Refused. Logged by ${who}`
    : result === 'skipped' ? `Skipped. Logged by ${who}`
    : st === 'missed' ? 'Not marked done'
    : st === 'due' ? 'Due now'
    : null;
  const bad = result === 'refused' || result === 'skipped' || st === 'missed';
  const statusColor = bad ? Colors.urgent : st === 'due' ? Colors.caution : Colors.textSecondary;
  const line = item.kind === 'medication' ? medLine(item) : item.place ?? '';
  const adh = item.kind === 'medication' && !item.date ? adherenceFor(item, state.scheduleLog, 7) : null;

  return (
    <View style={[s.row, !first && s.rowRule]}>
      <Pressable onPress={onToggleOpen} style={s.rowMain} accessibilityRole="button" accessibilityLabel={`${item.title}, ${timeLabel(item.time)}`}>
        <Text style={s.time}>{timeLabel(item.time)}</Text>
        <View style={{ flex: 1, gap: 2 }}>
          <Text style={[s.rowTitle, result === 'done' && s.rowTitleDone]}>
            {item.title}{item.important ? '  •' : ''}
          </Text>
          <Text style={s.rowKind}>{line ? `${line}` : KIND_LABEL[item.kind]}{item.purpose && !line ? `, ${item.purpose}` : ''}</Text>
          {status ? <Text style={[s.status, { color: statusColor }]}>{status}</Text> : null}
        </View>
      </Pressable>
      <Pressable
        onPress={onDone}
        accessibilityRole="checkbox"
        accessibilityState={{ checked: result === 'done' }}
        accessibilityLabel={`${item.title}, mark ${log ? 'not done' : 'done'}`}
        hitSlop={10}
        style={[s.box, result === 'done' && s.boxOn, bad && result && s.boxBad]}
      >
        {result === 'done' ? <Ionicons name="checkmark" size={18} color={Colors.textOnBrown} /> : null}
        {result === 'refused' || result === 'skipped' ? <Ionicons name="close" size={18} color={Colors.urgent} /> : null}
      </Pressable>
      {expanded ? (
        <View style={s.detail}>
          {item.detail ? <Text style={s.detailText}>{item.detail}</Text> : null}
          <View style={s.facts}>
            {item.purpose ? <Fact label="For" value={item.purpose} /> : null}
            {item.dose ? <Fact label="Dose" value={item.dose} /> : null}
            {item.food && item.food !== 'any' ? <Fact label="Food" value={FOOD_LABEL[item.food]} /> : null}
            {item.prescriber ? <Fact label={item.kind === 'appointment' ? 'With' : 'Prescribed by'} value={item.prescriber} /> : null}
            {item.place ? <Fact label="Where" value={item.place} /> : null}
            <Fact label="Repeats" value={`${repeatLabel(item)}${item.endDate ? `, until ${item.endDate}` : ''}`} />
            {adh && adh.due ? (
              <Fact
                label="Last 7 days"
                value={`${adh.taken} of ${adh.due} given${adh.refused ? `, ${adh.refused} refused` : ''}${adh.missed ? `, ${adh.missed} not marked` : ''}`}
              />
            ) : null}
          </View>
          {item.steps?.length ? (
            <View style={{ gap: 4 }}>
              <Text style={s.factLabel}>STEPS</Text>
              {item.steps.map((t, i) => <Text key={i} style={s.step}>{i + 1}.  {t}</Text>)}
            </View>
          ) : null}
          {log?.note ? <Text style={s.logNote}>“{log.note}”</Text> : null}

          {reason ? (
            <View style={{ gap: 8 }}>
              <Text style={s.factLabel}>WHAT HAPPENED? (OPTIONAL)</Text>
              <Input value={note} onChangeText={setNote} placeholder="Said she was full. Tried again later." multiline />
              <View style={s.wrap}>
                <Button label={`Log as ${STATUS_LABEL[reason].toLowerCase()}`} onPress={() => { onLog(reason, note); setReason(null); setNote(''); }} />
                <Button label="Cancel" variant="ghost" onPress={() => { setReason(null); setNote(''); }} />
              </View>
            </View>
          ) : (
            <View style={s.actions}>
              {result !== 'refused' ? <Pressable onPress={() => setReason('refused')} accessibilityRole="button"><Text style={s.actionText}>Refused</Text></Pressable> : null}
              {result !== 'skipped' ? <Pressable onPress={() => setReason('skipped')} accessibilityRole="button"><Text style={s.actionText}>Skipped</Text></Pressable> : null}
              <Pressable onPress={onRemove} accessibilityRole="button" hitSlop={8}><Text style={s.remove}>Remove</Text></Pressable>
            </View>
          )}
          <Text style={s.detailMeta}>Added by {item.createdByName.split(' ')[0]}.</Text>
        </View>
      ) : null}
    </View>
  );
}

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <View style={s.fact}>
      <Text style={s.factLabel}>{label.toUpperCase()}</Text>
      <Text style={s.factValue}>{value}</Text>
    </View>
  );
}

/** How the medicines went this week, with a way to ask Cura about it. */
function WeekCard({ name }: { name: string }) {
  const { state } = useApp();
  const meds = state.schedule.filter(i => i.kind === 'medication' && !i.date);
  if (!meds.length) return null;
  const w = weekSummary(state.schedule, state.scheduleLog, 7);
  if (!w.due) return null;
  const pct = Math.round((w.taken / w.due) * 100);
  const trouble = w.refused + w.skipped + w.missed;
  return (
    <View style={s.week}>
      <View style={{ flexDirection: 'row', alignItems: 'baseline', gap: 8 }}>
        <Text style={s.weekPct}>{pct}%</Text>
        <Text style={s.weekText}>of {name}&apos;s medicines given in the last 7 days</Text>
      </View>
      {trouble ? (
        <Text style={s.weekSub}>
          {[w.refused && `${w.refused} refused`, w.skipped && `${w.skipped} skipped`, w.missed && `${w.missed} not marked`]
            .filter(Boolean).join(', ')}
        </Text>
      ) : <Text style={s.weekSub}>Nothing missed.</Text>}
      <Pressable
        onPress={() => router.push({ pathname: '/(tabs)/cura', params: { q: `Look at ${name}'s medicines over the last week. Is there a pattern in what was refused or missed, and what should I do or ask the doctor?` } })}
        accessibilityRole="button"
        style={{ alignSelf: 'flex-start', paddingVertical: 4 }}
      >
        <Text style={s.weekLink}>Ask Cura about this week</Text>
      </Pressable>
    </View>
  );
}

// ── Add sheet ───────────────────────────────────────────────

type Repeat = 'daily' | 'days' | 'once';

function AddSheet({
  visible, defaultDate, onClose, onSave,
}: {
  visible: boolean; defaultDate: string; onClose: () => void; onSave: (i: AddScheduleInput) => void;
}) {
  const [title, setTitle] = useState('');
  const [kind, setKind] = useState<ScheduleKind>('medication');
  const [hour, setHour] = useState('8');
  const [minute, setMinute] = useState('00');
  const [ampm, setAmpm] = useState<'AM' | 'PM'>('AM');
  const [repeat, setRepeat] = useState<Repeat>('daily');
  const [days, setDays] = useState<number[]>([]);
  const [date, setDate] = useState(defaultDate);
  const [detail, setDetail] = useState('');
  const [dose, setDose] = useState('');
  const [food, setFood] = useState<FoodRule>('any');
  const [purpose, setPurpose] = useState('');
  const [prescriber, setPrescriber] = useState('');
  const [place, setPlace] = useState('');
  const [steps, setSteps] = useState('');
  const [important, setImportant] = useState(false);
  const [course, setCourse] = useState('0');

  const h = Number(hour);
  const valid = title.trim().length > 1 && h >= 1 && h <= 12 && (repeat !== 'days' || days.length > 0);

  const reset = () => {
    setTitle(''); setDetail(''); setKind('medication'); setHour('8'); setMinute('00'); setAmpm('AM');
    setRepeat('daily'); setDays([]); setDose(''); setFood('any'); setPurpose(''); setPrescriber('');
    setPlace(''); setSteps(''); setImportant(false); setCourse('0');
  };

  const save = () => {
    const h24 = (h % 12) + (ampm === 'PM' ? 12 : 0);
    onSave({
      title: title.trim(),
      kind,
      time: `${String(h24).padStart(2, '0')}:${minute}`,
      days: repeat === 'days' ? days : [],
      date: repeat === 'once' ? date : undefined,
      detail: detail.trim(),
      ...(kind === 'medication' && dose.trim() ? { dose: dose.trim() } : {}),
      ...(kind === 'medication' && food !== 'any' ? { food } : {}),
      ...(purpose.trim() ? { purpose: purpose.trim() } : {}),
      ...(prescriber.trim() ? { prescriber: prescriber.trim() } : {}),
      ...(place.trim() ? { place: place.trim() } : {}),
      ...(steps.trim() ? { steps: steps.split('\n').map(x => x.trim()).filter(Boolean) } : {}),
      ...(important ? { important: true } : {}),
      ...(repeat !== 'once' && Number(course) > 0 ? { endDate: dateKey(Date.now() + Number(course) * 86400000) } : {}),
    });
    reset();
  };

  const upcoming = useMemo(() => Array.from({ length: 10 }, (_, o) => {
    const d = new Date(); d.setDate(d.getDate() + o);
    return { key: dateKey(d), label: o === 0 ? 'Today' : o === 1 ? 'Tomorrow' : `${DAY_NAMES[d.getDay()]} ${d.getDate()}` };
  }), []);

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <SafeAreaView style={s.sheet} edges={['top', 'bottom']}>
        <View style={s.sheetHead}>
          <Pressable onPress={onClose} hitSlop={10} accessibilityRole="button"><Text style={s.cancel}>Cancel</Text></Pressable>
          <Text style={s.sheetTitle}>Add to the schedule</Text>
          <View style={{ width: 52 }} />
        </View>
        <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <ScrollView contentContainerStyle={s.form} keyboardShouldPersistTaps="handled">
            <Field label="What" required>
              <Input value={title} onChangeText={setTitle} placeholder="Donepezil 5 mg" autoCapitalize="sentences" />
            </Field>
            <Field label="Type">
              <View style={s.wrap}>
                {KINDS.map(k => <Chip key={k} label={KIND_LABEL[k]} selected={kind === k} onPress={() => setKind(k)} />)}
              </View>
            </Field>
            <Field label="Time" required>
              <View style={s.timeRow}>
                <Input value={hour} onChangeText={t => setHour(t.replace(/\D/g, '').slice(0, 2))} keyboardType="number-pad" style={s.hour} />
                <Text style={s.colon}>:</Text>
                <View style={[s.wrap, { flex: 1 }]}>
                  {['00', '15', '30', '45'].map(m => <Chip key={m} label={m} selected={minute === m} onPress={() => setMinute(m)} />)}
                </View>
              </View>
              <Segmented options={[{ value: 'AM', label: 'AM' }, { value: 'PM', label: 'PM' }]} value={ampm} onChange={v => setAmpm(v as 'AM' | 'PM')} />
            </Field>
            <Field label="Repeats">
              <Segmented
                options={[{ value: 'daily', label: 'Every day' }, { value: 'days', label: 'Some days' }, { value: 'once', label: 'Once' }]}
                value={repeat} onChange={v => setRepeat(v as Repeat)}
              />
              {repeat === 'days' ? (
                <View style={[s.wrap, { marginTop: 10 }]}>
                  {DAY_NAMES.map((n, i) => (
                    <Chip key={n} label={n} selected={days.includes(i)} onPress={() => setDays(days.includes(i) ? days.filter(d => d !== i) : [...days, i])} />
                  ))}
                </View>
              ) : null}
              {repeat === 'once' ? (
                <View style={[s.wrap, { marginTop: 10 }]}>
                  {upcoming.map(u => <Chip key={u.key} label={u.label} selected={date === u.key} onPress={() => setDate(u.key)} />)}
                </View>
              ) : null}
            </Field>
            {kind === 'medication' ? (
              <>
                <Field label="Dose">
                  <Input value={dose} onChangeText={setDose} placeholder="5 mg, 1 tablet" />
                </Field>
                <Field label="With food?">
                  <View style={s.wrap}>
                    {(Object.keys(FOOD_LABEL) as FoodRule[]).map(f => (
                      <Chip key={f} label={FOOD_LABEL[f]} selected={food === f} onPress={() => setFood(f)} />
                    ))}
                  </View>
                </Field>
              </>
            ) : null}
            <Field label={kind === 'medication' ? 'What it is for' : 'Purpose'} hint="In plain words. Optional.">
              <Input value={purpose} onChangeText={setPurpose} placeholder={kind === 'medication' ? 'Blood pressure' : 'Keeps her moving'} />
            </Field>
            {kind === 'medication' || kind === 'appointment' ? (
              <Field label={kind === 'medication' ? 'Prescribed by' : 'With'}>
                <Input value={prescriber} onChangeText={setPrescriber} placeholder="Dr. Kulkarni" />
              </Field>
            ) : null}
            {kind === 'appointment' || kind === 'activity' ? (
              <Field label="Where">
                <Input value={place} onChangeText={setPlace} placeholder="Sahyadri Clinic, Kothrud" />
              </Field>
            ) : null}
            <Field label="Instructions" hint="How to give it, what helps, what to watch for. Optional.">
              <Input value={detail} onChangeText={setDetail} multiline placeholder="After breakfast, with water." />
            </Field>
            {kind === 'activity' || kind === 'other' || kind === 'meal' ? (
              <Field label="Steps" hint="One per line. Optional.">
                <Input value={steps} onChangeText={setSteps} multiline placeholder={'Slippers with grip\nHand on her elbow'} />
              </Field>
            ) : null}
            {repeat !== 'once' ? (
              <Field label="How long">
                <Segmented
                  options={[{ value: '0', label: 'Ongoing' }, { value: '7', label: '7 days' }, { value: '14', label: '14 days' }, { value: '30', label: '30 days' }]}
                  value={course} onChange={setCourse}
                />
              </Field>
            ) : null}
            <Field label="Importance">
              <View style={s.wrap}>
                <Chip label="Must not be missed" selected={important} onPress={() => setImportant(v => !v)} />
              </View>
            </Field>
          </ScrollView>
          <View style={s.footer}>
            <Button label="Add" disabled={!valid} onPress={save} />
          </View>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </Modal>
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: Colors.bgBase },
  header: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    paddingHorizontal: Spacing.md, paddingVertical: 10,
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.separator,
  },
  title: { ...Type.title, fontSize: 22, color: Colors.textStrong },
  sub: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', marginTop: 2 },
  addBtn: { width: 40, height: 40, borderRadius: 20, backgroundColor: Colors.brown, alignItems: 'center', justifyContent: 'center' },

  dayBar: { flexGrow: 0, flexShrink: 0, height: 86, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.separator },
  dayRow: { paddingHorizontal: Spacing.md, paddingVertical: 10, gap: 8 },
  day: { width: 58, alignItems: 'center', paddingVertical: 8, borderRadius: Radius.md, gap: 2 },
  dayOn: { backgroundColor: Colors.brown },
  dayLetter: { fontSize: 11, fontWeight: '600', color: Colors.textSecondary },
  dayNum: { fontSize: 18, fontWeight: '700', color: Colors.textStrong },
  dayTextOn: { color: Colors.textOnBrown },
  dayDot: { width: 5, height: 5, borderRadius: 3, backgroundColor: Colors.brown },

  list: { paddingHorizontal: Spacing.md, paddingTop: Spacing.sm },
  row: { flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', paddingVertical: 14, gap: 12 },
  rowRule: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator },
  rowMain: { flex: 1, flexDirection: 'row', gap: 14 },
  time: { width: 76, fontSize: 14, fontWeight: '700', color: Colors.textStrong, fontVariant: ['tabular-nums'], paddingTop: 1 },
  rowTitle: { fontSize: 16, fontWeight: '600', color: Colors.textStrong, lineHeight: 21 },
  rowTitleDone: { color: Colors.textSecondary },
  rowKind: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  status: { ...Type.caption, fontWeight: '600' },
  box: {
    width: 30, height: 30, borderRadius: 15, borderWidth: 2, borderColor: Colors.border,
    alignItems: 'center', justifyContent: 'center', backgroundColor: Colors.surfaceRaised,
  },
  boxOn: { backgroundColor: Colors.brown, borderColor: Colors.brown },
  boxBad: { borderColor: Colors.urgent },
  facts: { gap: 8 },
  fact: { flexDirection: 'row', gap: 10, alignItems: 'baseline' },
  factLabel: { fontSize: 10, fontWeight: '800', letterSpacing: 0.6, color: Colors.textSecondary, width: 96 },
  factValue: { ...Type.body, fontSize: 14, color: Colors.textPrimary, flex: 1 },
  step: { ...Type.body, fontSize: 14, color: Colors.textPrimary },
  logNote: { ...Type.body, fontSize: 14, fontStyle: 'italic', color: Colors.textSecondary },
  actions: { flexDirection: 'row', gap: 22, alignItems: 'center' },
  actionText: { fontSize: 13, fontWeight: '700', color: Colors.brown },
  week: {
    paddingVertical: 12, gap: 2, marginBottom: 4,
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.separator,
  },
  weekPct: { fontFamily: 'Fraunces_700Bold', fontSize: 28, color: Colors.textStrong },
  weekText: { ...Type.callout, color: Colors.textPrimary, flex: 1, fontWeight: '400' },
  weekSub: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  weekLink: { fontSize: 13, fontWeight: '700', color: Colors.brown },
  detail: { width: '100%', paddingLeft: 90, gap: 10 },
  detailText: { ...Type.body, fontSize: 14, color: Colors.textPrimary, lineHeight: 20 },
  detailMeta: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  remove: { fontSize: 13, fontWeight: '700', color: Colors.urgent },

  sheet: { flex: 1, backgroundColor: Colors.bgBase },
  sheetHead: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: Spacing.md, paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.separator,
  },
  sheetTitle: { ...Type.subhead, color: Colors.textStrong },
  cancel: { fontSize: 15, fontWeight: '600', color: Colors.brown, width: 52 },
  form: { padding: Spacing.md, gap: Spacing.md },
  wrap: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.sm },
  timeRow: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 8 },
  hour: { width: 64, textAlign: 'center', fontSize: 20, fontWeight: '700' },
  colon: { fontSize: 20, fontWeight: '700', color: Colors.textStrong },
  footer: {
    padding: Spacing.md, borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator,
    backgroundColor: Colors.bgBase,
  },
});
