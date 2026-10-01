import { createInstance } from 'i18next';
import { initReactI18next } from 'react-i18next';
import { getLocales } from 'expo-localization';

import ru from './ru.json';
import kk from './kk.json';

export const SUPPORTED_LANGUAGES = ['ru', 'kk'] as const;
export type AppLanguage = (typeof SUPPORTED_LANGUAGES)[number];

function isAppLanguage(code: string | null | undefined): code is AppLanguage {
  return SUPPORTED_LANGUAGES.includes(code as AppLanguage);
}

// Берём первый язык телефона, который мы поддерживаем. Если ни один не подходит — русский.
function detectDeviceLanguage(): AppLanguage {
  for (const locale of getLocales()) {
    if (isAppLanguage(locale.languageCode)) return locale.languageCode;
  }
  return 'ru';
}

// Отдельный экземпляр i18next — react-i18next подхватит его через initReactI18next.
const i18n = createInstance();

void i18n.use(initReactI18next).init({
  resources: {
    ru: { translation: ru },
    kk: { translation: kk },
  },
  lng: detectDeviceLanguage(),
  fallbackLng: 'ru',
  interpolation: { escapeValue: false },
});

// Выбор языка пока живёт только до перезапуска приложения.
// На шаге с профилем будем сохранять его в profiles.locale в Supabase.
export function changeLanguage(lang: AppLanguage) {
  return i18n.changeLanguage(lang);
}

export default i18n;
