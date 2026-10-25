/**
 * Last step of family sign-up: how do you want to bring care in?
 * Find a provider near their home, or hand out a join code so a caregiver (and
 * more relatives) can join this circle themselves. Both can be done later.
 */
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { ScreenHeader } from '../../src/components/ScreenHeader';
import { CircleCode } from '../../src/components/CircleCode';
import { Button, Card } from '../../src/components/ui';
import { Colors, Spacing, Type } from '../../src/design/tokens';
import { useApp } from '../../src/state/AppContext';

export default function Connect() {
  const { state } = useApp();
  const name = state.pnc?.preferredName ?? 'them';

  return (
    <SafeAreaView style={s.safe} edges={['top', 'bottom']}>
      <ScreenHeader title="Bring in care" subtitle="Your account is ready" />
      <ScrollView contentContainerStyle={s.scroll} showsVerticalScrollIndicator={false}>
        <Text style={s.lead}>Who will look after {name}?</Text>
        <Text style={s.sub}>Pick one now, or do both. You can come back to either from your home screen.</Text>

        <Card style={s.card}>
          <Text style={s.cardTitle}>Find a care provider nearby</Text>
          <Text style={s.cardBody}>
            Search caregivers on Cura and care providers near {name}&apos;s home, then send a request.
          </Text>
          <Button label={`Search near ${name}`} icon="search" onPress={() => router.push('/(onboard)/find-care')} />
        </Card>

        <Card style={s.card}>
          <Text style={s.cardTitle}>Invite with a join code</Text>
          {state.joinCode ? (
            <CircleCode code={state.joinCode} name={name} />
          ) : (
            <Text style={s.cardBody}>
              Join codes are created with a real Cura account. In the demo there is no circle to share.
            </Text>
          )}
        </Card>
      </ScrollView>
      <View style={s.footer}>
        <Button label="Go to my dashboard" onPress={() => router.replace('/(tabs)')} />
      </View>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { padding: Spacing.md, gap: Spacing.md, paddingBottom: Spacing.xxl },
  lead: { ...Type.title, color: Colors.textStrong },
  sub: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400' },
  card: { gap: 12 },
  cardTitle: { fontFamily: 'Fraunces_600SemiBold', fontSize: 18, color: Colors.textStrong },
  cardBody: { ...Type.callout, color: Colors.textPrimary, fontWeight: '400', lineHeight: 20 },
  footer: { padding: Spacing.md, borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator, backgroundColor: Colors.bgBase },
});
