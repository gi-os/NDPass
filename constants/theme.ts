/**
 * NDPass — Liquid Glass Design System
 *
 * Inspired by iOS 26 Liquid Glass material.
 * Translucent panels with subtle borders that catch light,
 * layered depth, and warm cinema tones underneath.
 *
 * The trick: dark base + translucent white panels + 1px bright borders
 * + soft inner shadows = convincing glass without native blur API.
 */

export const Colors = {
  // Base layers
  bg: '#080810',
  bgGradientStart: '#0A0A18',
  bgGradientEnd: '#10081A',

  // Glass panels — translucent white
  glass: 'rgba(255, 255, 255, 0.06)',
  glassHover: 'rgba(255, 255, 255, 0.09)',
  glassActive: 'rgba(255, 255, 255, 0.12)',
  glassBorder: 'rgba(255, 255, 255, 0.12)',
  glassBorderLight: 'rgba(255, 255, 255, 0.18)',
  glassHighlight: 'rgba(255, 255, 255, 0.25)',

  // Cinema accents
  cream: '#F0E6D3',
  creamMuted: '#B8A88A',
  creamDim: '#6B6152',
  amber: '#E8A63A',
  amberGlow: 'rgba(232, 166, 58, 0.15)',
  red: '#E85454',
  green: '#4ADE80',
  greenGlow: 'rgba(74, 222, 128, 0.12)',

  // Text
  textPrimary: '#F5F0EA',
  textSecondary: 'rgba(245, 240, 234, 0.55)',
  textMuted: 'rgba(245, 240, 234, 0.3)',

  // Shadows
  shadowDark: 'rgba(0, 0, 0, 0.5)',
  shadowGlow: 'rgba(232, 166, 58, 0.08)',
} as const;

export const Glass = {
  // Standard glass panel
  panel: {
    backgroundColor: Colors.glass,
    borderWidth: 1,
    borderColor: Colors.glassBorder,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.3,
    shadowRadius: 24,
    elevation: 8,
  },
  // Elevated glass (modals, popovers)
  elevated: {
    backgroundColor: Colors.glassActive,
    borderWidth: 1,
    borderColor: Colors.glassBorderLight,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 16 },
    shadowOpacity: 0.4,
    shadowRadius: 32,
    elevation: 12,
  },
  // Subtle glass (cards within cards)
  subtle: {
    backgroundColor: 'rgba(255, 255, 255, 0.03)',
    borderWidth: 0.5,
    borderColor: 'rgba(255, 255, 255, 0.06)',
  },
} as const;

export const Typography = {
  // Display — for movie titles, hero text
  display: 'System',
  // Mono — for metadata, labels, terminal
  mono: 'Courier',
  // Body
  body: 'System',
} as const;

export const Spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
} as const;

export const Radius = {
  sm: 6,
  md: 12,
  lg: 16,
  xl: 22,
  card: 20,
  pill: 100,
} as const;
