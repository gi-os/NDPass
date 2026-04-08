import { View, ViewStyle, StyleSheet, Platform } from 'react-native';
import { Colors, Glass, Radius } from '@/constants/theme';
import { ReactNode } from 'react';

let LiquidGlassView: any = null;
let isLiquidGlassSupported = false;

try {
  const lg = require('@callstack/liquid-glass');
  LiquidGlassView = lg.LiquidGlassView;
  isLiquidGlassSupported = lg.isLiquidGlassSupported ?? false;
} catch {
  // Package not available — use fallback
}

interface GlassCardProps {
  children: ReactNode;
  style?: ViewStyle;
  elevated?: boolean;
}

/**
 * Glass panel component.
 * Uses real iOS 26 Liquid Glass when available via @callstack/liquid-glass.
 * Falls back to translucent panel with border on older iOS.
 */
export default function GlassCard({ children, style, elevated = false }: GlassCardProps) {
  // Use real Liquid Glass on iOS 26+
  if (Platform.OS === 'ios' && isLiquidGlassSupported && LiquidGlassView) {
    return (
      <LiquidGlassView
        style={[styles.container, { borderRadius: Radius.card }, style]}
        visualEffect={elevated ? 'regular' : 'clear'}
      >
        {children}
      </LiquidGlassView>
    );
  }

  // Fallback: translucent panel
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
