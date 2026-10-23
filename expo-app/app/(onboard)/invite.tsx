/**
 * Send a care request.
 *
 * Payment is authorized here but not charged — the money is only captured once
 * the caregiver accepts. Payment methods are mock entries on purpose: this is a
 * demo, so nothing ever collects real card details.
 */
import { useMemo, useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, KeyboardAvoidingView, Platform, Pressable,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router, useLocalSearchParams } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { ScreenHeader } from '../../src/components/ScreenHeader';
import {
  Avatar, Button, Card, EmptyState, Field, Input, Segmented,
} from '../../src/components/ui';
import { Colors, Radius, Spacing, Type } from '../../src/design/tokens';
import { rupees } from '../../src/lib/format';
import { formatDistance } from '../../src/lib/geo';
import { useApp } from '../../src/state/AppContext';
import { friendlyDbError } from '../../src/backend/remote';

const PAYMENT_METHODS = [
  { id: 'visa', label: 'Visa •••• 4242', icon: 'card-outline' as const, sub: 'Demo card' },
  { id: 'upi', label: 'UPI: raj@okbank', icon: 'phone-portrait-outline' as const, sub: 'Demo UPI handle' },
];

const SCHEDULES = [
  { value: '6', label: 'Mon–Sat', days: 6 },
  { value: '5', label: 'Mon–Fri', days: 5 },
  { value: '7', label: 'Every day', days: 7 },
  { value: '3', label: '3 days/wk', days: 3 },
];

const SHIFTS = [
  { value: 'morning', label: 'Morning', text: '8:00 AM – 2:00 PM' },
  { value: 'afternoon', label: 'Afternoon', text: '12:00 PM – 6:00 PM' },
  { value: 'evening', label: 'Evening', text: '4:00 PM – 10:00 PM' },
  { value: 'overnight', label: 'Overnight', text: '9:00 PM – 7:00 AM' },
];

