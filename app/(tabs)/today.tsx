import { useTranslation } from 'react-i18next';

import { AppText } from '@/components/AppText';
import { EmptyState } from '@/components/EmptyState';
import { Screen } from '@/components/Screen';

export default function TodayScreen() {
  const { t } = useTranslation();

  return (
    <Screen edges={['top']}>
      <AppText variant="title">{t('today.title')}</AppText>
      <EmptyState emoji="⏰" text={t('today.empty')} />
    </Screen>
  );
}
