import { View, ViewStyle, StyleSheet } from 'react-native';
import { BlurView } from 'expo-blur';
import { Colors, Glass, Radius } from '@/constants/theme';
import { ReactNode } from 'react';

interface GlassCardProps {
  children: ReactNode;
  style?: ViewStyle;
  intensity?: number;
  elevated?: boolean;
}

/**
 * Glass panel component — translucent card with border highlight.
 * Uses expo-blur when available, falls back to semi-transparent bg.
 */
export default function GlassCard({ children, style, intensity = 30, elevated = false }: GlassCardProps) {
  const glassStyle = elevated ? Glass.elevated : Glass.panel;

  return (
    <View style={[styles.container, glassStyle, { borderRadius: Radius.card }, style]}>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    overflow: 'hidden',
    position: 'relative',
  },
});
