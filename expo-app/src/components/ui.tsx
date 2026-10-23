/**
 * Shared UI primitives. Everything in the app is built from these so the
 * cream/brown material stays consistent across all 5 tabs and onboarding.
 */
import React from 'react';
import {
  View, Text, Pressable, StyleSheet, ActivityIndicator,
  TextInput, ScrollView, type ViewStyle, type TextStyle,
  type TextInputProps, type StyleProp,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Radius, Shadow, Spacing, Type } from '../design/tokens';

type IoniconName = React.ComponentProps<typeof Ionicons>['name'];

// ── Card ────────────────────────────────────────────────────

export function Card({
  children, style, padded = true, raised = false,
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  padded?: boolean;
  raised?: boolean;
}) {
  return (
    <View style={[s.card, padded && { padding: Spacing.md }, raised && Shadow.lifted, style]}>
      {children}
    </View>
  );
}

export function SectionHeader({
  title, action, onAction, icon,
}: {
  title: string;
  action?: string;
  onAction?: () => void;
  icon?: IoniconName;
}) {
  return (
    <View style={s.sectionHeader}>
      <View style={s.row}>
        <Text style={s.sectionTitle} accessibilityRole="header">{title}</Text>
      </View>
      {action ? (
        <Pressable onPress={onAction} hitSlop={8}>
          <Text style={s.sectionAction}>{action}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

// ── Buttons ─────────────────────────────────────────────────

export function Button({
  label, onPress, variant = 'primary', icon, disabled, loading, style, size = 'md',
}: {
  label: string;
  onPress?: () => void;
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  icon?: IoniconName;
  disabled?: boolean;
  loading?: boolean;
  style?: StyleProp<ViewStyle>;
  size?: 'md' | 'sm';
}) {
  const off = disabled || loading;
  const palette = {
    primary: { bg: Colors.brown, fg: Colors.textOnBrown, border: 'transparent' },
    secondary: { bg: Colors.surface, fg: Colors.brown, border: Colors.border },
    ghost: { bg: 'transparent', fg: Colors.brown, border: 'transparent' },
    danger: { bg: Colors.urgent, fg: '#FFF7F4', border: 'transparent' },
  }[variant];

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled: !!off, busy: !!loading }}
      onPress={onPress}
      disabled={off}
      style={({ pressed }) => [
        s.btn,
        size === 'sm' && s.btnSm,
        { backgroundColor: palette.bg, borderColor: palette.border },
        variant === 'secondary' && { borderWidth: 1 },
        pressed && !off && { opacity: 0.75 },
        off && { opacity: 0.45 },
        style,
      ]}
    >
      {/* Buttons are words, not icons: the label says what happens. While busy the
          caller changes the label ("Sending"), so no spinner is needed. */}
      <Text style={[s.btnLabel, size === 'sm' && { fontSize: 14 }, { color: palette.fg }]}>{label}</Text>
    </Pressable>
  );
}

export function IconButton({
  icon, onPress, active, label, size = 36, tint,
}: {
  icon: IoniconName;
  onPress?: () => void;
  active?: boolean;
  label: string;
  size?: number;
  tint?: string;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      hitSlop={6}
      style={({ pressed }) => [
        s.iconBtn,
        { width: size, height: size, borderRadius: size / 2 },
        active && { backgroundColor: Colors.brown },
        pressed && { opacity: 0.65 },
      ]}
    >
      <Ionicons
        name={icon}
        size={size * 0.5}
        color={active ? Colors.textOnBrown : tint ?? Colors.brown}
      />
    </Pressable>
  );
}

// ── Chips & badges ──────────────────────────────────────────

export function Chip({
  label, selected, onPress, icon, tone,
}: {
  label: string;
  selected?: boolean;
  onPress?: () => void;
  icon?: IoniconName;
  tone?: { fg: string; bg: string };
}) {
  const fg = tone?.fg ?? (selected ? Colors.textOnBrown : Colors.textPrimary);
  const bg = tone?.bg ?? (selected ? Colors.brown : Colors.surfaceTinted);
  const base = [
    s.chip,
    { backgroundColor: bg },
    !selected && !tone ? { borderWidth: 1, borderColor: Colors.separator } : null,
  ];
  const content = (
    <>
      {icon && <Ionicons name={icon} size={13} color={fg} />}
      <Text style={[s.chipText, { color: fg }]} numberOfLines={1}>{label}</Text>
    </>
  );

  // A plain View ignores the function form of `style`, so the two cases have to
  // be kept apart — sharing one wrapper silently drops the styling.
  if (!onPress) return <View style={base}>{content}</View>;

  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityState={{ selected: !!selected }}
      style={({ pressed }) => [...base, pressed && { opacity: 0.7 }]}
    >
      {content}
    </Pressable>
  );
}