export default function InviteScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { state, sendInvite } = useApp();
  const [error, setError] = useState<string | null>(null);
  const pnc = state.pnc;

  const caregiver = useMemo(
    () => state.nearby.find(c => c.id === id),
    [state.nearby, id],
  );

  const [days, setDays] = useState('6');
  const [shift, setShift] = useState('morning');
  const [hours, setHours] = useState(String(pnc?.careHoursPerDay ?? 6));
  const [message, setMessage] = useState(
    pnc
      ? `${pnc.preferredName} is ${pnc.age}${pnc.conditions.length ? ` and lives with ${pnc.conditions[0]}` : ''}. ` +
        `We are looking for someone patient and consistent.`
      : '',
  );
  const [method, setMethod] = useState(PAYMENT_METHODS[0].id);
  const [sending, setSending] = useState(false);

  if (!caregiver || !pnc) {
    return (
      <SafeAreaView style={s.safe} edges={['top']}>
        <ScreenHeader title="Request care" />
        <EmptyState
          icon="person-outline"
          title="Caregiver not found"
          body="Go back and pick someone from the list."
          action="Back to search"
          onAction={() => router.back()}
        />
      </SafeAreaView>
    );
  }

  const daysPerWeek = SCHEDULES.find(x => x.value === days)?.days ?? 6;
  const hoursPerDay = Number(hours) || 6;
  const weekly = daysPerWeek * hoursPerDay * caregiver.hourlyRate;
  const fee = Math.round(weekly * 0.08);
  const total = weekly + fee;
  const shiftText = SHIFTS.find(x => x.value === shift)?.text ?? '8:00 AM – 2:00 PM';
  const scheduleSummary = `${SCHEDULES.find(x => x.value === days)?.label}, ${shiftText}`;

  const onSend = async () => {
    setSending(true);
    setError(null);
    const startDate = new Date(Date.now() + 2 * 86_400_000).toISOString().slice(0, 10);
    try {
      const invite = await sendInvite({
      caregiver,
      startDate,
      scheduleSummary,
      hoursPerDay,
      daysPerWeek,
      message: message.trim(),
      paymentMethod: 'Arranged directly',
      });
      router.replace({ pathname: '/(onboard)/sent', params: { id: invite.id } });
    } catch (err) {
      setError(friendlyDbError(err));
    } finally {
      setSending(false);
    }
  };

  return (
    <SafeAreaView style={s.safe} edges={['top']}>
      <ScreenHeader title="Request care" subtitle={caregiver.name} step={4} totalSteps={4} />

      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView
          contentContainerStyle={s.scroll}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <Card style={s.cgCard}>
            <Avatar initials={caregiver.photoInitials} size={52} />
            <View style={{ flex: 1, gap: 2 }}>
              <Text style={s.cgName}>{caregiver.name}</Text>
              <Text style={s.cgHeadline} numberOfLines={2}>{caregiver.headline}</Text>
              <View style={s.cgMeta}>
                {caregiver.reviewCount > 0 ? (
                  <>
                    <Ionicons name="star" size={12} color={Colors.caution} />
                    <Text style={s.cgMetaText}>{caregiver.rating.toFixed(1)}</Text>
                    <Text style={s.dot}>·</Text>
                  </>
                ) : null}
                <Text style={s.cgMetaText}>{formatDistance(caregiver.distanceKm ?? 0)}</Text>
                <Text style={s.dot}>·</Text>
                <Text style={s.cgMetaText}>{rupees(caregiver.hourlyRate)}/hr</Text>
              </View>
            </View>
          </Card>

          <View style={s.form}>
            <Field label="Which days?">
              <Segmented
                options={SCHEDULES.map(x => ({ value: x.value, label: x.label }))}
                value={days}
                onChange={setDays}
              />
            </Field>

            <Field label="Which shift?">
              <Segmented
                options={SHIFTS.map(x => ({ value: x.value, label: x.label }))}
                value={shift}
                onChange={setShift}
              />
              <Text style={s.shiftHint}>{shiftText}</Text>
            </Field>

            <Field label="Hours per day">
              <Segmented
                options={['3', '4', '6', '8', '12'].map(h => ({ value: h, label: `${h}h` }))}
                value={hours}
                onChange={setHours}
              />
            </Field>

            <Field label={`A note to ${caregiver.name.split(' ')[0]}`} hint="What should they know before saying yes?">
              <Input value={message} onChangeText={setMessage} multiline />
            </Field>
          </View>

          <Card style={s.breakdown}>
            <Row label={`${rupees(caregiver.hourlyRate)} × ${hoursPerDay}h × ${daysPerWeek} days`} value={rupees(weekly)} />
            <View style={s.divider} />
            <Row label="Estimated weekly cost" value={rupees(weekly)} strong />
            <View style={s.holdNote}>
              <Text style={s.holdText}>
                Payments in Cura are not live yet. Nothing is charged. Agree on payment with{' '}
                {caregiver.name.split(' ')[0]} directly once they accept.
              </Text>
            </View>
          </Card>
        </ScrollView>

        <View style={s.footer}>
          {error ? <Text style={s.error} accessibilityLiveRegion="polite">{error}</Text> : null}
          <Button
            label={sending ? 'Sending' : `Send request to ${caregiver.name.split(' ')[0]}`}
            icon="paper-plane"
            loading={sending}
            onPress={onSend}
          />
          <Text style={s.legal}>
            {caregiver.name.split(' ')[0]} sees your request on their phone and can accept or decline.
          </Text>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

function Row({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <View style={s.breakRow}>
      <Text style={[s.breakLabel, strong && { color: Colors.textStrong, fontWeight: '700' }]}>{label}</Text>
      <Text style={[s.breakValue, strong && { fontSize: 17 }]}>{value}</Text>
    </View>
  );
}

const s = StyleSheet.create({
  error: { ...Type.callout, color: Colors.urgent, marginBottom: Spacing.sm },
  safe: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { padding: Spacing.md, paddingBottom: Spacing.xl, gap: Spacing.md },

  cgCard: { flexDirection: 'row', gap: 12, alignItems: 'center' },
  cgName: { ...Type.heading, color: Colors.textStrong },
  cgHeadline: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  cgMeta: { flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 2 },
  cgMetaText: { ...Type.caption, color: Colors.textPrimary, fontWeight: '600' },
  dot: { color: Colors.textTertiary },

  form: { gap: Spacing.md },
  shiftHint: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', marginTop: 6, textAlign: 'center' },

  sectionLabel: { ...Type.overline, color: Colors.textSecondary, marginTop: Spacing.xs },
  payRow: {
    flexDirection: 'row', alignItems: 'center', gap: 12,
    padding: 14, borderRadius: Radius.lg, backgroundColor: Colors.surface,
    borderWidth: 1.5, borderColor: Colors.separator,
  },
  payLabel: { ...Type.callout, color: Colors.textStrong, fontWeight: '600' },
  paySub: { fontSize: 11, color: Colors.textTertiary, marginTop: 1 },
  radio: {
    width: 20, height: 20, borderRadius: 10, borderWidth: 2, borderColor: Colors.border,
    alignItems: 'center', justifyContent: 'center',
  },
  radioDot: { width: 10, height: 10, borderRadius: 5, backgroundColor: Colors.brown },

  breakdown: { gap: 2 },
  breakRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 5, gap: 12 },
  breakLabel: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400', flex: 1 },
  breakValue: { ...Type.callout, color: Colors.textStrong, fontWeight: '700' },
  divider: { height: StyleSheet.hairlineWidth, backgroundColor: Colors.separator, marginVertical: 6 },
  holdNote: {
    flexDirection: 'row', gap: 8, alignItems: 'flex-start',
    backgroundColor: Colors.positiveSoft, padding: 10, borderRadius: Radius.md, marginTop: 8,
  },
  holdText: { fontSize: 12, color: Colors.textPrimary, lineHeight: 17, flex: 1 },

  footer: {
    padding: Spacing.md, gap: 6,
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator,
    backgroundColor: Colors.bgBase,
  },
  legal: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400', textAlign: 'center' },
});
