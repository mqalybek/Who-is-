import type { TextStyle } from 'react-native';

// Пока системный шрифт (San Francisco / Roboto) — он поддерживает казахские буквы.
// Свой шрифт можно подключить позже через expo-font.
export const typography = {
  title: { fontSize: 32, lineHeight: 38, fontWeight: '800' },
  heading: { fontSize: 22, lineHeight: 28, fontWeight: '700' },
  body: { fontSize: 16, lineHeight: 22, fontWeight: '400' },
  bodyBold: { fontSize: 16, lineHeight: 22, fontWeight: '700' },
  caption: { fontSize: 13, lineHeight: 18, fontWeight: '500' },
} satisfies Record<string, TextStyle>;

export type TypographyVariant = keyof typeof typography;
