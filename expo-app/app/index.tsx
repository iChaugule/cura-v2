/**
 * Welcome screen. Also the gate: if someone is already signed in on this
 * device, it sends them straight into the app.
 *
 * Instead of a list of feature claims, it shows a real piece of the product:
 * the pattern engine run on the demo family's last three weeks.
 */
import { useEffect, useMemo, useRef } from 'react';
import { View, Text, StyleSheet, ScrollView, Pressable, Image } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Button } from '../src/components/ui';
import { Colors, Radius, Spacing, Type } from '../src/design/tokens';
import { useApp } from '../src/state/AppContext';
import { analyze, TIER_LABEL } from '../src/engine/patterns';
import { buildDemoSeed } from '../src/data/demoSeed';
import { TierColors } from '../src/components/Findings';

export default function Welcome() {
  const { state, isOnboarded, startDemo, canGoLive } = useApp();

  // Already signed in on this device: skip the front door. Only checked once,
  // when the app opens, so it never hijacks a sign-up that is in progress.
  const checked = useRef(false);
  useEffect(() => {
    if (!state.hydrated || checked.current) return;
    checked.current = true;
    if (!isOnboarded) return;
    if (state.live && !state.pnc) router.replace('/(onboard)/invites');
    else router.replace('/(tabs)');
  }, [state.hydrated, isOnboarded, state.live, state.pnc]);

  // A real finding from the real engine, on the sample family's data.
  const sample = useMemo(() => analyze(buildDemoSeed().quizzes).findings[0], []);

  if (!state.hydrated) return <View style={styles.loading} />;

  const onDemo = () => {
    startDemo();
    router.replace('/(tabs)');
  };

  return (
    <SafeAreaView style={styles.safe}>
      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>
        <View style={styles.hero}>
          <View style={styles.brand}>
            <Image
              source={require('../assets/logo-mark.png')}
              style={styles.mark}
              accessibilityLabel="Cura logo: a swan whose wing, shaped like a C, holds a heart"
            />
            <Text style={styles.wordmark}>Cura</Text>
          </View>
          <Text style={styles.headline}>
            Know how someone you love is doing today, from wherever you are.
          </Text>
          <Text style={styles.lede}>
            Cura connects your family with a caregiver who lives near them. The caregiver logs each day,
            everyone reads it in their own language, and Cura tells you when something drifts from their
            normal.
          </Text>
        </View>

        {sample ? (
          <View style={styles.preview} accessibilityLabel="Example of what a family sees">
            <Text style={styles.previewCaption}>What a family saw this morning</Text>
            <View style={styles.previewCard}>
              <Text style={[styles.previewTier, { color: TierColors[sample.tier].fg }]}>
                {TIER_LABEL[sample.tier].toUpperCase()}
              </Text>
              <Text style={styles.previewTitle}>{sample.title}</Text>
              <Text style={styles.previewBody}>{sample.detail.split('. ').slice(0, 2).join('. ').replace(/\.?$/, '.')}</Text>
              <View style={styles.previewFoot}>
                <Text style={styles.previewMeta}>
                  From {sample.evidence.length} check-in answers by Priya, her caregiver in Pune
                </Text>
              </View>
            </View>
            <Text style={styles.previewNote}>
              Cura compares each day to the person&apos;s own usual, not to an average. It never diagnoses.
            </Text>
          </View>
        ) : null}

        <View style={styles.actions}>
          <Button label="Get started" onPress={() => router.push('/(onboard)/role')} />
          {canGoLive ? (
            <View style={styles.links}>
              <Pressable onPress={() => router.push('/(onboard)/sign-in')} hitSlop={8} accessibilityRole="link">
                <Text style={styles.link}>Sign in</Text>
              </Pressable>
              <View style={styles.linkRule} />
              <Pressable onPress={() => router.push('/(onboard)/join')} hitSlop={8} accessibilityRole="link">
                <Text style={styles.link}>Join with a family code</Text>
              </Pressable>
            </View>
          ) : (
            <Text style={styles.offline}>
              Not connected to the Cura database, so new accounts stay on this phone.
            </Text>
          )}
        </View>

        <Pressable onPress={onDemo} accessibilityRole="button" style={({ pressed }) => [styles.demo, pressed && { opacity: 0.8 }]}>
          <Text style={styles.demoTitle}>Look around first</Text>
          <Text style={styles.demoBody}>
            Opens a sample family with three weeks of history. You can switch between the family&apos;s and the
            caregiver&apos;s view.
          </Text>
        </Pressable>

        <View style={styles.footer}>
          <Text style={styles.legal}>Cura is not a medical service. In an emergency, call your local emergency number.</Text>
          <View style={styles.links}>
            <Pressable onPress={() => router.push('/terms')} accessibilityRole="link" hitSlop={8}>
              <Text style={styles.footLink}>Terms</Text>
            </Pressable>
            <Pressable onPress={() => router.push('/privacy')} accessibilityRole="link" hitSlop={8}>
              <Text style={styles.footLink}>Privacy</Text>
            </Pressable>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.bgBase },
  loading: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { paddingHorizontal: Spacing.lg, paddingBottom: Spacing.xl, flexGrow: 1, maxWidth: 560, width: '100%', alignSelf: 'center' },

  hero: { paddingTop: 40, gap: 12 },
  brand: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  mark: { width: 44, height: 44, borderRadius: 22 },
  wordmark: { fontFamily: 'Fraunces_700Bold', fontSize: 22, color: Colors.brown, letterSpacing: 0.2 },
  headline: { ...Type.display, fontSize: 31, lineHeight: 37, color: Colors.textStrong },
  lede: { ...Type.body, color: Colors.textPrimary, lineHeight: 23 },

  preview: { marginTop: Spacing.lg, gap: 8 },
  previewCaption: { ...Type.caption, color: Colors.textSecondary },
  previewCard: {
    backgroundColor: Colors.surface, borderRadius: Radius.lg, padding: Spacing.md, gap: 6,
    borderWidth: 1, borderColor: Colors.separator,
    boxShadow: '0px 6px 18px rgba(110, 58, 38, 0.10)',
  },
  previewTier: { ...Type.overline, fontSize: 10 },
  previewTitle: { ...Type.heading, color: Colors.textStrong },
  previewBody: { ...Type.callout, fontWeight: '400', color: Colors.textPrimary },
  previewFoot: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator, paddingTop: 8, marginTop: 4 },
  previewMeta: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400' },
  previewNote: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', lineHeight: 17 },

  actions: { gap: Spacing.md, marginTop: Spacing.lg },
  links: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', gap: Spacing.md },
  linkRule: { width: 1, height: 14, backgroundColor: Colors.border },
  link: { ...Type.callout, color: Colors.brown, fontWeight: '700' },
  offline: { ...Type.caption, color: Colors.textSecondary, textAlign: 'center', fontWeight: '400' },

  demo: {
    marginTop: Spacing.lg, padding: Spacing.md, gap: 4, borderRadius: Radius.md,
    backgroundColor: Colors.surfaceTinted,
  },
  demoTitle: { ...Type.subhead, color: Colors.textStrong },
  demoBody: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400' },

  footer: { marginTop: 'auto', paddingTop: Spacing.xl, gap: 8 },
  legal: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400', textAlign: 'center' },
  footLink: { ...Type.caption, color: Colors.textSecondary, fontWeight: '700' },
});
