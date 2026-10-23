/**
 * Edit info.
 *
 * Everything both sides rely on lives here: your own account, the full care
 * profile, and the engagement. Changes flow straight into the AI context, so
 * fixing something here fixes every answer that follows.
 */
import { CircleCode } from '../../src/components/CircleCode';
import { useEffect, useMemo, useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, Pressable, KeyboardAvoidingView, Platform, Alert,
} from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import {
  Avatar, Banner, Button, Card, Chip, Field, Input, KeyValue, Pill, SectionHeader, Segmented,
} from '../../src/components/ui';
import { AddressField } from '../../src/components/AddressField';
import { Colors, Radius, Spacing, Type } from '../../src/design/tokens';
import { LANGUAGES, languageLabel } from '../../src/ai/cura';
import { initials, relativeTime, rupees } from '../../src/lib/format';
import { useApp } from '../../src/state/AppContext';
import type { Medication, PlaceResult, Pnc } from '../../src/models/types';

const CONDITIONS = [
  "Alzheimer's / dementia", 'Hypertension', 'Diabetes', 'Arthritis',
  "Parkinson's", 'Heart condition', 'Stroke recovery', 'Post-surgery',
  'Limited vision', 'Hearing loss', 'Depression / anxiety', 'Frailty',
];

export default function Profile() {
  const {
    state, me, them, activeInvite, pendingInvites, updateAccount, updatePnc, reset,
  } = useApp();
  const role = state.activeRole;
  const isFamily = role === 'family';

  // ── Account draft ─────────────────────────────────────────
  const [name, setName] = useState(me?.name ?? '');
  const [email, setEmail] = useState(me?.email ?? '');
  const [phone, setPhone] = useState(me?.phone ?? '');
  const [language, setLanguage] = useState(me?.language ?? 'en');
  const [relationship, setRelationship] = useState(me?.relationship ?? '');

  useEffect(() => {
    setName(me?.name ?? '');
    setEmail(me?.email ?? '');
    setPhone(me?.phone ?? '');
    setLanguage(me?.language ?? 'en');
    setRelationship(me?.relationship ?? '');
  }, [me]);

  const accountDirty =
    !!me &&
    (name !== me.name || email !== me.email || phone !== me.phone ||
      language !== me.language || (relationship || '') !== (me.relationship || ''));

  // ── Care profile draft ────────────────────────────────────
  const pnc = state.pnc;
  const [draft, setDraft] = useState<Pnc | null>(pnc);
  const [addressText, setAddressText] = useState(pnc?.address ?? '');
  const [place, setPlace] = useState<PlaceResult | null>(null);

  useEffect(() => {
    setDraft(pnc);
    setAddressText(pnc?.address ?? '');
    setPlace(null);
  }, [pnc]);

  const pncDirty = useMemo(() => {
    if (!pnc || !draft) return false;
    return JSON.stringify(pnc) !== JSON.stringify(draft) || !!place;
  }, [pnc, draft, place]);

  const set = <K extends keyof Pnc>(key: K, value: Pnc[K]) =>
    setDraft(d => (d ? { ...d, [key]: value } : d));

  const toggleCondition = (c: string) => {
    if (!draft) return;
    set(
      'conditions',
      draft.conditions.includes(c)
        ? draft.conditions.filter(x => x !== c)
        : [...draft.conditions, c],
    );
  };

  const addMedication = () => {
    if (!draft) return;
    const med: Medication = {
      id: `med-${Date.now().toString(36)}`,
      name: '', dose: '', schedule: '',
    };
    set('medications', [...draft.medications, med]);
  };

  const updateMedication = (id: string, patch: Partial<Medication>) => {
    if (!draft) return;
    set('medications', draft.medications.map(m => (m.id === id ? { ...m, ...patch } : m)));
  };

  const removeMedication = (id: string) => {
    if (!draft) return;
    set('medications', draft.medications.filter(m => m.id !== id));
  };

  const savePnc = () => {
    if (!draft) return;
    updatePnc({
      ...draft,
      ...(place ? { address: place.label, location: { lat: place.lat, lng: place.lng } } : {}),
    });
    setPlace(null);
  };

  const confirmReset = () => {
    const go = () => {
      reset().then(() => router.replace('/'));
    };
    if (Platform.OS === 'web' || state.live) { go(); return; }
    Alert.alert(
      'Sign out and clear this device?',
      'Everything stored on this phone (notes, check-ins and messages) is removed.',
      [{ text: 'Cancel', style: 'cancel' }, { text: 'Clear', style: 'destructive', onPress: go }],
    );
  };

  if (!me) return null;

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView style={s.screen} contentContainerStyle={s.scroll} showsVerticalScrollIndicator={false}>
        {/* ── Who you are ─────────────────────────────────── */}
        <View style={s.hero}>
          <Avatar initials={initials(me.name)} size={62} tone={isFamily ? Colors.textStrong : Colors.brown} />
          <View style={{ flex: 1 }}>
            <Text style={s.heroName}>{me.name}</Text>
            <Pill
              label={isFamily ? `${me.relationship || 'Family'} of ${pnc?.preferredName ?? 'them'}` : 'Caregiver'}
              tone={{ fg: Colors.brown, bg: Colors.accentSoft }}
            />
          </View>
        </View>

        {!isFamily && pendingInvites.length ? (
          <Banner
            icon="mail-unread-outline"
            tone="caution"
            title={`${pendingInvites.length} care request waiting`}
            action="Open"
            onAction={() => router.push('/(onboard)/invites')}
          />
        ) : null}

        <SectionHeader title="Your account" icon="person-outline" />
        <Card style={{ gap: Spacing.md }}>
          <Field label="Name"><Input value={name} onChangeText={setName} autoCapitalize="words" /></Field>
          <Field label="Email">
            <Input value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" />
          </Field>
          <Field label="Phone"><Input value={phone} onChangeText={setPhone} keyboardType="phone-pad" /></Field>
          {isFamily ? (
            <Field label="Relationship">
              <Input value={relationship} onChangeText={setRelationship} placeholder="Son, daughter, grandson…" />
            </Field>
          ) : null}
          <Field
            label="Your language"
            hint={`Messages are translated into ${languageLabel(language)} for you automatically.`}
          >
            <View style={s.chipWrap}>
              {LANGUAGES.map(l => (
                <Chip key={l.code} label={l.native} selected={language === l.code} onPress={() => setLanguage(l.code)} />
              ))}
            </View>
          </Field>
          {accountDirty ? (
            <Button
              label="Save account changes"
              icon="checkmark"
              onPress={() => updateAccount(role, { name, email, phone, language, relationship })}
            />
          ) : null}
        </Card>

        {/* ── Care profile ────────────────────────────────── */}
        {draft ? (
          <>
            <SectionHeader title={`About ${draft.preferredName || 'them'}`} icon="heart-outline" />
            <Card style={{ gap: Spacing.md }}>
              <View style={s.split}>
                <View style={{ flex: 1 }}>
                  <Field label="Called">
                    <Input value={draft.preferredName} onChangeText={v => set('preferredName', v)} autoCapitalize="words" />
                  </Field>
                </View>
                <View style={{ flex: 1 }}>
                  <Field label="Age">
                    <Input
                      value={String(draft.age)}
                      onChangeText={v => set('age', Number(v.replace(/\D/g, '')) || 0)}
                      keyboardType="number-pad"
                      maxLength={3}
                    />
                  </Field>
                </View>
              </View>

              <Field label="Full name">
                <Input value={draft.fullName} onChangeText={v => set('fullName', v)} autoCapitalize="words" />
              </Field>

              <Field label="Pronouns">
                <Segmented
                  options={[
                    { value: 'she/her', label: 'she/her' },
                    { value: 'he/him', label: 'he/him' },
                    { value: 'they/them', label: 'they/them' },
                  ]}
                  value={draft.pronouns}
                  onChange={v => set('pronouns', v)}
                />
              </Field>

              <Field label="Address" hint="Changing this changes which caregivers are nearby.">
                <AddressField
                  value={addressText}
                  onChangeText={setAddressText}
                  selected={place}
                  onSelect={p => setPlace(p)}
                />
              </Field>

              <Field label="Conditions">
                <View style={s.chipWrap}>
                  {Array.from(new Set([...CONDITIONS, ...draft.conditions])).map(c => (
                    <Chip
                      key={c}
                      label={c}
                      selected={draft.conditions.includes(c)}
                      onPress={() => toggleCondition(c)}
                    />
                  ))}
                </View>
              </Field>

              <Field label="Getting around">
                <Input value={draft.mobility} onChangeText={v => set('mobility', v)} multiline />
              </Field>

              <Field label="Food and diet">
                <Input value={draft.diet} onChangeText={v => set('diet', v)} multiline />
              </Field>

              <Field label="Allergies" hint="Cura AI flags these when you ask about medicines.">
                <Input value={draft.allergies} onChangeText={v => set('allergies', v)} placeholder="None known" />
              </Field>

              <Field label="Their usual day">
                <Input value={draft.routine} onChangeText={v => set('routine', v)} multiline />
              </Field>

              <Field label="What helps when they are upset">
                <Input value={draft.calmingNotes} onChangeText={v => set('calmingNotes', v)} multiline />
              </Field>

              <View style={s.split}>
                <View style={{ flex: 1 }}>
                  <Field label="Emergency contact">
                    <Input value={draft.emergencyContact} onChangeText={v => set('emergencyContact', v)} />
                  </Field>
                </View>
                <View style={{ flex: 1 }}>
                  <Field label="Emergency phone">
                    <Input value={draft.emergencyPhone} onChangeText={v => set('emergencyPhone', v)} keyboardType="phone-pad" />
                  </Field>
                </View>
              </View>
            </Card>

            {/* ── Medications ───────────────────────────────── */}
            <SectionHeader title="Medications" icon="medkit-outline" action="Add" onAction={addMedication} />
            <Card style={{ gap: Spacing.md }}>
              {draft.medications.length === 0 ? (
                <Text style={s.empty}>
                  No medications recorded. Add them so Cura AI can check interactions and timing.
                </Text>
              ) : (
                draft.medications.map(m => (
                  <View key={m.id} style={s.medRow}>
                    <View style={{ flex: 1, gap: 8 }}>
                      <Input
                        value={m.name}
                        onChangeText={v => updateMedication(m.id, { name: v })}
                        placeholder="Medicine name"
                      />
                      <View style={s.split}>
                        <Input
                          style={{ flex: 1 }}
                          value={m.dose}
                          onChangeText={v => updateMedication(m.id, { dose: v })}
                          placeholder="5 mg"
                        />
                        <Input
                          style={{ flex: 2 }}
                          value={m.schedule}
                          onChangeText={v => updateMedication(m.id, { schedule: v })}
                          placeholder="Once daily, after breakfast"
                        />
                      </View>
                    </View>
                    <Pressable
                      onPress={() => removeMedication(m.id)}
                      hitSlop={8}
                      accessibilityRole="button"
                      accessibilityLabel={`Remove ${m.name || 'medication'}`}
                      style={s.removeBtn}
                    >
                      <Ionicons name="close" size={16} color={Colors.urgent} />
                    </Pressable>
                  </View>
                ))
              )}
              <Text style={s.medNote}>
                Cura AI never changes a dose. It only tells you what to ask their doctor.
              </Text>
            </Card>

            {pncDirty ? (
              <Button label="Save care profile" icon="checkmark" onPress={savePnc} />
            ) : null}
          </>
        ) : null}

        {/* ── Engagement ──────────────────────────────────── */}
        <SectionHeader title="Care arrangement" icon="briefcase-outline" />
        {activeInvite ? (
          <Card style={{ gap: 2 }}>
            <View style={s.arrangeHead}>
              <Avatar
                initials={initials(isFamily ? activeInvite.caregiverName : activeInvite.familyName)}
                size={40}
                tone={isFamily ? Colors.brown : Colors.textStrong}
              />
              <View style={{ flex: 1 }}>
                <Text style={s.arrangeName}>
                  {isFamily ? activeInvite.caregiverName : activeInvite.familyName}
                </Text>
                <Text style={s.arrangeSub}>
                  Since {new Date(activeInvite.startDate).toLocaleDateString(undefined, { month: 'long', year: 'numeric' })}
                </Text>
              </View>
              <Pill label="Active" tone={{ fg: Colors.positive, bg: Colors.positiveSoft }} />
            </View>
            <View style={s.hr} />
            <KeyValue label="Schedule" value={activeInvite.scheduleSummary} />
            <KeyValue label="Rate" value={`${rupees(activeInvite.hourlyRate)}/hr`} />
            <KeyValue label="Estimated weekly" value={rupees(activeInvite.payment.weeklyTotal)} />
            <KeyValue label="Payment" value={state.demoMode ? activeInvite.payment.method : 'Arranged directly'} />
          </Card>
        ) : (
          <Card style={{ gap: 10 }}>
            <Text style={s.empty}>
              {isFamily ? 'No caregiver engaged yet.' : 'You have no active family yet.'}
            </Text>
            {isFamily ? (
              <Button
                label="Find a caregiver"
                variant="secondary"
                icon="search"
                onPress={() => router.push('/(onboard)/find-care')}
              />
            ) : (
              <Button
                label="See care requests"
                variant="secondary"
                icon="mail-outline"
                onPress={() => router.push('/(onboard)/invites')}
              />
            )}
          </Card>
        )}

        {isFamily && activeInvite ? (
          <Button
            label="Find a different caregiver"
            variant="secondary"
            icon="swap-horizontal"
            onPress={() => router.push('/(onboard)/find-care')}
          />
        ) : null}

        {/* ── Care circle ─────────────────────────────────── */}
        {state.live && state.circleId ? (
          <>
            <SectionHeader title="Care circle" icon="people-outline" />
            <Card style={{ gap: 12 }}>
              {state.members.map(m => (
                <View key={m.id} style={s.memberRow}>
                  <Avatar initials={initials(m.name)} size={34} tone={m.role === 'caregiver' ? Colors.brown : Colors.textStrong} />
                  <View style={{ flex: 1 }}>
                    <Text style={s.memberName}>{m.name}{m.id === me.id ? ' (you)' : ''}</Text>
                    <Text style={s.memberMeta}>
                      {m.role === 'caregiver' ? 'Caregiver' : m.relationship || 'Family'} · reads in {m.language.toUpperCase()}
                    </Text>
                  </View>
                </View>
              ))}
              {state.joinCode && state.pnc ? <CircleCode code={state.joinCode} name={state.pnc.preferredName} /> : null}
            </Card>
          </>
        ) : null}

        {/* ── Device ──────────────────────────────────────── */}
        <SectionHeader title="This device" icon="settings-outline" />
        <Card style={{ gap: 12 }}>
          {state.demoMode ? (
            <Banner
              icon="flask-outline"
              tone="info"
              title="Demo mode is on"
              body="The data here is made up, and the bar at the top lets you switch between both sides."
            />
          ) : null}
          <Text style={s.empty}>
            {state.live
              ? 'Signed in. Your care circle is saved in Cura and only its members can read it.'
              : 'Everything is stored on this device only. Nothing is uploaded except the questions you send to Cura AI.'}
          </Text>
          <Button
            label={state.live ? 'Sign out' : 'Sign out and clear data'}
            variant="danger"
            icon="log-out-outline"
            onPress={confirmReset}
          />
          <View style={s.legalRow}>
            <Pressable onPress={() => router.push('/terms')} accessibilityRole="link" hitSlop={8}>
              <Text style={s.legalLink}>Terms of Service</Text>
            </Pressable>
            <Pressable onPress={() => router.push('/privacy')} accessibilityRole="link" hitSlop={8}>
              <Text style={s.legalLink}>Privacy Policy</Text>
            </Pressable>
          </View>
        </Card>

        <Text style={s.legal}>
          Cura is not a medical service. Nothing here replaces advice from a doctor.
        </Text>
        <View style={{ height: Spacing.xl }} />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  memberRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  memberName: { ...Type.subhead, fontSize: 15, color: Colors.textStrong },
  memberMeta: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  codeBox: { gap: 6, paddingTop: 10, borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator },
  codeLabel: { ...Type.overline, color: Colors.textSecondary },
  code: { fontSize: 30, fontWeight: '800', letterSpacing: 6, color: Colors.textStrong, fontVariant: ['tabular-nums'] },
  legalRow: { flexDirection: 'row', gap: Spacing.lg, justifyContent: 'center', paddingTop: 4 },
  legalLink: { ...Type.caption, color: Colors.brown, fontWeight: '700' },
  screen: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { padding: Spacing.md, paddingTop: Spacing.sm },

  hero: { flexDirection: 'row', alignItems: 'center', gap: 14, paddingVertical: Spacing.sm },
  heroName: { ...Type.title, fontSize: 22, color: Colors.textStrong, marginBottom: 6 },

  split: { flexDirection: 'row', gap: Spacing.sm },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.sm },
  hr: { height: StyleSheet.hairlineWidth, backgroundColor: Colors.separator, marginVertical: 8 },
  empty: { ...Type.body, fontSize: 14, color: Colors.textSecondary, lineHeight: 20 },

  medRow: {
    flexDirection: 'row', alignItems: 'flex-start', gap: 8,
    backgroundColor: Colors.surfaceTinted, padding: 10, borderRadius: Radius.md,
  },
  removeBtn: {
    width: 28, height: 28, borderRadius: 14, backgroundColor: Colors.urgentSoft,
    alignItems: 'center', justifyContent: 'center', marginTop: 10,
  },
  medNote: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400', fontStyle: 'italic' },

  arrangeHead: { flexDirection: 'row', alignItems: 'center', gap: 11 },
  arrangeName: { ...Type.subhead, color: Colors.textStrong },
  arrangeSub: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', marginTop: 2 },

  legal: {
    ...Type.caption, color: Colors.textTertiary, fontWeight: '400',
    textAlign: 'center', marginTop: Spacing.lg,
  },
});
