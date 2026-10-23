/**
 * Address input with live geocoding.
 *
 * The chosen result carries coordinates, which is what the caregiver search and
 * the map both run on.
 */
import { useEffect, useRef, useState } from 'react';
import { View, Text, Pressable, StyleSheet, ActivityIndicator } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Radius, Spacing, Type } from '../design/tokens';
import { searchPlaces } from '../lib/geo';
import type { PlaceResult } from '../models/types';
import { Input } from './ui';

export function AddressField({
  value, onChangeText, onSelect, selected, placeholder,
}: {
  value: string;
  onChangeText: (v: string) => void;
  onSelect: (place: PlaceResult) => void;
  selected: PlaceResult | null;
  placeholder?: string;
}) {
  const [results, setResults] = useState<PlaceResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [open, setOpen] = useState(false);
  const abort = useRef<AbortController | null>(null);

  useEffect(() => {
    // Already resolved to a place — nothing to look up.
    if (selected && selected.label === value) {
      setResults([]);
      setOpen(false);
      return;
    }
    if (value.trim().length < 3) {
      setResults([]);
      setOpen(false);
      return;
    }

    setLoading(true);
    const timer = setTimeout(async () => {
      abort.current?.abort();
      const controller = new AbortController();
      abort.current = controller;
      try {
        const found = await searchPlaces(value, controller.signal);
        if (controller.signal.aborted) return;
        setResults(found);
        setOpen(found.length > 0);
      } finally {
        if (!controller.signal.aborted) setLoading(false);
      }
    }, 550); // Nominatim asks for at most one request per second.

    return () => {
      clearTimeout(timer);
      setLoading(false);
    };
  }, [value, selected]);

  return (
    <View style={{ gap: 6 }}>
      <View>
        <Input
          value={value}
          onChangeText={onChangeText}
          placeholder={placeholder ?? 'Street, area, city'}
          autoCorrect={false}
          style={{ paddingRight: 40 }}
        />
        <View style={s.adornment}>
          {loading ? (
            <ActivityIndicator size="small" color={Colors.textSecondary} />
          ) : selected ? (
            <Ionicons name="checkmark-circle" size={19} color={Colors.positive} />
          ) : (
            <Ionicons name="search" size={17} color={Colors.textTertiary} />
          )}
        </View>
      </View>

      {open && results.length > 0 ? (
        <View style={s.dropdown}>
          {results.map((r, i) => (
            <Pressable
              key={`${r.lat},${r.lng},${i}`}
              accessibilityRole="button"
              onPress={() => {
                onSelect(r);
                onChangeText(r.label);
                setOpen(false);
                setResults([]);
              }}
              style={({ pressed }) => [
                s.row,
                i > 0 && { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.separator },
                pressed && { backgroundColor: Colors.accentSoft },
              ]}
            >
              <Ionicons name="location-outline" size={16} color={Colors.brown} />
              <View style={{ flex: 1 }}>
                <Text style={s.rowTitle} numberOfLines={1}>{r.shortLabel}</Text>
                <Text style={s.rowSub} numberOfLines={1}>{r.label}</Text>
              </View>
            </Pressable>
          ))}
        </View>
      ) : null}

      {selected ? (
        <Text style={s.confirmed}>
          Pinned at {selected.lat.toFixed(4)}, {selected.lng.toFixed(4)}
        </Text>
      ) : null}
    </View>
  );
}

const s = StyleSheet.create({
  adornment: { position: 'absolute', right: 12, top: 0, bottom: 0, justifyContent: 'center' },
  dropdown: {
    backgroundColor: Colors.surfaceRaised,
    borderRadius: Radius.md,
    borderWidth: 1, borderColor: Colors.border,
    overflow: 'hidden',
  },
  row: { flexDirection: 'row', alignItems: 'center', gap: 10, padding: 11 },
  rowTitle: { ...Type.callout, color: Colors.textStrong, fontWeight: '600' },
  rowSub: { fontSize: 11, color: Colors.textTertiary, marginTop: 1 },
  confirmed: { ...Type.caption, color: Colors.positive, fontWeight: '500' },
});
