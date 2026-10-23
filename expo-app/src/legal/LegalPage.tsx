/**
 * Shared layout for the Terms of Service and Privacy Policy pages.
 */
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ScreenHeader } from '../components/ScreenHeader';
import { Colors, Spacing, Type } from '../design/tokens';

/** Set this to the address people should write to about their data. */
export const CONTACT_EMAIL = '';
export const LEGAL_UPDATED = 'October 22, 2026';

export interface LegalSection { heading: string; body: string[] }

export function LegalPage({ title, intro, sections }: { title: string; intro: string; sections: LegalSection[] }) {
  return (
    <SafeAreaView style={s.safe} edges={['top']}>
      <ScreenHeader title={title} subtitle={`Last updated ${LEGAL_UPDATED}`} />
      <ScrollView contentContainerStyle={s.scroll}>
        <Text style={s.intro}>{intro}</Text>
        {sections.map((sec, i) => (
          <View key={sec.heading} style={s.section}>
            <Text style={s.heading} accessibilityRole="header">{i + 1}. {sec.heading}</Text>
            {sec.body.map((p, j) => <Text key={j} style={s.p}>{p}</Text>)}
          </View>
        ))}
        {CONTACT_EMAIL ? (
          <Text style={s.p}>Questions: {CONTACT_EMAIL}</Text>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.bgBase },
  scroll: { padding: Spacing.md, paddingBottom: Spacing.xxl, gap: Spacing.md, maxWidth: 680 },
  intro: { ...Type.body, color: Colors.textStrong },
  section: { gap: 6 },
  heading: { ...Type.subhead, color: Colors.textStrong },
  p: { ...Type.body, fontSize: 14, color: Colors.textPrimary, lineHeight: 21 },
});
