// Палитра: яркая, но не кислотная. Основной — фиолетовый, акценты — розовый и жёлтый.
export const colors = {
  primary: '#7C3AED',
  primaryDark: '#5B21B6',
  primarySoft: '#EDE4FF',
  pink: '#FF4D8D',
  pinkSoft: '#FFE3EE',
  yellow: '#FFC93C',
  yellowSoft: '#FFF4D6',
  mint: '#2DD4A7',

  background: '#FFF9F2',
  surface: '#FFFFFF',
  border: '#ECE6F5',

  text: '#1E1B2E',
  textMuted: '#6B6680',
  textOnPrimary: '#FFFFFF',

  danger: '#E5484D',
} as const;

export type ColorName = keyof typeof colors;
