import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Colors, Radius, Spacing, Type } from '../design/tokens';

export function ScreenHeader({
  title, subtitle, onBack, right, step, totalSteps,
}: {
  title: string;
  subtitle?: string;
  onBack?: () => void;
  right?: React.ReactNode;
  step?: number;
  totalSteps?: number;
}) {
  const back = onBack ?? (router.canGoBack() ? () => router.back() : undefined);

  return (
    <View style={s.wrap}>
      <View style={s.row}>
        {back ? (
          <Pressable onPress={back} hitSlop={10} accessibilityRole="button" accessibilityLabel="Go back" style={s.backBtn}>
            <Ionicons name="chevron-back" size={22} color={Colors.brown} />
          </Pressable>
        ) : (
          <View style={{ width: 34 }} />
        )}
        <View style={s.titles}>
          <Text style={s.title} numberOfLines={1}>{title}</Text>
          {subtitle ? <Text style={s.subtitle} numberOfLines={1}>{subtitle}</Text> : null}
        </View>
        <View style={s.rightSlot}>{right}</View>
      </View>

      {totalSteps ? (
        <View style={s.progressRow}>
          {Array.from({ length: totalSteps }).map((_, i) => (
            <View
              key={i}
              style={[s.progressSeg, i < (step ?? 0) && { backgroundColor: Colors.brown }]}
            />
          ))}
        </View>
      ) : null}
    </View>
  );
}

const s = StyleSheet.create({
  wrap: {
    paddingHorizontal: Spacing.md, paddingBottom: 10, paddingTop: 4,
    backgroundColor: Colors.bgBase,
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.separator,
  },
  row: { flexDirection: 'row', alignItems: 'center', minHeight: 44, gap: 4 },
  backBtn: { width: 34, height: 34, alignItems: 'center', justifyContent: 'center' },
  titles: { flex: 1, alignItems: 'center' },
  title: { ...Type.subhead, color: Colors.textStrong },
  subtitle: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', marginTop: 1 },
  rightSlot: { minWidth: 34, alignItems: 'flex-end' },

  progressRow: { flexDirection: 'row', gap: 5, marginTop: 6 },
  progressSeg: { flex: 1, height: 3, borderRadius: Radius.pill, backgroundColor: Colors.surfaceTinted },
});
