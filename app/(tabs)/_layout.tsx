import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { BlurView } from 'expo-blur';
import { StyleSheet, View } from 'react-native';
import { Colors } from '@/constants/theme';

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        headerStyle: { backgroundColor: Colors.bg, shadowColor: 'transparent', elevation: 0 },
        headerTintColor: Colors.cream,
        headerTitleStyle: { fontFamily: 'Courier', fontWeight: '700', fontSize: 18, letterSpacing: 0.5 },
        tabBarStyle: {
          position: 'absolute',
          backgroundColor: 'transparent',
          borderTopWidth: 0,
          elevation: 0,
          height: 88,
        },
        tabBarBackground: () => (
          <View style={StyleSheet.absoluteFill}>
            <BlurView intensity={40} tint="dark" style={StyleSheet.absoluteFill} />
            <View style={{ position: 'absolute', top: 0, left: 24, right: 24, height: 0.5, backgroundColor: Colors.glassHighlight }} />
          </View>
        ),
        tabBarActiveTintColor: Colors.amber,
        tabBarInactiveTintColor: Colors.textMuted,
        tabBarLabelStyle: { fontFamily: 'Courier', fontSize: 9, letterSpacing: 0.8 },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          headerShown: false,
          tabBarLabel: 'STUBS',
          tabBarIcon: ({ color, size }) => <Ionicons name="ticket-outline" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="calendar"
        options={{
          title: 'Calendar',
          tabBarLabel: 'CALENDAR',
          tabBarIcon: ({ color, size }) => <Ionicons name="calendar-outline" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="scan"
        options={{
          title: 'Scan',
          tabBarLabel: 'SCAN',
          tabBarIcon: ({ color, size }) => <Ionicons name="camera-outline" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="stats"
        options={{
          title: 'Stats',
          tabBarLabel: 'STATS',
          tabBarIcon: ({ color, size }) => <Ionicons name="analytics-outline" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: 'Settings',
          tabBarLabel: 'SETTINGS',
          tabBarIcon: ({ color, size }) => <Ionicons name="settings-outline" size={size} color={color} />,
        }}
      />
    </Tabs>
  );
}
