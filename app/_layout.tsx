import { useEffect } from 'react';
import { Stack, router } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { Platform, NativeModules } from 'react-native';
import { Colors } from '@/constants/theme';
import { updateWidget } from '@/lib/widget';

export default function RootLayout() {
  useEffect(() => {
    updateWidget();
    // Check if launched from share extension — navigate to scan tab
    checkPendingShare();
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

async function checkPendingShare() {
  if (Platform.OS !== 'ios') return;
  try {
    const { SharedStorage } = NativeModules;
    if (!SharedStorage?.get) return;
    const flag = await SharedStorage.get('pendingShareFlag', 'group.com.gios.ndpass');
    if (flag === '1') {
      // Navigate to scan tab after a short delay to let the layout mount
      setTimeout(() => {
        router.navigate('/(tabs)/scan');
      }, 300);
    }
  } catch {}
}
