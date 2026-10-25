import { useEffect } from 'react';
import { View, StyleSheet, type ColorValue } from 'react-native';
import { Tabs, router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { DemoBar } from '../../src/components/DemoBar';
import { Colors } from '../../src/design/tokens';
import { useApp } from '../../src/state/AppContext';

type IconName = React.ComponentProps<typeof Ionicons>['name'];

// React Navigation hands the icon a ColorValue, not a plain string.
const icon = (active: IconName, inactive: IconName) =>
  ({ color, focused }: { color: ColorValue; focused: boolean }) => (
    <Ionicons name={focused ? active : inactive} size={23} color={color as string} />
  );

/**
 * Room the tab bar needs above the home indicator: 5px padding + a 28px icon
 * box + a 14px label line + 5px padding, plus a little slack. The stock 49pt
 * iOS height is 5px short of this, which silently flex-shrinks the label until
 * its descenders clip — so the height is set explicitly instead.
 */
const TAB_BAR_CONTENT_HEIGHT = 56;

export default function TabsLayout() {
  const { state, isOnboarded, pendingInvites } = useApp();
  const insets = useSafeAreaInsets();

  // Nobody signed up — bounce back to the front door.
  useEffect(() => {
    if (!state.hydrated) return;
    if (!isOnboarded) router.replace('/');
    // A caregiver no family has connected with yet has nothing to show here.
    else if (state.live && !state.pnc) router.replace('/(onboard)/invites');
  }, [state.hydrated, isOnboarded, state.live, state.pnc]);

  if (!state.hydrated) return <View style={{ flex: 1, backgroundColor: Colors.bgBase }} />;

  const unreadInvites = state.activeRole === 'caregiver' ? pendingInvites.length : 0;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: Colors.bgBase }} edges={['top']}>
      <DemoBar />
      <Tabs
        screenOptions={{
          headerShown: false,
          tabBarActiveTintColor: Colors.brown,
          tabBarInactiveTintColor: Colors.textTertiary,
          sceneStyle: { backgroundColor: Colors.bgBase },
          // Height must include the bottom inset — the bar draws behind the
          // home indicator and pads itself by that amount.
          tabBarStyle: {
            backgroundColor: Colors.surface,
            borderTopColor: Colors.separator,
            borderTopWidth: StyleSheet.hairlineWidth,
            height: TAB_BAR_CONTENT_HEIGHT + insets.bottom,
          },
          // lineHeight must be explicit: the label box is `overflow: hidden`
          // and the default line box is shorter than the glyphs, so descenders
          // (the "g" in Messages) get cut off.
          tabBarLabelStyle: { fontSize: 11, lineHeight: 14, fontWeight: '600' },
        }}
      >
        <Tabs.Screen name="index" options={{ title: 'Home', tabBarIcon: icon('home', 'home-outline') }} />
        <Tabs.Screen name="schedule" options={{ title: 'Schedule', tabBarIcon: icon('calendar', 'calendar-outline') }} />
        <Tabs.Screen name="messages" options={{ title: 'Chat', tabBarIcon: icon('chatbubbles', 'chatbubbles-outline') }} />
        <Tabs.Screen name="notes" options={{ title: 'Notes', tabBarIcon: icon('document-text', 'document-text-outline') }} />
        <Tabs.Screen name="cura" options={{ title: 'Ask', tabBarIcon: icon('help-circle', 'help-circle-outline') }} />
        <Tabs.Screen
          name="profile"
          options={{
            title: 'Info',
            tabBarIcon: icon('person-circle', 'person-circle-outline'),
            tabBarBadge: unreadInvites || undefined,
            tabBarBadgeStyle: { backgroundColor: Colors.urgent, fontSize: 10, color: '#fff' },
          }}
        />
      </Tabs>
    </SafeAreaView>
  );
}