export function Pill({ label, tone }: { label: string; tone: { fg: string; bg: string } }) {
  return (
    <View style={[s.pill, { backgroundColor: tone.bg }]}>
      <Text style={[s.pillText, { color: tone.fg }]}>{label}</Text>
    </View>
  );
}

export function Avatar({
  initials, size = 44, tone,
}: {
  initials: string;
  size?: number;
  tone?: string;
}) {
  return (
    <View
      style={[
        s.avatar,
        { width: size, height: size, borderRadius: size / 2, backgroundColor: tone ?? Colors.brown },
      ]}
    >
      <Text style={{ color: Colors.textOnBrown, fontSize: size * 0.36, fontWeight: '700' }}>
        {initials}
      </Text>
    </View>
  );
}

// ── Inputs ──────────────────────────────────────────────────

export function Field({
  label, hint, children, required,
}: {
  label: string;
  hint?: string;
  children: React.ReactNode;
  required?: boolean;
}) {
  return (
    <View style={{ gap: 6 }}>
      <Text style={s.fieldLabel}>
        {label}
        {required ? <Text style={{ color: Colors.urgent }}> *</Text> : null}
      </Text>
      {children}
      {hint ? <Text style={s.fieldHint}>{hint}</Text> : null}
    </View>
  );
}

export function Input({ style, ...props }: TextInputProps) {
  return (
    <TextInput
      placeholderTextColor={Colors.textTertiary}
      {...props}
      style={[s.input, props.multiline && { minHeight: 96, paddingTop: 12 }, style]}
    />
  );
}

export function OptionRow<T extends string>({
  options, value, onChange,
}: {
  options: { value: T; label: string; sublabel?: string; icon?: IoniconName }[];
  value: T | null;
  onChange: (v: T) => void;
}) {
  return (
    <View style={{ gap: Spacing.sm }}>
      {options.map(o => {
        const active = o.value === value;
        return (
          <Pressable
            key={o.value}
            onPress={() => onChange(o.value)}
            accessibilityRole="radio"
            accessibilityState={{ selected: active }}
            style={({ pressed }) => [
              s.optionRow,
              active && { borderColor: Colors.brown, backgroundColor: Colors.accentSoft },
              pressed && { opacity: 0.8 },
            ]}
          >
            {o.icon && (
              <View style={[s.optionIcon, active && { backgroundColor: Colors.brown }]}>
                <Ionicons name={o.icon} size={17} color={active ? Colors.textOnBrown : Colors.brown} />
              </View>
            )}
            <View style={{ flex: 1 }}>
              <Text style={s.optionLabel}>{o.label}</Text>
              {o.sublabel ? <Text style={s.optionSub}>{o.sublabel}</Text> : null}
            </View>
            <View style={[s.radio, active && { borderColor: Colors.brown }]}>
              {active && <View style={s.radioDot} />}
            </View>
          </Pressable>
        );
      })}
    </View>
  );
}

