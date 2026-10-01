import { StyleSheet, View } from 'react-native';
import { router } from 'expo-router';
import { useTranslation } from 'react-i18next';

import { AppText } from '@/components/AppText';
import { Button } from '@/components/Button';
import { Screen } from '@/components/Screen';
import { colors, radius, spacing } from '@/theme';

export default function SignInScreen() {
  const { t } = useTranslation();

  // Заглушка: настоящий вход через Supabase Auth появится позже.
  const goNext = () => router.push('/onboarding');

  return (
    <Screen>
      <View style={styles.hero}>
        <View style={styles.logo}>
          <AppText variant="title" color="textOnPrimary">
            ?
          </AppText>
        </View>
        <AppText variant="title">{t('common.appName')}</AppText>
        <AppText color="textMuted" style={styles.center}>
          {t('auth.tagline')}
        </AppText>
      </View>

      <View style={styles.actions}>
        <Button title={t('auth.signInApple')} onPress={goNext} />
        <Button title={t('auth.signInGoogle')} onPress={goNext} variant="secondary" />
        <AppText variant="caption" color="textMuted" style={styles.center}>
          {t('auth.stubNote')}
        </AppText>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  hero: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.md,
  },
  logo: {
    width: 96,
    height: 96,
    borderRadius: radius.lg,
    backgroundColor: colors.pink,
    alignItems: 'center',
    justifyContent: 'center',
    transform: [{ rotate: '-8deg' }],
  },
  actions: {
    gap: spacing.md,
  },
  center: {
    textAlign: 'center',
  },
});
