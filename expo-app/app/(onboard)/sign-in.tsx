/**
 * Sign in to an existing Cura account. Works for family members and
 * caregivers alike; the account remembers which one you are.
 */
import { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, KeyboardAvoidingView, Platform } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { ScreenHeader } from '../../src/components/ScreenHeader';
import { Button, Field, Input } from '../../src/components/ui';
import { Colors, Spacing, Type } from '../../src/design/tokens';
import { useApp } from '../../src/state/AppContext';
import { friendlyDbError } from '../../src/backend/remote';

export default function SignIn() {
  const { signIn } = useApp();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const valid = email.includes('@') && password.length >= 6;

  const go = async () => {
    setBusy(true);
    setError(null);
    try {
      await signIn(email, password);
      router.replace('/');
    } catch (err) {
      setError(friendlyDbError(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <SafeAreaView style={s.safe} edges={['top']}>
      <ScreenHeader title="Sign in" onBack={() => router.back()} />
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView contentContainerStyle={s.scroll} keyboardShouldPersistTaps="handled">
          <Text style={s.lead}>Welcome back</Text>
          <Field label="Email">
            <Input
              value={email} onChangeText={setEmail} placeholder="you@example.com"
              keyboardType="email-address" autoCapitalize="none" autoComplete="email"
            />
          </Field>
          <Field label="Password">
            <Input
              value={password} onChangeText={setPassword} secureTextEntry
              autoCapitalize="none" autoComplete="password" onSubmitEditing={valid ? go : undefined}
            />
          </Field>
          {error ? <Text style={s.error} accessibilityLiveRegion="polite">{error}</Text> : null}
          <Button label={busy ? 'Signing in' : 'Sign in'} icon="log-in-outline" disabled={!valid || busy} onPress={go} />
          <View style={{ height: Spacing.md }} />
          <Button label="Create an account instead" variant="ghost" onPress={() => router.replace('/(onboard)/role')} />
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { padding: Spacing.md, gap: Spacing.md },
  lead: { ...Type.title, color: Colors.textStrong },
  error: { ...Type.callout, color: Colors.urgent },
});
