/**
 * Join a care circle with a code.
 *
 * This is how a second relative (a sister in another country, a cousin across
 * town) gets the same view as the person who set Cura up: same notes, same
 * check-ins, same conversation with the caregiver, each in their own language.
 */
import { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, KeyboardAvoidingView, Platform } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { ScreenHeader } from '../../src/components/ScreenHeader';
import { Button, Chip, Field, Input } from '../../src/components/ui';
import { Colors, Spacing, Type } from '../../src/design/tokens';
import { LANGUAGES } from '../../src/ai/cura';
import { useApp } from '../../src/state/AppContext';
import { friendlyDbError } from '../../src/backend/remote';

export default function JoinCircle() {
  const { joinWithCode } = useApp();
  const [code, setCode] = useState('');
  const [name, setName] = useState('');
  const [relationship, setRelationship] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [language, setLanguage] = useState('en');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const valid =
    code.trim().length === 6 && name.trim().length > 1 && email.includes('@') && password.length >= 6;

  const go = async () => {
    setBusy(true);
    setError(null);
    try {
      await joinWithCode(
        {
          id: '', role: 'family', name: name.trim(), email: email.trim(), phone: '',
          language, relationship: relationship.trim() || 'Family',
        },
        code,
        password,
      );
      router.replace('/(tabs)');
    } catch (err) {
      setError(friendlyDbError(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <SafeAreaView style={s.safe} edges={['top']}>
      <ScreenHeader title="Join a care circle" onBack={() => router.back()} />
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView contentContainerStyle={s.scroll} keyboardShouldPersistTaps="handled">
          <Text style={s.lead}>Your family already uses Cura</Text>
          <Text style={s.sub}>
            Whoever set it up can find the 6-character code on their Info tab. Once you join you see the same
            updates they do, wherever you live.
          </Text>
          <Field label="Circle code" required>
            <Input
              value={code} onChangeText={t => setCode(t.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 6))}
              placeholder="A1B2C3" autoCapitalize="characters" autoCorrect={false}
              style={{ letterSpacing: 4, fontSize: 20, fontWeight: '700' }}
            />
          </Field>
          <Field label="Your name" required>
            <Input value={name} onChangeText={setName} placeholder="Sunita Rao" autoCapitalize="words" />
          </Field>
          <Field label="How you are related">
            <Input value={relationship} onChangeText={setRelationship} placeholder="Daughter" autoCapitalize="words" />
          </Field>
          <Field label="Email" required>
            <Input value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" placeholder="you@example.com" />
          </Field>
          <Field label="Password" hint="At least 6 characters." required>
            <Input value={password} onChangeText={setPassword} secureTextEntry autoCapitalize="none" />
          </Field>
          <Field label="Language you want to read in" hint="Messages from the caregiver are translated into this.">
            <View style={s.chipWrap}>
              {LANGUAGES.slice(0, 10).map(l => (
                <Chip key={l.code} label={l.native} selected={language === l.code} onPress={() => setLanguage(l.code)} />
              ))}
            </View>
          </Field>
          {error ? <Text style={s.error} accessibilityLiveRegion="polite">{error}</Text> : null}
          <Button label={busy ? 'Joining' : 'Join the circle'} icon="people-outline" disabled={!valid || busy} onPress={go} />
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { padding: Spacing.md, gap: Spacing.md, paddingBottom: Spacing.xxl },
  lead: { ...Type.title, color: Colors.textStrong },
  sub: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400' },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.sm },
  error: { ...Type.callout, color: Colors.urgent },
});
