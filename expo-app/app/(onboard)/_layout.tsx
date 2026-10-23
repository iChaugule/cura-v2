import { Stack } from 'expo-router';
import { Colors } from '../../src/design/tokens';

export default function OnboardLayout() {
  return (
    <Stack
      screenOptions={{
        headerShown: false,
        animation: 'slide_from_right',
        contentStyle: { backgroundColor: Colors.bgBase },
      }}
    />
  );
}
