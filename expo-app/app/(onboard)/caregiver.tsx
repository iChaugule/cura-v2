/**
 * Caregiver sign-up. Short on purpose: caregivers fill this in on a phone
 * between shifts. Where they work and how far they travel decides which
 * families can find them.
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
import { Colors, Spacing, Type } from '../../src/design/tokens';
import { LANGUAGES } from '../../src/ai/cura';
import { ALL_SPECIALTIES } from '../../src/data/caregivers';
import { useApp } from '../../src/state/AppContext';
import { friendlyDbError } from '../../src/backend/remote';
import type { Account, PlaceResult } from '../../src/models/types';

export default function CaregiverSignup() {
  const { signUpCaregiver, canGoLive } = useApp();
  const [step, setStep] = useState(1);

  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [language, setLanguage] = useState('en');
  const [password, setPassword] = useState('');

  const [areaText, setAreaText] = useState('');
  const [area, setArea] = useState<PlaceResult | null>(null);
  const [radius, setRadius] = useState('15');
  const [headline, setHeadline] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [years, setYears] = useState('5');
  const [rate, setRate] = useState('320');
  const [specialties, setSpecialties] = useState<string[]>([]);
  const [spokenLanguages, setSpokenLanguages] = useState<string[]>([]);
  const [bio, setBio] = useState('');
  const [more, setMore] = useState(false);

  const toggle = (list: string[], set: (v: string[]) => void, value: string) =>
    set(list.includes(value) ? list.filter(v => v !== value) : [...list, value]);

  const step1Valid =
    name.trim().length > 1 && email.includes('@') && (!canGoLive || password.length >= 6);
  const step2Valid = specialties.length > 0 && !!area;

  const finish = async () => {
    if (!area) return;
    const account: Account = {
      id: `acct-caregiver-${Date.now().toString(36)}`,
      role: 'caregiver',
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      language,
    };
    setSaving(true);
    setError(null);
    try {
      await signUpCaregiver(account, {
        hourlyRate: Number(rate) || 0,
        yearsExperience: Number(years) || 1,
        specialties,
        languages: spokenLanguages.length ? spokenLanguages : ['English'],
        bio: bio.trim(),
        headline: headline.trim() || specialties.slice(0, 2).join(' and '),
        areaLabel: area.shortLabel || area.label,
        location: { lat: area.lat, lng: area.lng },
        serviceRadiusKm: Number(radius) || 15,
      }, canGoLive ? password : undefined);
      router.replace('/(onboard)/invites');
    } catch (err) {
      setError(friendlyDbError(err));
    } finally {
      setSaving(false);
    }
  };

  return (
    <SafeAreaView style={s.safe} edges={['top']}>
      <ScreenHeader
        title="Join as a caregiver"
        subtitle={step === 1 ? 'Your details' : 'Your work'}
        step={step + 1}
        totalSteps={3}
        onBack={step === 1 ? undefined : () => setStep(1)}
      />

      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView
          contentContainerStyle={s.scroll}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {step === 1 ? (
            <View style={s.form}>
              <Text style={s.lead}>Tell families who you are</Text>
              <Field label="Your name" required>
                <Input value={name} onChangeText={setName} placeholder="Priya Sharma" autoCapitalize="words" />
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
                <Input value={phone} onChangeText={setPhone} placeholder="+91 98765 44321" keyboardType="phone-pad" />
              </Field>
              <Field
                label="Language you want to read in"
                hint="Messages from the family are translated into this automatically."
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
          ) : (
            <View style={s.form}>
              <Text style={s.lead}>What kind of care do you give?</Text>

              <Field label="Your specialization" hint="Pick everything you are confident with." required>
                <View style={s.chipWrap}>
                  {ALL_SPECIALTIES.map(sp => (
                    <Chip
                      key={sp}
                      label={sp}
                      selected={specialties.includes(sp)}
                      onPress={() => toggle(specialties, setSpecialties, sp)}
                    />
                  ))}
                </View>
              </Field>

              <Field label="Proof of training or experience">
                <Text style={s.proof}>
                  Certificates and licences can wait. Skip this for now. Families will see that your profile is not
                  verified yet.
                </Text>
              </Field>

              <Field
                label="Where you work"
                hint="Your neighbourhood or town. Families see the area, never your address."
                required
              >
                <AddressField
                  value={areaText}
                  onChangeText={setAreaText}
                  selected={area}
                  onSelect={p => setArea(p)}
                  placeholder="Kothrud, Pune"
                />
              </Field>

              <Field label="How far you will travel">
                <Segmented
                  options={['5', '10', '15', '25', '40'].map(k => ({ value: k, label: `${k} km` }))}
                  value={radius}
                  onChange={setRadius}
                />
              </Field>

              <Field label="Years of experience">
                <Segmented
                  options={['1', '3', '5', '8', '10'].map(y => ({ value: y, label: `${y}+` }))}
                  value={years}
                  onChange={setYears}
                />
              </Field>

              <Button
                label={more ? 'Hide extra details' : 'Add more about you (optional)'}
                variant="ghost"
                onPress={() => setMore(v => !v)}
              />

              {more ? (
                <>
                  <Field label="One line about you" hint="Shown under your name in search.">
                    <Input value={headline} onChangeText={setHeadline} placeholder="Memory care, 6 years, Marathi speaker" />
                  </Field>
                  <Field label="Your hourly rate (₹)">
                    <Input value={rate} onChangeText={setRate} keyboardType="number-pad" placeholder="320" />
                  </Field>
                  <Field label="Languages you speak">
                    <View style={s.chipWrap}>
                      {['English', 'Marathi', 'Hindi', 'Tamil', 'Telugu', 'Bengali', 'Gujarati', 'Malayalam'].map(l => (
                        <Chip
                          key={l}
                          label={l}
                          selected={spokenLanguages.includes(l)}
                          onPress={() => toggle(spokenLanguages, setSpokenLanguages, l)}
                        />
                      ))}
                    </View>
                  </Field>
                  <Field label="About you" hint="Two or three honest sentences.">
                    <Input
                      value={bio} onChangeText={setBio} multiline
                      placeholder="6 years in memory care. Calm, unhurried approach, and I write a full note every day."
                    />
                  </Field>
                </>
              ) : null}
            </View>
          )}
        </ScrollView>

        <View style={s.footer}>
          {error ? <Text style={s.error} accessibilityLiveRegion="polite">{error}</Text> : null}
          <Button
            label={step === 1 ? 'Continue' : saving ? 'Creating your profile' : 'Create my profile'}
            icon={step === 1 ? 'arrow-forward' : undefined}
            disabled={(step === 1 ? !step1Valid : !step2Valid) || saving}
            onPress={() => (step === 1 ? setStep(2) : finish())}
          />
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { padding: Spacing.md, paddingBottom: Spacing.xxl },
  form: { gap: Spacing.md },
  lead: { ...Type.title, color: Colors.textStrong },
  proof: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400' },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.sm },
  error: { ...Type.callout, color: Colors.urgent, marginBottom: Spacing.sm },
  footer: {
    padding: Spacing.md,
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator,
    backgroundColor: Colors.bgBase,
  },
});
