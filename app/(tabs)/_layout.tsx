import { Text } from 'react-native';
import { Tabs } from 'expo-router/js-tabs';
import { useTranslation } from 'react-i18next';

import { colors } from '@/theme';

// Иконки пока эмодзи — чтобы не тянуть отдельную библиотеку иконок.
function TabIcon({ emoji, focused }: { emoji: string; focused: boolean }) {
  return <Text style={{ fontSize: 24, opacity: focused ? 1 : 0.45 }}>{emoji}</Text>;
}

export default function TabsLayout() {
  const { t } = useTranslation();

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.textMuted,
        tabBarStyle: { backgroundColor: colors.surface, borderTopColor: colors.border },
        tabBarLabelStyle: { fontWeight: '700' },
      }}
    >
      <Tabs.Screen
        name="today"
        options={{
          title: t('tabs.today'),
          tabBarIcon: ({ focused }) => <TabIcon emoji="🔥" focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="circles"
        options={{
          title: t('tabs.circles'),
          tabBarIcon: ({ focused }) => <TabIcon emoji="👯" focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: t('tabs.profile'),
          tabBarIcon: ({ focused }) => <TabIcon emoji="😎" focused={focused} />,
        }}
      />
    </Tabs>
  );
}
