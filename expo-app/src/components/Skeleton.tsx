/**
 * Placeholder bar shown while something loads, in the shape of what is coming.
 * A gentle opacity pulse says "loading" without a spinner.
 */
import { useEffect, useRef } from 'react';
import { Animated, type DimensionValue, type ViewStyle, AccessibilityInfo } from 'react-native';
import { Colors } from '../design/tokens';

export function Skeleton({
  width = '100%', height = 14, style,
}: { width?: DimensionValue; height?: number; style?: ViewStyle }) {
  const opacity = useRef(new Animated.Value(0.55)).current;

  useEffect(() => {
    let loop: Animated.CompositeAnimation | null = null;
    AccessibilityInfo.isReduceMotionEnabled().then(reduce => {
      if (reduce) return;
      loop = Animated.loop(Animated.sequence([
        Animated.timing(opacity, { toValue: 1, duration: 700, useNativeDriver: true }),
        Animated.timing(opacity, { toValue: 0.55, duration: 700, useNativeDriver: true }),
      ]));
      loop.start();
    }).catch(() => {});
    return () => loop?.stop();
  }, [opacity]);

  return (
    <Animated.View
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      style={[{ width, height, borderRadius: 4, backgroundColor: Colors.surfaceTinted, opacity }, style]}
    />
  );
}
