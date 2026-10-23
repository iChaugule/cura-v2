/**
 * Demo mode's role switcher.
 *
 * Real accounts are one-sided — you are either the family or the caregiver.
 * This bar exists so the whole two-sided product can be shown from one device.
 * Remove it (and `demoMode` in the store) once accounts are real.
 */
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Radius, Spacing, Type } from '../design/tokens';
import { useApp } from '../state/AppContext';

export function DemoBar() {
  const { state, setActiveRole } = useApp();

  // Only in demo mode, and only once both sides exist on this device.
  if (!state.demoMode || !state.familyAccount || !state.caregiverAccount) return null;

  const role = state.activeRole;

  return (
    <View style={s.bar}>
      <View style={s.tag}>
        <Text style={s.tagText}>DEMO</Text>
      </View>
      <Text style={s.label}>Viewing as</Text>
      <View style={s.switch}>
        {(['family', 'caregiver'] as const).map(r => {
          const active = role === r;
          const account = r === 'family' ? state.familyAccount : state.caregiverAccount;
          return (
            <Pressable
              key={r}
              onPress={() => setActiveRole(r)}
              accessibilityRole="tab"
              accessibilityState={{ selected: active }}
              accessibilityLabel={`View as ${r}: ${account?.name}`}
              style={[s.option, active && s.optionActive]}
            >
              <Ionicons
                name={r === 'family' ? 'people' : 'medkit'}
                size={12}
                color={active ? Colors.textOnBrown : Colors.textSecondary}
              />
              <Text style={[s.optionText, active && { color: Colors.textOnBrown }]} numberOfLines={1}>
                {account?.name.split(' ')[0] ?? (r === 'family' ? 'Family' : 'Caregiver')}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  bar: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    paddingHorizontal: Spacing.md, paddingVertical: 6,
    backgroundColor: Colors.surfaceTinted,
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.separator,
  },
  tag: {
    flexDirection: 'row', alignItems: 'center', gap: 3,
    backgroundColor: Colors.brown, paddingHorizontal: 6, paddingVertical: 2,
    borderRadius: Radius.pill,
  },
  tagText: { fontSize: 9, fontWeight: '800', letterSpacing: 0.6, color: Colors.textOnBrown },
  label: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', flex: 1 },
  switch: {
    flexDirection: 'row', gap: 2, padding: 2,
    backgroundColor: Colors.surfaceRaised, borderRadius: Radius.pill,
    borderWidth: StyleSheet.hairlineWidth, borderColor: Colors.border,
  },
  option: {
    flexDirection: 'row', alignItems: 'center', gap: 4,
    paddingHorizontal: 10, paddingVertical: 4, borderRadius: Radius.pill,
  },
  optionActive: { backgroundColor: Colors.brown },
  optionText: { fontSize: 12, fontWeight: '700', color: Colors.textSecondary, maxWidth: 70 },
});
