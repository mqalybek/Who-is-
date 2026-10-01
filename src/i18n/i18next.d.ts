import 'i18next';

import type ru from './ru.json';

// Благодаря этому TypeScript подсказывает ключи переводов и ругается на опечатки в t('...').
declare module 'i18next' {
  interface CustomTypeOptions {
    defaultNS: 'translation';
    resources: { translation: typeof ru };
  }
}
