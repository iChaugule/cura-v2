/**
 * Renders the light markdown the AI produces: **bold**, bullet lines and
 * numbered lines. Not a full parser — just enough to read well.
 */
import React from 'react';
import { Text, View, StyleSheet, type TextStyle, type StyleProp } from 'react-native';
import { Colors, Type } from '../design/tokens';

function inline(text: string, key: string, style?: StyleProp<TextStyle>) {
  const parts = text.split(/(\*\*[^*]+\*\*)/g).filter(Boolean);
  return parts.map((part, i) => {
    const bold = part.startsWith('**') && part.endsWith('**');
    return (
      <Text
        key={`${key}-${i}`}
        style={[style, bold && { fontWeight: '700', color: Colors.textStrong }]}
      >
        {bold ? part.slice(2, -2) : part}
      </Text>
    );
  });
}

export function RichText({
  children, style,
}: {
  children: string;
  style?: StyleProp<TextStyle>;
}) {
  const lines = children.split('\n');

  return (
    <View style={{ gap: 6 }}>
      {lines.map((line, i) => {
        const trimmed = line.trim();
        if (!trimmed) return null;

        const bullet = /^[-•*]\s+/.test(trimmed);
        const numbered = /^\d+[.)]\s+/.test(trimmed);

        if (bullet || numbered) {
          const marker = numbered ? trimmed.match(/^\d+[.)]/)![0] : '•';
          const body = trimmed.replace(/^([-•*]|\d+[.)])\s+/, '');
          return (
            <View key={i} style={s.listRow}>
              <Text style={[s.marker, style]}>{marker}</Text>
              <Text style={[s.body, style, { flex: 1 }]}>{inline(body, `l${i}`, style)}</Text>
            </View>
          );
        }

        return (
          <Text key={i} style={[s.body, style]}>
            {inline(trimmed, `p${i}`, style)}
          </Text>
        );
      })}
    </View>
  );
}

const s = StyleSheet.create({
  body: { ...Type.body, color: Colors.textPrimary },
  listRow: { flexDirection: 'row', gap: 8, alignItems: 'flex-start' },
  marker: { ...Type.body, color: Colors.textSecondary, minWidth: 16 },
});
