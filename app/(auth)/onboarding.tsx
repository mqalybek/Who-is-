import { useState } from 'react';
import { KeyboardAvoidingView, Platform, StyleSheet, TextInput, View } from 'react-native';
import { router } from 'expo-router';
import { useTranslation } from 'react-i18next';

import { AppText } from '@/components/AppText';
import { Button } from '@/components/Button';
import { Screen } from '@/components/Screen';
import { isValidUsername } from '@/features/auth/username';
import { colors, radius, spacing, typography } from '@/theme';

export default function OnboardingScreen() {
  const { t } = useTranslation();
  const [username, setUsername] = useState('');

  const isValid = isValidUsername(username);
  const showError = username.length > 0 && !isValid;

  // Заглушка: позже здесь будет сохранение ника в profiles.
  const finish = () => router.replace('/today');

  return (
    <Screen>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <View style={styles.form}>
          <AppText variant="title">{t('onboarding.title')}</AppText>
          <AppText color="textMuted">{t('onboarding.subtitle')}</AppText>

          <TextInput
            value={username}
            onChangeText={setUsername}
            placeholder={t('onboarding.placeholder')}
            placeholderTextColor={colors.textMuted}
            autoCapitalize="none"
            autoCorrect={false}
            autoFocus
            maxLength={20}
            style={[styles.input, showError && styles.inputError]}
          />
          <AppText variant="caption" color={showError ? 'danger' : 'textMuted'}>
            {showError ? t('onboarding.invalid') : t('onboarding.rules')}
          </AppText>
        </View>

        <Button title={t('common.continue')} onPress={finish} disabled={!isValid} />
      </KeyboardAvoidingView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  flex: {
    flex: 1,
    justifyContent: 'space-between',
  },
  form: {
    gap: spacing.md,
    paddingTop: spacing.xl,
  },
  input: {
    ...typography.heading,
    color: colors.text,
    backgroundColor: colors.surface,
    borderWidth: 2,
    borderColor: colors.border,
    borderRadius: radius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
  },
  inputError: {
    borderColor: colors.danger,
  },
});
