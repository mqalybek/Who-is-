import { useTranslation } from 'react-i18next';

import { AppText } from '@/components/AppText';
import { LanguageSwitcher } from '@/components/LanguageSwitcher';
import { Screen } from '@/components/Screen';

export default function ProfileScreen() {
  const { t } = useTranslation();

  return (
    <Screen edges={['top']}>
      <AppText variant="title">{t('profile.title')}</AppText>
      <AppText variant="heading">{t('profile.language')}</AppText>
      <LanguageSwitcher />
    </Screen>
  );
}