/** Horizontal segmented control. */
export function Segmented<T extends string>({
  options, value, onChange,
}: {
  options: { value: T; label: string }[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <View style={s.segment}>
      {options.map(o => {
        const active = o.value === value;
        return (
          <Pressable
            key={o.value}
            onPress={() => onChange(o.value)}
            accessibilityRole="tab"
            accessibilityState={{ selected: active }}
            style={[s.segmentItem, active && s.segmentItemActive]}
          >
            <Text style={[s.segmentText, active && { color: Colors.textOnBrown }]} numberOfLines={1}>
              {o.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

// ── Feedback ────────────────────────────────────────────────

export function EmptyState({
  title, body, action, onAction,
}: {
  /** Kept for call sites; empty states are words, not icons. */
  icon?: IoniconName;
  title: string;
  body: string;
  action?: string;
  onAction?: () => void;
}) {
  return (
    <View style={s.empty}>
      <Text style={s.emptyTitle}>{title}</Text>
      <Text style={s.emptyBody}>{body}</Text>
      {action ? <Button label={action} onPress={onAction} variant="secondary" size="sm" style={{ marginTop: Spacing.sm }} /> : null}
    </View>
  );
}

export function Banner({
  title, body, tone = 'info', action, onAction,
}: {
  icon?: IoniconName;
  title: string;
  body?: string;
  tone?: 'info' | 'caution' | 'urgent' | 'positive';
  action?: string;
  onAction?: () => void;
}) {
  const map = {
    info: { fg: Colors.info, bg: Colors.infoSoft },
    caution: { fg: Colors.caution, bg: Colors.cautionSoft },
    urgent: { fg: Colors.urgent, bg: Colors.urgentSoft },
    positive: { fg: Colors.positive, bg: Colors.positiveSoft },
  }[tone];
  return (
    <View style={[s.banner, { backgroundColor: map.bg }]}>
      <View style={{ flex: 1, gap: 2 }}>
        <Text style={[s.bannerTitle, { color: map.fg }]}>{title}</Text>
        {body ? <Text style={s.bannerBody}>{body}</Text> : null}
      </View>
      {action ? (
        <Pressable onPress={onAction} hitSlop={8}>
          <Text style={[s.bannerAction, { color: map.fg }]}>{action}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

/** Simple horizontal 0–100 meter. */
export function Meter({ value, tone }: { value: number; tone?: string }) {
  const pct = Math.max(0, Math.min(100, value));
  return (
    <View style={s.meterTrack}>
      <View style={[s.meterFill, { width: `${pct}%`, backgroundColor: tone ?? Colors.brown }]} />
    </View>
  );
}

export function KeyValue({ label, value }: { label: string; value: string }) {
  return (
    <View style={s.kv}>
      <Text style={s.kvLabel}>{label}</Text>
      <Text style={s.kvValue}>{value}</Text>
    </View>
  );
}

/** Horizontally scrolling chip strip used for filters and quick prompts. */
export function ChipRow({ children }: { children: React.ReactNode }) {
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={{ gap: Spacing.sm, paddingHorizontal: Spacing.md }}
    >
      {children}
    </ScrollView>
  );
}

// ── Styles ──────────────────────────────────────────────────

const s = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center' },

  card: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    borderWidth: StyleSheet.hairlineWidth * 2,
    borderColor: Colors.separator,
  },

  sectionHeader: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: Spacing.xs, marginBottom: Spacing.sm, marginTop: Spacing.lg,
  },
  sectionTitle: { fontFamily: 'Fraunces_600SemiBold', fontSize: 18, color: Colors.textStrong },
  sectionAction: { ...Type.caption, color: Colors.brown, fontWeight: '700' },

  btn: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8,
    paddingVertical: 14, paddingHorizontal: Spacing.lg, borderRadius: Radius.md,
  },
  btnSm: { paddingVertical: 9, paddingHorizontal: Spacing.md, borderRadius: Radius.sm },
  btnLabel: { fontSize: 16, fontWeight: '700' },

  iconBtn: {
    alignItems: 'center', justifyContent: 'center',
    backgroundColor: Colors.surfaceTinted,
  },

  chip: {
    flexDirection: 'row', alignItems: 'center', gap: 5,
    paddingHorizontal: 12, paddingVertical: 7, borderRadius: Radius.pill,
  },
  chipText: { fontSize: 13, fontWeight: '600' },

  pill: { paddingHorizontal: 9, paddingVertical: 3, borderRadius: Radius.pill, alignSelf: 'flex-start' },
  pillText: { fontSize: 11, fontWeight: '700', letterSpacing: 0.2 },

  avatar: { alignItems: 'center', justifyContent: 'center' },

  fieldLabel: { ...Type.callout, color: Colors.textStrong, fontWeight: '700' },
  fieldHint: { ...Type.caption, color: Colors.textTertiary, fontWeight: '400' },
  input: {
    backgroundColor: Colors.surfaceRaised,
    borderWidth: 1, borderColor: Colors.border,
    borderRadius: Radius.md,
    paddingHorizontal: 14, paddingVertical: 12,
    fontSize: 15, color: Colors.textStrong,
  },

  optionRow: {
    flexDirection: 'row', alignItems: 'center', gap: 12,
    padding: 14, borderRadius: Radius.md,
    borderWidth: 1.5, borderColor: Colors.separator,
    backgroundColor: Colors.surface,
  },
  optionIcon: {
    width: 36, height: 36, borderRadius: 18,
    backgroundColor: Colors.accentSoft,
    alignItems: 'center', justifyContent: 'center',
  },
  optionLabel: { ...Type.subhead, color: Colors.textStrong },
  optionSub: { ...Type.caption, color: Colors.textSecondary, fontWeight: '400', marginTop: 2 },
  radio: {
    width: 20, height: 20, borderRadius: 10,
    borderWidth: 2, borderColor: Colors.border,
    alignItems: 'center', justifyContent: 'center',
  },
  radioDot: { width: 10, height: 10, borderRadius: 5, backgroundColor: Colors.brown },

  segment: {
    flexDirection: 'row', backgroundColor: Colors.surfaceTinted,
    borderRadius: Radius.md, padding: 3, gap: 2,
  },
  segmentItem: { flex: 1, paddingVertical: 8, borderRadius: Radius.sm, alignItems: 'center' },
  segmentItemActive: { backgroundColor: Colors.brown },
  segmentText: { fontSize: 13, fontWeight: '700', color: Colors.textSecondary },

  empty: { alignItems: 'center', paddingVertical: Spacing.xl, paddingHorizontal: Spacing.lg, gap: 6 },
  emptyIcon: {
    width: 56, height: 56, borderRadius: 28, backgroundColor: Colors.surfaceTinted,
    alignItems: 'center', justifyContent: 'center', marginBottom: 6,
  },
  emptyTitle: { fontFamily: 'Fraunces_600SemiBold', fontSize: 19, color: Colors.textStrong, textAlign: 'center' },
  emptyBody: { ...Type.callout, color: Colors.textSecondary, textAlign: 'center', fontWeight: '400' },

  banner: {
    flexDirection: 'row', gap: 10, alignItems: 'flex-start',
    padding: 13, borderRadius: Radius.lg,
  },
  bannerTitle: { fontSize: 14, fontWeight: '700' },
  bannerBody: { fontSize: 13, color: Colors.textSecondary, lineHeight: 18 },
  bannerAction: { fontSize: 13, fontWeight: '700' },

  meterTrack: { height: 8, borderRadius: 4, backgroundColor: Colors.surfaceTinted, overflow: 'hidden' },
  meterFill: { height: '100%', borderRadius: 4 },

  kv: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', gap: Spacing.md, paddingVertical: 7 },
  kvLabel: { ...Type.callout, color: Colors.textSecondary, fontWeight: '500' },
  kvValue: { ...Type.callout, color: Colors.textStrong, fontWeight: '600', flex: 1, textAlign: 'right' },
});

export const uiStyles = s;
