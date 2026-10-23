/**
 * Request sent. From here you can either enter the app, or jump across to the
 * caregiver's inbox to see the other half of the handshake.
 */
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router, useLocalSearchParams } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Button, Card, KeyValue } from '../../src/components/ui';
import { Colors, Radius, Spacing, Type, Shadow } from '../../src/design/tokens';
import { rupees } from '../../src/lib/format';
import { useApp } from '../../src/state/AppContext';

export default function InviteSent() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { state, setActiveRole, ensureCaregiverAccount } = useApp();
  const invite = state.invites.find(i => i.id === id) ?? state.invites[0];

  const viewAsCaregiver = () => {
    if (invite) ensureCaregiverAccount(invite.caregiverName);
    setActiveRole('caregiver');
    router.replace('/(onboard)/invites');
  };

  return (
    <SafeAreaView style={s.safe} edges={['top']}>
      <ScrollView contentContainerStyle={s.scroll} showsVerticalScrollIndicator={false}>
        <View style={s.hero}>
          <View style={s.check}>
            <Ionicons name="checkmark" size={34} color={Colors.textOnBrown} />
          </View>
          <Text style={s.title}>Request sent</Text>
          <Text style={s.sub}>
            {invite?.caregiverName ?? 'The caregiver'} sees it on their phone now. You will see their answer here as soon as they reply.
          </Text>
        </View>

        {invite ? (
          <Card style={{ gap: 2 }}>
            <KeyValue label="Caregiver" value={invite.caregiverName} />
            <KeyValue label="Schedule" value={invite.scheduleSummary} />
            <KeyValue label="Starting" value={new Date(invite.startDate).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' })} />
            <KeyValue label="Rate" value={`${rupees(invite.hourlyRate)}/hr · ${invite.hoursPerDay}h a day`} />
          </Card>
        ) : null}

        {state.demoMode ? (
        <Card style={s.demoCard}>
          <View style={s.demoTag}>
            <Text style={s.demoTagText}>DEMO</Text>
          </View>
          <Text style={s.demoTitle}>See the caregiver&apos;s side</Text>
          <Text style={s.demoBody}>
            In the real product this request lands on the caregiver&apos;s phone. Jump across to their
            inbox to accept or decline it.
          </Text>
          <Button
            label="Open caregiver inbox"
            variant="secondary"
            icon="arrow-forward"
            onPress={viewAsCaregiver}
          />
        </Card>
        ) : null}

        <Button
          label="Continue to Cura"
          icon="home-outline"
          onPress={() => router.replace('/(tabs)')}
        />
      </ScrollView>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { padding: Spacing.md, gap: Spacing.md, paddingBottom: Spacing.xl, flexGrow: 1 },

  hero: { alignItems: 'center', gap: 8, paddingVertical: Spacing.xl },
  check: {
    width: 72, height: 72, borderRadius: 36, backgroundColor: Colors.positive,
    alignItems: 'center', justifyContent: 'center', marginBottom: 6,
  },
  title: { ...Type.title, color: Colors.textStrong },
  sub: {
    ...Type.callout, color: Colors.textSecondary, fontWeight: '400',
    textAlign: 'center', maxWidth: 300, lineHeight: 20,
  },

  divider: { height: StyleSheet.hairlineWidth, backgroundColor: Colors.separator, marginVertical: 6 },
  hold: {
    flexDirection: 'row', gap: 8, alignItems: 'flex-start',
    backgroundColor: Colors.positiveSoft, padding: 10, borderRadius: Radius.md, marginTop: 8,
  },
  holdText: { fontSize: 12, color: Colors.textPrimary, lineHeight: 17, flex: 1 },

  demoCard: { gap: 10, backgroundColor: Colors.surfaceTinted },
  demoTag: {
    flexDirection: 'row', alignItems: 'center', gap: 5, alignSelf: 'flex-start',
    backgroundColor: Colors.brown, paddingHorizontal: 9, paddingVertical: 4, borderRadius: Radius.pill,
  },
  demoTagText: { ...Type.overline, fontSize: 10, color: Colors.textOnBrown },
  demoTitle: { ...Type.heading, color: Colors.textStrong },
  demoBody: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400', lineHeight: 20 },
});
