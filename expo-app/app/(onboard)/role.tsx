import { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, Pressable } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { ScreenHeader } from '../../src/components/ScreenHeader';
import { Button } from '../../src/components/ui';
import { Colors, Radius, Spacing, Type } from '../../src/design/tokens';
import type { Role } from '../../src/models/types';

export default function RoleScreen() {
  const [role, setRole] = useState<Role | null>(null);

  return (
    <SafeAreaView style={s.safe} edges={['top']}>
      <ScreenHeader title="Join Cura" step={1} totalSteps={3} />

      <ScrollView contentContainerStyle={s.scroll} showsVerticalScrollIndicator={false}>
        <Text style={s.lead}>Which one are you?</Text>
        <Text style={s.sub}>
          This changes what you see. You can only pick one per account.
        </Text>

        <View style={{ gap: Spacing.sm, marginTop: Spacing.lg }}>
          <RoleCard
            selected={role === 'family'}
            onPress={() => setRole('family')}
            icon="people"
            title="Family member"
            tagline="I am arranging care for someone"
            bullets={[
              'Find a caregiver who lives near them, even if you live far away',
              'Read every day of their care and message the caregiver in your own language',
            ]}
          />
          <RoleCard
            selected={role === 'caregiver'}
            onPress={() => setRole('caregiver')}
            icon="medkit"
            title="Caregiver"
            tagline="I provide care professionally"
            bullets={[
              'Families nearby find you and send requests to your phone',
              'A short daily check-in keeps the whole family informed',
            ]}
          />
        </View>
      </ScrollView>

      <View style={s.footer}>
        <Button
          label="Continue"
          icon="arrow-forward"
          disabled={!role}
          onPress={() =>
            router.push(role === 'family' ? '/(onboard)/family' : '/(onboard)/caregiver')
          }
        />
      </View>
    </SafeAreaView>
  );
}

function RoleCard({
  selected, onPress, icon, title, tagline, bullets,
}: {
  selected: boolean;
  onPress: () => void;
  icon: React.ComponentProps<typeof Ionicons>['name'];
  title: string;
  tagline: string;
  bullets: string[];
}) {
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="radio"
      accessibilityState={{ selected }}
      accessibilityLabel={title}
      style={({ pressed }) => [
        s.roleCard,
        selected && { borderColor: Colors.brown, borderWidth: 2, backgroundColor: Colors.accentSoft },
        pressed && { opacity: 0.85 },
      ]}
    >
      <View style={s.roleHead}>
        <View style={{ flex: 1 }}>
          <Text style={s.roleTitle}>{title}</Text>
          <Text style={s.roleTagline}>{tagline}</Text>
        </View>
        <View style={[s.radio, selected && { borderColor: Colors.brown }]}>
          {selected ? <View style={s.radioDot} /> : null}
        </View>
      </View>
      <View style={s.bullets}>
        {bullets.map(b => (
          <View key={b} style={s.bulletRow}>
            <View style={s.bulletDot} />
            <Text style={s.bulletText}>{b}</Text>
          </View>
        ))}
      </View>
    </Pressable>
  );
}

const s = StyleSheet.create({
  bulletDot: { width: 4, height: 4, borderRadius: 2, backgroundColor: Colors.textTertiary },
  safe: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { padding: Spacing.md, paddingBottom: Spacing.xl },
  lead: { ...Type.title, color: Colors.textStrong, marginTop: Spacing.md },
  sub: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400', marginTop: 4 },

  roleCard: {
    gap: 12, padding: Spacing.md,
    backgroundColor: Colors.surface, borderRadius: Radius.xl,
    borderWidth: 2, borderColor: Colors.separator,
  },
  roleHead: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  roleIcon: {
    width: 44, height: 44, borderRadius: 22, backgroundColor: Colors.accentSoft,
    alignItems: 'center', justifyContent: 'center',
  },
  roleTitle: { ...Type.heading, color: Colors.textStrong },
  roleTagline: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', marginTop: 2 },
  radio: {
    width: 22, height: 22, borderRadius: 11, borderWidth: 2, borderColor: Colors.border,
    alignItems: 'center', justifyContent: 'center',
  },
  radioDot: { width: 11, height: 11, borderRadius: 6, backgroundColor: Colors.brown },

  bullets: { gap: 6, paddingLeft: 2, marginTop: 4 },
  bulletRow: { flexDirection: 'row', alignItems: 'center', gap: 7 },
  bulletText: { ...Type.caption, color: Colors.textPrimary, fontWeight: '400', flex: 1 },

  footer: {
    padding: Spacing.md,
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator,
    backgroundColor: Colors.bgBase,
  },
});
