/**
 * The care circle code, large, with a share button.
 * Anyone who types it on the welcome screen joins this circle, as a relative or as a caregiver.
 */
import { useState } from 'react';
import { View, Text, StyleSheet, Share, Platform, Pressable } from 'react-native';
import { Colors, Radius, Spacing, Type } from '../design/tokens';
import { Button } from './ui';

export function CircleCode({ code, name, sample }: { code: string; name: string; sample?: boolean }) {
  const [copied, setCopied] = useState(false);
  const message = `Join ${name}'s care circle on Cura. Open Cura, choose "Join with a circle code", and enter ${code}.`;

  const share = async () => {
    try {
      if (Platform.OS === 'web') {
        const nav = (globalThis as any).navigator;
        if (nav?.share) await nav.share({ text: message });
        else await nav?.clipboard?.writeText(message);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      } else {
        await Share.share({ message });
      }
    } catch { /* cancelled */ }
  };

  return (
    <View style={s.box}>
      <Text style={s.label}>CIRCLE CODE</Text>
      <Text style={s.code} selectable accessibilityLabel={`Circle code ${code.split('').join(' ')}`}>{code}</Text>
      <Text style={s.help}>
        {sample ? 'A sample code for the demo. With a live account, relatives and caregivers enter the code on the welcome screen. ' : ''}Give this to relatives or a caregiver. They choose "Join with a circle code" on the welcome screen and
        see everything you see, translated into their language.
      </Text>
      <Button label={copied ? 'Copied' : 'Share the code'} variant="secondary" onPress={share} />
    </View>
  );
}

const s = StyleSheet.create({
  box: { gap: 8 },
  label: { ...Type.overline, color: Colors.textSecondary },
  code: { fontSize: 34, fontWeight: '800', letterSpacing: 8, color: Colors.textStrong, fontVariant: ['tabular-nums'] },
  help: { ...Type.callout, color: Colors.textSecondary, fontWeight: '400' },
});
