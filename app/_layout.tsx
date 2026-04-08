import { useEffect } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { Colors } from '@/constants/theme';
import { updateWidget } from '@/lib/widget';

export default function RootLayout() {
  // Refresh widget data on every app launch
  useEffect(() => {
    updateWidget();
  }, []);

  return (
    <>
      <StatusBar style="light" />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: Colors.bg },
          headerTintColor: Colors.cream,
          headerTitleStyle: {
            fontFamily: 'Courier',
            fontWeight: '700',
            fontSize: 18,
            letterSpacing: 1,
          },
          headerShadowVisible: false,
          contentStyle: { backgroundColor: Colors.bg },
        }}
      >
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen
          name="ticket/[id]"
          options={{
            title: '',
            headerTransparent: true,
            headerBackTitle: 'Back',
            contentStyle: { backgroundColor: 'transparent' },
          }}
        />
      </Stack>
    </>
  );
}
