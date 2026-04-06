/**
 * NDPass — Design Tokens
 * 
 * Aesthetic: "Vintage cinema lobby meets brutalist ticket"
 * Dark base, warm paper/cream accents, monospaced ticket typography
 */

export const Colors = {
  // Base
  bg: '#0A0A0A',
  bgCard: '#141414',
  bgElevated: '#1C1C1C',
  bgInput: '#1A1A1A',

  // Paper / ticket tones
  cream: '#E8D5B7',
  creamMuted: '#B8A88A',
  creamDim: '#6B6152',
  paper: '#F5EDE0',

  // Accents
  amber: '#D4A24E',
  red: '#C4453C',
  green: '#4CAF6E',

  // Text
  textPrimary: '#F0ECE6',
  textSecondary: '#8A8478',
  textMuted: '#5A5549',

  // Borders
  border: '#2A2A2A',
  borderLight: '#3A3A3A',
} as const;

export const Typography = {
  // Monospaced for ticket data — feels like a thermal print
  mono: 'Courier',
  // System for UI
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
  sm: 4,
  md: 8,
  lg: 12,
  xl: 16,
  card: 14,
} as const;
