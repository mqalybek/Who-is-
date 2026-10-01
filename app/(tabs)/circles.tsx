import { useTranslation } from 'react-i18next';

import { AppText } from '@/components/AppText';
import { EmptyState } from '@/components/EmptyState';
import { Screen } from '@/components/Screen';

export default function CirclesScreen() {
  const { t } = useTranslation();

  return (
    <Screen edges={['top']}>
      <AppText variant="title">{t('circles.title')}</AppText>
      <EmptyState emoji="🫶" text={t('circles.empty')} />
    </Screen>
  );
}
