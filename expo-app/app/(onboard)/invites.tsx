/**
 * The caregiver's inbox — the other half of the handshake.
 *
 * Accepting captures the family's authorized payment; declining releases it.
 */
import { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, Pressable, ActivityIndicator } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { ScreenHeader } from '../../src/components/ScreenHeader';
import { Avatar, Button, Card, Chip, EmptyState, Field, Input, KeyValue, Pill, Segmented } from '../../src/components/ui';
import { Colors, Radius, Spacing, Type } from '../../src/design/tokens';
import { initials, relativeTime, rupees } from '../../src/lib/format';
import { useApp } from '../../src/state/AppContext';
import { friendlyDbError } from '../../src/backend/remote';
import type { CareInvite } from '../../src/models/types';

const DECLINE_REASONS = [
  'My schedule is full',
  'Too far from me',
  'Not my area of care',
  'Rate does not work for me',
];

export default function CaregiverInbox() {
  const { state, respondToInvite, refresh, reset, joinCircleWithCode } = useApp();
  const [tab, setTab] = useState<'requests' | 'code'>('requests');
  const [code, setCode] = useState('');
  const [joining, setJoining] = useState(false);
  const [codeError, setCodeError] = useState<string | null>(null);
  /** A signed-in caregiver no family has connected with yet. */
  const noCircle = state.live && !state.circleId;
  const pnc = state.pnc;

  const [busy, setBusy] = useState<string | null>(null);
  const [decliningId, setDecliningId] = useState<string | null>(null);
  const [settled, setSettled] = useState<{ id: string; accepted: boolean } | null>(null);

  const pending = state.invites.filter(i => i.status === 'pending');
  const responded = state.invites.filter(i => i.status !== 'pending');

  const [error, setError] = useState<string | null>(null);

  const answer = async (invite: CareInvite, accepted: boolean, reason?: string) => {
    setBusy(invite.id);
    setError(null);
    try {
      await respondToInvite(invite.id, accepted ? 'accepted' : 'declined', reason);
      setDecliningId(null);
      setSettled({ id: invite.id, accepted });
    } catch (err) {
      setError(friendlyDbError(err));
    } finally {
      setBusy(null);
    }
  };
  const accept = (invite: CareInvite) => answer(invite, true);
  const decline = (invite: CareInvite, reason: string) => answer(invite, false, reason);

  const joinNow = async () => {
    setJoining(true);
    setCodeError(null);
    try {
      await joinCircleWithCode(code, 'caregiver');
      router.replace('/(tabs)');
    } catch (err) {
      setCodeError(friendlyDbError(err));
    } finally {
      setJoining(false);
    }
  };

  const tabs = (
    <Segmented
      options={[
        { value: 'requests', label: `Requests${pending.length ? ` (${pending.length})` : ''}` },
        { value: 'code', label: 'Enter a code' },
      ]}
      value={tab}
      onChange={v => setTab(v as 'requests' | 'code')}
    />
  );

  if (settled) {
    const invite = state.invites.find(i => i.id === settled.id);
    return (
      <SafeAreaView style={s.safe} edges={['top']}>
        <ScrollView contentContainerStyle={s.resultScroll}>
          <View
            style={[
              s.resultIcon,
              { backgroundColor: settled.accepted ? Colors.positive : Colors.surfaceTinted },
            ]}
          >
            <Ionicons
              name={settled.accepted ? 'checkmark' : 'close'}
              size={34}
              color={settled.accepted ? Colors.textOnBrown : Colors.textSecondary}
            />
          </View>
          <Text style={s.resultTitle}>
            {settled.accepted ? 'You accepted' : 'Request declined'}
          </Text>
          <Text style={s.resultBody}>
            {settled.accepted
              ? `${invite?.familyName ?? 'The family'} has been notified and you start on ${
                  invite ? new Date(invite.startDate).toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric' }) : 'the agreed date'
                }.`
              : `${invite?.familyName ?? 'The family'} has been told, so they can look for someone else.`}
          </Text>

          <Button label="Go to Cura" icon="arrow-forward" onPress={() => router.replace('/(tabs)')} />
          {state.demoMode && state.familyAccount ? (
            <Button
              label="Back to the family view"
              variant="ghost"
              icon="swap-horizontal"
              onPress={() => router.replace('/(tabs)')}
            />
          ) : null}
        </ScrollView>
      </SafeAreaView>
    );
  }

  if (tab === 'code') {
    return (
      <SafeAreaView style={s.safe} edges={['top']}>
        <ScreenHeader
          title="Join a care circle"
          subtitle="Use the code a family gave you"
          onBack={router.canGoBack() ? () => router.back() : undefined}
          right={
            noCircle ? (
              <Pressable onPress={() => reset().then(() => router.replace('/'))} hitSlop={8} accessibilityRole="button">
                <Text style={s.skip}>Sign out</Text>
              </Pressable>
            ) : undefined
          }
        />
        <ScrollView contentContainerStyle={s.scroll} keyboardShouldPersistTaps="handled">
          {tabs}
          <Text style={s.codeLead}>Enter the 6-character code</Text>
          <Text style={s.codeSub}>
            The family finds it on their Cura home screen. Once you join, you see the care profile, the schedule and the
            notes, and you can message everyone in the circle.
          </Text>
          <Field label="Circle code">
            <Input
              value={code}
              onChangeText={t => setCode(t.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 6))}
              placeholder="A1B2C3" autoCapitalize="characters" autoCorrect={false}
              style={{ letterSpacing: 4, fontSize: 20, fontWeight: '700' }}
            />
          </Field>
          {!state.live ? (
            <Text style={s.codeSub}>Codes work with a real Cura account. This is the demo, so there is nothing to join.</Text>
          ) : null}
          {codeError ? <Text style={s.errorText} accessibilityLiveRegion="polite">{codeError}</Text> : null}
          <Button label={joining ? 'Joining' : 'Join the circle'} disabled={code.length !== 6 || joining || !state.live} onPress={joinNow} />
        </ScrollView>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={s.safe} edges={['top']}>
      <ScreenHeader
        title="Care requests"
        subtitle={pending.length ? `${pending.length} waiting for you` : 'Nothing new'}
        onBack={router.canGoBack() ? () => router.back() : undefined}
        right={
          noCircle ? (
            <Pressable onPress={() => reset().then(() => router.replace('/'))} hitSlop={8} accessibilityRole="button">
              <Text style={s.skip}>Sign out</Text>
            </Pressable>
          ) : (
            <Pressable onPress={() => router.replace('/(tabs)')} hitSlop={8}>
              <Text style={s.skip}>Skip</Text>
            </Pressable>
          )
        }
      />

      <ScrollView contentContainerStyle={s.scroll} showsVerticalScrollIndicator={false}>
        {tabs}
        {pending.length === 0 && responded.length === 0 ? (
          <EmptyState
            icon="mail-outline"
            title="No requests yet"
            body={
              state.caregiverProfile
                ? `Families caring for someone within ${state.caregiverProfile.serviceRadiusKm} km of ${state.caregiverProfile.areaLabel} can now find you. Their requests appear here the moment they send them.`
                : 'Families near you will see your profile. Requests land here.'
            }
            action={noCircle ? 'Check again' : 'Go to Cura'}
            onAction={() => (noCircle ? refresh() : router.replace('/(tabs)'))}
          />
        ) : null}

        {error ? <Text style={s.errorText} accessibilityLiveRegion="polite">{error}</Text> : null}
        {pending.map(invite => {
          const pnc = invite.pncSummary ?? (state.pnc ? { ...state.pnc, area: state.pnc.address } : null);
          return (
          <Card key={invite.id} style={s.inviteCard}>
            <View style={s.inviteHead}>
              <Avatar initials={initials(invite.familyName)} size={44} tone={Colors.textStrong} />
              <View style={{ flex: 1 }}>
                <Text style={s.familyName}>{invite.familyName}</Text>
                <Text style={s.timeAgo}>Requested {relativeTime(invite.createdAt)}</Text>
              </View>
              <Pill label="New" tone={{ fg: Colors.caution, bg: Colors.cautionSoft }} />
            </View>

            <View style={s.quote}>
              <Text style={s.quoteText}>&ldquo;{invite.message}&rdquo;</Text>
            </View>

            {pnc ? (
              <View style={s.pncBox}>
                <Text style={s.pncName}>
                  {pnc.preferredName}, {pnc.age}
                </Text>
                <Text style={s.pncAddress} numberOfLines={1}>
                  {pnc.area}
                </Text>
                {pnc.conditions.length ? (
                  <View style={s.chipWrap}>
                    {pnc.conditions.slice(0, 4).map(c => (
                      <Chip key={c} label={c} />
                    ))}
                  </View>
                ) : null}
                <Text style={s.pncNeed} numberOfLines={2}>{pnc.mobility}</Text>
              </View>
            ) : null}

            <View style={s.terms}>
              <KeyValue label="Schedule" value={invite.scheduleSummary} />
              <KeyValue label="Starts" value={new Date(invite.startDate).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' })} />
              <KeyValue label="Rate" value={`${rupees(invite.hourlyRate)}/hr`} />
              <KeyValue label="Estimated weekly" value={rupees(invite.payment.weeklyTotal)} />
            </View>

            <Text style={s.holdText}>
              Accepting adds you to this family&apos;s care circle: you see the full care profile and can
              message every relative. Payments are arranged with the family directly for now.
            </Text>

            {decliningId === invite.id ? (
              <View style={s.declineBox}>
                <Text style={s.declineTitle}>Why are you declining?</Text>
                <View style={s.chipWrap}>
                  {DECLINE_REASONS.map(r => (
                    <Chip key={r} label={r} onPress={() => decline(invite, r)} />
                  ))}
                </View>
                <Button label="Cancel" variant="ghost" size="sm" onPress={() => setDecliningId(null)} />
              </View>
            ) : busy === invite.id ? (
              <View style={s.busyRow}>
                <ActivityIndicator color={Colors.brown} />
                <Text style={s.busyText}>Joining the circle</Text>
              </View>
            ) : (
              <View style={s.actions}>
                <Button
                  label="Decline"
                  variant="secondary"
                  style={{ flex: 1 }}
                  onPress={() => setDecliningId(invite.id)}
                />
                <Button
                  label="Accept"
                  icon="checkmark"
                  style={{ flex: 1.4 }}
                  onPress={() => accept(invite)}
                />
              </View>
            )}
          </Card>
          );
        })}

        {responded.length ? (
          <>
            <Text style={s.pastLabel}>EARLIER</Text>
            {responded.map(invite => (
              <Card key={invite.id} style={s.pastCard}>
                <View style={{ flex: 1 }}>
                  <Text style={s.pastName}>{invite.familyName}</Text>
                  <Text style={s.pastMeta}>
                    {invite.scheduleSummary} · {rupees(invite.payment.weeklyTotal)}/wk
                  </Text>
                </View>
                <Pill
                  label={invite.status === 'accepted' ? 'Accepted' : 'Declined'}
                  tone={
                    invite.status === 'accepted'
                      ? { fg: Colors.positive, bg: Colors.positiveSoft }
                      : { fg: Colors.textSecondary, bg: Colors.surfaceTinted }
                  }
                />
              </Card>
            ))}
          </>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  codeLead: { ...Type.title, color: Colors.textStrong },
  codeSub: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400' },
  errorText: { ...Type.callout, color: Colors.urgent },
  safe: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { padding: Spacing.md, gap: Spacing.md, paddingBottom: Spacing.xl },
  skip: { ...Type.callout, color: Colors.brown, fontWeight: '700' },

  inviteCard: { gap: 12 },
  inviteHead: { flexDirection: 'row', alignItems: 'center', gap: 11 },
  familyName: { ...Type.subhead, color: Colors.textStrong },
  timeAgo: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400', marginTop: 1 },

  quote: { backgroundColor: Colors.surfaceTinted, borderRadius: Radius.md, padding: 12 },
  quoteText: { ...Type.body, fontSize: 14, color: Colors.textPrimary, fontStyle: 'italic', lineHeight: 20 },

  pncBox: { gap: 6 },
  pncName: { ...Type.subhead, color: Colors.textStrong },
  pncAddress: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  pncNeed: { ...Type.caption, color: Colors.textPrimary, fontWeight: '400', lineHeight: 17 },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },

  terms: { backgroundColor: Colors.surfaceRaised, borderRadius: Radius.md, padding: 12 },
  divider: { height: StyleSheet.hairlineWidth, backgroundColor: Colors.separator, marginVertical: 4 },

  holdNote: {
    flexDirection: 'row', gap: 8, alignItems: 'flex-start',
    backgroundColor: Colors.positiveSoft, padding: 10, borderRadius: Radius.md,
  },
  holdText: { fontSize: 12, color: Colors.textPrimary, lineHeight: 17, flex: 1 },

  actions: { flexDirection: 'row', gap: Spacing.sm },
  busyRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 10, paddingVertical: 12 },
  busyText: { ...Type.callout, color: Colors.textSecondary },

  declineBox: { gap: 10, backgroundColor: Colors.surfaceTinted, padding: 12, borderRadius: Radius.md },
  declineTitle: { ...Type.callout, color: Colors.textStrong, fontWeight: '700' },

  pastLabel: { ...Type.overline, color: Colors.textSecondary, marginTop: Spacing.sm },
  pastCard: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  pastName: { ...Type.callout, color: Colors.textStrong, fontWeight: '600' },
  pastMeta: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', marginTop: 2 },

  resultScroll: { padding: Spacing.md, gap: Spacing.md, alignItems: 'stretch', paddingTop: Spacing.xxl },
  resultIcon: {
    width: 72, height: 72, borderRadius: 36, alignSelf: 'center',
    alignItems: 'center', justifyContent: 'center',
  },
  resultTitle: { ...Type.title, color: Colors.textStrong, textAlign: 'center' },
  resultBody: {
    ...Type.callout, color: Colors.textSecondary, fontWeight: '400',
    textAlign: 'center', lineHeight: 20, marginTop: -6,
  },
  resultCard: { gap: 2, marginTop: Spacing.sm },
  payHead: { flexDirection: 'row', alignItems: 'center', gap: 7, marginBottom: 6 },
  payHeadText: { ...Type.subhead, color: Colors.textStrong },
});
