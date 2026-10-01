import { Pressable, StyleSheet, View } from 'react-native';
import { useTranslation } from 'react-i18next';

import { changeLanguage, SUPPORTED_LANGUAGES } from '@/i18n';
import { colors, radius, spacing } from '@/theme';
import { AppText } from './AppText';

export function LanguageSwitcher() {
  const { t, i18n } = useTranslation();

  return (
    <View style={styles.row} accessibilityRole="radiogroup">
      {SUPPORTED_LANGUAGES.map((lang) => {
        const selected = i18n.language === lang;
        return (
          <Pressable
            key={lang}
            accessibilityRole="radio"
            accessibilityState={{ selected }}
            onPress={() => void changeLanguage(lang)}
            style={[styles.option, selected && styles.optionSelected]}
          >
            <AppText variant="bodyBold" color={selected ? 'textOnPrimary' : 'text'}>
              {t(`languages.${lang}`)}
            </AppText>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    gap: spacing.sm,
    backgroundColor: colors.primarySoft,
    borderRadius: radius.pill,
    padding: spacing.xs,
  },
  option: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: spacing.sm + spacing.xs,
    borderRadius: radius.pill,
  },
  optionSelected: {
    backgroundColor: colors.primary,
  },
});
