import { StyleSheet, View } from 'react-native';

import { colors, radius, spacing } from '@/theme';
import { AppText } from './AppText';

type Props = {
  emoji: string;
  text: string;
};

export function EmptyState({ emoji, text }: Props) {
  return (
    <View style={styles.card}>
      <AppText style={styles.emoji}>{emoji}</AppText>
      <AppText color="textMuted" style={styles.text}>
        {text}
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.xl,
    alignItems: 'center',
    gap: spacing.md,
  },
  emoji: {
    fontSize: 48,
    lineHeight: 56,
  },
  text: {
    textAlign: 'center',
  },
});
