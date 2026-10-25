/**
 * Family member sign-up: who you are, who needs care, and what they need.
 * On finish this writes the account + care profile and sends you to the
 * caregiver search built around their address.
 */
import { useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, KeyboardAvoidingView, Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { ScreenHeader } from '../../src/components/ScreenHeader';
import { AddressField } from '../../src/components/AddressField';
import { Button, Chip, Field, Input, Segmented } from '../../src/components/ui';
import { Colors, Radius, Spacing, Type } from '../../src/design/tokens';
import { LANGUAGES } from '../../src/ai/cura';
import { useApp } from '../../src/state/AppContext';
import { friendlyDbError } from '../../src/backend/remote';
import { timeLabel } from '../../src/lib/schedule';
import type { AddScheduleInput } from '../../src/state/AppContext';
import type { Account, Medication, PlaceResult, Pnc } from '../../src/models/types';

const DOSE_TIMES = [
  { value: '08:00', label: 'Morning' },
  { value: '13:00', label: 'Midday' },
  { value: '18:00', label: 'Evening' },
  { value: '21:00', label: 'Bedtime' },
];

const CONDITIONS = [
  "Alzheimer's / dementia", 'Hypertension', 'Diabetes', 'Arthritis',
  'Parkinson\'s', 'Heart condition', 'Stroke recovery', 'Post-surgery',
  'Limited vision', 'Hearing loss', 'Depression / anxiety', 'Frailty',
];

const MOBILITY = [
  { value: 'independent', label: 'Walks independently' },
  { value: 'aid', label: 'Uses a walker or cane' },
  { value: 'assisted', label: 'Needs help to move' },
  { value: 'bed', label: 'Mostly in bed' },
] as const;

const MOBILITY_TEXT: Record<string, string> = {
  independent: 'Walks independently, no aid needed.',
  aid: 'Walks with a walker or cane. Needs a steady surface and a hand on stairs.',
  assisted: 'Needs physical assistance to stand, walk and transfer.',
  bed: 'Mostly bed-bound. Needs help with turning, transfers and personal care.',
};

export default function FamilySignup() {
  const { signUpFamily, canGoLive } = useApp();
  const [password, setPassword] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [step, setStep] = useState(1);

  // Step 1 — you
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [relationship, setRelationship] = useState('');
  const [language, setLanguage] = useState('en');

  // Step 2 — them
  const [fullName, setFullName] = useState('');
  const [preferredName, setPreferredName] = useState('');
  const [age, setAge] = useState('');
  const [pronouns, setPronouns] = useState('she/her');
  const [addressText, setAddressText] = useState('');
  const [place, setPlace] = useState<PlaceResult | null>(null);

  // Step 3 — care
  const [conditions, setConditions] = useState<string[]>([]);
  const [mobility, setMobility] = useState<string>('aid');
  const [diet, setDiet] = useState('');
  const [careLanguages, setCareLanguages] = useState<string[]>([]);
  const [hours, setHours] = useState('6');
  const [routine, setRoutine] = useState('');
  const [calming, setCalming] = useState('');
  const [emergencyPhone, setEmergencyPhone] = useState('');

  // Step 4: medicines (optional). Each one also becomes a schedule entry.
  const [meds, setMeds] = useState<(Medication & { time: string })[]>([]);
  const [medName, setMedName] = useState('');
  const [medDose, setMedDose] = useState('');
  const [medTime, setMedTime] = useState('08:00');
  const typedMed = (): (Medication & { time: string }) | null => {
    if (!medName.trim()) return null;
    const when = DOSE_TIMES.find(t => t.value === medTime)?.label.toLowerCase() ?? 'daily';
    return {
      id: `med-${Date.now().toString(36)}`, name: medName.trim(), dose: medDose.trim(),
      schedule: `Once daily, ${when}`, time: medTime,
    };
  };
  const addMed = () => {
    const m = typedMed();
    if (!m) return;
    setMeds([...meds, m]);
    setMedName(''); setMedDose('');
  };

  const toggle = (list: string[], set: (v: string[]) => void, value: string) =>
    set(list.includes(value) ? list.filter(v => v !== value) : [...list, value]);

  const step1Valid =
    name.trim().length > 1 && email.includes('@') && (!canGoLive || password.length >= 6);
  const step2Valid =
    preferredName.trim().length > 0 && !!place && Number(age) > 0 && Number(age) < 130;
  const step3Valid = true; // everything on this step is optional

  const finish = async (skipMeds = false) => {
    if (!place) return;
    // A medicine that was typed but not added with the button still counts.
    const typed = skipMeds ? null : typedMed();
    const chosen = skipMeds ? [] : typed ? [...meds, typed] : meds;
    const account: Account = {
      id: `acct-family-${Date.now().toString(36)}`,
      role: 'family',
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      language,
      relationship: relationship.trim() || 'Family',
    };
    const pnc: Pnc = {
      id: `pnc-${Date.now().toString(36)}`,
      fullName: fullName.trim() || preferredName.trim(),
      preferredName: preferredName.trim(),
      age: Number(age),
      pronouns,
      address: place.label,
      location: { lat: place.lat, lng: place.lng },
      conditions,
      mobility: MOBILITY_TEXT[mobility],
      diet: diet.trim() || 'No special dietary requirements recorded.',
      languages: careLanguages.length ? careLanguages : ['English'],
      medications: chosen.map(({ time: _t, ...m }) => m),
      allergies: '',
      emergencyContact: `${name.trim()} (${relationship.trim() || 'family'})`,
      emergencyPhone: emergencyPhone.trim() || phone.trim(),
      routine: routine.trim() || 'No routine recorded yet.',
      calmingNotes: calming.trim() || 'Nothing recorded yet.',
      careHoursPerDay: Number(hours) || 6,
    };
    setSaving(true);
    setError(null);
    try {
      const firstSchedule: AddScheduleInput[] = chosen.map(m => ({
        title: m.name, kind: 'medication', time: m.time, days: [], detail: m.schedule,
        ...(m.dose ? { dose: m.dose } : {}),
      }));
      await signUpFamily(account, pnc, canGoLive ? password : undefined, firstSchedule);
      router.replace('/(onboard)/connect');
    } catch (err) {
      setError(friendlyDbError(err));
    } finally {
      setSaving(false);
    }
  };

  const canAdvance = step === 1 ? step1Valid : step === 2 ? step2Valid : true;

  return (
    <SafeAreaView style={s.safe} edges={['top']}>
      <ScreenHeader
        title="Set up care"
        subtitle={['About you', `About ${preferredName.trim() || 'them'}`, 'Their care needs', 'Medicines and records'][step - 1]}
        step={step + 1}
        totalSteps={5}
        onBack={step === 1 ? undefined : () => setStep(step - 1)}
      />

      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <ScrollView
          contentContainerStyle={s.scroll}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {step === 1 && (
            <View style={s.form}>
              <Text style={s.lead}>First, about you</Text>
              <Field label="Your name" required>
                <Input value={name} onChangeText={setName} placeholder="Raj Rao" autoCapitalize="words" />
              </Field>
              <Field label="Email" required>
                <Input
                  value={email} onChangeText={setEmail} placeholder="you@example.com"
                  keyboardType="email-address" autoCapitalize="none"
                />
              </Field>
              {canGoLive ? (
                <Field label="Password" hint="At least 6 characters." required>
                  <Input value={password} onChangeText={setPassword} secureTextEntry placeholder="Choose a password" autoCapitalize="none" />
                </Field>
              ) : null}
              <Field label="Phone">
                <Input value={phone} onChangeText={setPhone} placeholder="+91 98200 11234" keyboardType="phone-pad" />
              </Field>
              <Field label="Your relationship to them">
                <Input value={relationship} onChangeText={setRelationship} placeholder="Son, daughter, grandson…" />
              </Field>
              <Field
                label="Language you want to read in"
                hint="Messages from the caregiver are translated into this automatically."
              >
                <View style={s.chipWrap}>
                  {LANGUAGES.slice(0, 10).map(l => (
                    <Chip
                      key={l.code}
                      label={l.native}
                      selected={language === l.code}
                      onPress={() => setLanguage(l.code)}
                    />
                  ))}
                </View>
              </Field>
            </View>
          )}

          {step === 2 && (
            <View style={s.form}>
              <Text style={s.lead}>Who needs care?</Text>
              <Field label="What do you call them?" hint="A nickname is fine. This is what you will see everywhere." required>
                <Input value={preferredName} onChangeText={setPreferredName} placeholder="Aaji" autoCapitalize="words" />
              </Field>
              <Field label="Full name">
                <Input value={fullName} onChangeText={setFullName} placeholder="Meena Rao" autoCapitalize="words" />
              </Field>
              <View style={s.split}>
                <View style={{ flex: 1 }}>
                  <Field label="Age" required>
                    <Input value={age} onChangeText={setAge} placeholder="83" keyboardType="number-pad" maxLength={3} />
                  </Field>
                </View>
                <View style={{ flex: 1.6 }}>
                  <Field label="Pronouns">
                    <Segmented
                      options={[
                        { value: 'she/her', label: 'she/her' },
                        { value: 'he/him', label: 'he/him' },
                        { value: 'they/them', label: 'they' },
                      ]}
                      value={pronouns}
                      onChange={setPronouns}
                    />
                  </Field>
                </View>
              </View>
              <Field
                label="Where do they live?"
                hint="We search for caregivers around this address."
                required
              >
                <AddressField
                  value={addressText}
                  onChangeText={setAddressText}
                  selected={place}
                  onSelect={p => setPlace(p)}
                  placeholder="Shivaji Nagar, Pune"
                />
              </Field>
            </View>
          )}

          {step === 3 && (
            <View style={s.form}>
              <Text style={s.lead}>What does {preferredName.trim() || 'they'} need?</Text>
              <Text style={s.sub}>
                This is what caregivers see, and what Cura AI uses to answer your questions. You can
                change any of it later.
              </Text>

              <Field label="Conditions" hint="Tap any that apply.">
                <View style={s.chipWrap}>
                  {CONDITIONS.map(c => (
                    <Chip
                      key={c}
                      label={c}
                      selected={conditions.includes(c)}
                      onPress={() => toggle(conditions, setConditions, c)}
                    />
                  ))}
                </View>
              </Field>

              <Field label="Getting around">
                <View style={{ gap: Spacing.sm }}>
                  {MOBILITY.map(m => (
                    <Chip
                      key={m.value}
                      label={m.label}
                      selected={mobility === m.value}
                      onPress={() => setMobility(m.value)}
                    />
                  ))}
                </View>
              </Field>

              <Field label="Food and diet">
                <Input
                  value={diet} onChangeText={setDiet} multiline
                  placeholder="Soft vegetarian food, low salt. Prefers dal rice and chai."
                />
              </Field>

              <Field label="Languages they speak">
                <View style={s.chipWrap}>
                  {['English', 'Marathi', 'Hindi', 'Tamil', 'Telugu', 'Bengali', 'Gujarati', 'Kannada'].map(l => (
                    <Chip
                      key={l}
                      label={l}
                      selected={careLanguages.includes(l)}
                      onPress={() => toggle(careLanguages, setCareLanguages, l)}
                    />
                  ))}
                </View>
              </Field>

              <Field label="Hours of care per day">
                <Segmented
                  options={[
                    { value: '3', label: '3h' },
                    { value: '6', label: '6h' },
                    { value: '8', label: '8h' },
                    { value: '12', label: '12h' },
                    { value: '24', label: '24h' },
                  ]}
                  value={hours}
                  onChange={setHours}
                />
              </Field>

              <Field label="Their usual day" hint="When they wake, eat and rest. Anything a new caregiver should know.">
                <Input
                  value={routine} onChangeText={setRoutine} multiline
                  placeholder="Wakes around 6:30 with chai. Lunch at 1, then a nap. Restless from about 5pm."
                />
              </Field>

              <Field label="What helps when they are upset?">
                <Input
                  value={calming} onChangeText={setCalming} multiline
                  placeholder="Speak slowly in Marathi. Never argue. Agree and redirect. The photo album always works."
                />
              </Field>

              <Field label="Emergency phone">
                <Input
                  value={emergencyPhone} onChangeText={setEmergencyPhone}
                  placeholder={phone || '+91 98200 11234'} keyboardType="phone-pad"
                />
              </Field>
            </View>
          )}

          {step === 4 && (
            <View style={s.form}>
              <Text style={s.lead}>Medicines and records</Text>
              <Text style={s.sub}>
                Both are optional. Medicines you add here go straight onto the daily schedule so the caregiver knows
                when each one is due.
              </Text>

              <Field label="Add a medicine">
                <View style={{ gap: Spacing.sm }}>
                  <Input value={medName} onChangeText={setMedName} placeholder="Donepezil" autoCapitalize="words" />
                  <Input value={medDose} onChangeText={setMedDose} placeholder="5 mg" />
                  <View style={s.chipWrap}>
                    {DOSE_TIMES.map(t => (
                      <Chip key={t.value} label={`${t.label} ${timeLabel(t.value)}`} selected={medTime === t.value} onPress={() => setMedTime(t.value)} />
                    ))}
                  </View>
                  <Button label="Add medicine" variant="secondary" disabled={!medName.trim()} onPress={addMed} />
                </View>
              </Field>

              {meds.length > 0 ? (
                <View style={{ gap: Spacing.sm }}>
                  {meds.map(m => (
                    <View key={m.id} style={s.medRow}>
                      <View style={{ flex: 1 }}>
                        <Text style={s.medName}>{m.name}{m.dose ? ` ${m.dose}` : ''}</Text>
                        <Text style={s.medMeta}>{timeLabel(m.time)} every day</Text>
                      </View>
                      <Chip label="Remove" onPress={() => setMeds(meds.filter(x => x.id !== m.id))} />
                    </View>
                  ))}
                </View>
              ) : null}

              <Field label="Medical records">
                <Text style={s.sub}>
                  Skip this for now. Uploading records is not available yet. Cura AI uses the conditions, medicines and
                  notes you enter instead.
                </Text>
              </Field>
            </View>
          )}
        </ScrollView>

        <View style={s.footer}>
          {error ? <Text style={s.error} accessibilityLiveRegion="polite">{error}</Text> : null}
          <Button
            label={step === 4 ? (saving ? 'Setting up care' : 'Create account') : 'Continue'}
            icon={step === 4 ? undefined : 'arrow-forward'}
            disabled={!canAdvance || saving}
            onPress={() => (step === 4 ? finish() : setStep(step + 1))}
          />
          {step === 4 ? (
            <Button label="Skip medicines and records" variant="ghost" disabled={saving} onPress={() => finish(true)} />
          ) : null}
          {!canAdvance ? (
            <Text style={s.hint}>
              {step === 1
                ? (canGoLive ? 'Add your name, a valid email and a password of 6 or more characters.' : 'Add your name and a valid email to continue.')
                : step === 2
                  ? 'Add their name, age, and pick their address from the list.'
                  : ''}
            </Text>
          ) : null}
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { padding: Spacing.md, paddingBottom: Spacing.xxl },
  form: { gap: Spacing.md },
  lead: { ...Type.title, color: Colors.textStrong, marginBottom: 2 },
  sub: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400', marginTop: -10 },
  split: { flexDirection: 'row', gap: Spacing.sm },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.sm },
  error: { ...Type.callout, color: Colors.urgent, marginBottom: Spacing.sm },
  footer: {
    padding: Spacing.md, gap: 8,
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator,
    backgroundColor: Colors.bgBase,
  },
  hint: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400', textAlign: 'center' },
  medRow: {
    flexDirection: 'row', alignItems: 'center', gap: Spacing.sm, padding: Spacing.sm,
    borderRadius: Radius.md, borderWidth: 1, borderColor: Colors.separator, backgroundColor: Colors.surface,
  },
  medName: { ...Type.subhead, color: Colors.textStrong },
  medMeta: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
});
